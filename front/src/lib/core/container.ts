/**
 * Container - Event handlers for @insert, @remove, @reparent, @reorder.
 *
 * This module exports handlers that orchestrate Factory, Registry, and Component
 * to manage parent-child relationships. Separated from Component to avoid
 * circular dependencies (Component <-> Factory).
 *
 * Each dynamic child is stored as a `ChildEntry` in the parent's `_childEntries`
 * flat array. Containers filter by type/mixin when rendering.
 */

import { flushSync } from 'svelte';
import type {
  ChildEntry,
  InsertEventData,
  RemoveEventData,
  ReorderEventData,
  ReparentEventData
} from '../types';
import type Component from './component.svelte';
import Factory from './factory';
import Registry from './registry';
import logger from './logger';

// ============================================================================
// Shared proxy builder
// ============================================================================

/**
 * Build reactive proxy objects for a child component's props, events, and methods.
 */
function buildChildProxies(child: Component): Omit<ChildEntry, 'component' | 'svelteProps' | 'onMounted' | 'onUnmounted'> {
  const props: Record<string, any> = {};
  for (const name of child.propNames) {
    Object.defineProperty(props, name, {
      get: () => child.svelteProps[name],
      set: (v: any) => { child.svelteProps[name] = v; },
      enumerable: true, configurable: true
    });
  }

  Object.defineProperty(props, 'childEntries', {
    get: () => child._childEntries,
    enumerable: true, configurable: true
  });

  const events: Record<string, any> = {};
  for (const name of child.eventNames) {
    Object.defineProperty(events, name, {
      get: () => child.svelteProps[name],
      set: (v: any) => { child.svelteProps[name] = v; },
      enumerable: true, configurable: true
    });
  }

  const methods: Record<string, any> = {};
  for (const name of child.methodNames) {
    Object.defineProperty(methods, name, {
      get: () => child.svelteProps[name],
      set: (v: any) => { child.svelteProps[name] = v; },
      enumerable: true, configurable: true
    });
  }

  return {
    id: child.id,
    type: child.type,
    props,
    events,
    methods,
    meta: {
      propNames: child.propNames,
      eventNames: child.eventNames,
      methodNames: child.methodNames,
      mixins: child.mixins
    }
  };
}

/**
 * Build a complete ChildEntry for a child component.
 */
function buildChildEntry(child: Component): ChildEntry {
  if (child.mixins.includes('headless')) {
    return { ...buildChildProxies(child) };
  }
  return {
    component: child.svelteComponentClass ?? undefined,
    svelteProps: child.svelteProps,
    onMounted: (el: Element | null) => child.notifyMounted(el!),
    onUnmounted: () => child.notifyUnmounted(),
    ...buildChildProxies(child)
  };
}

// ============================================================================
// Batch mode
// ============================================================================

let batchMode = false;

export function setBatchMode(enabled: boolean): void {
  batchMode = enabled;
}

// ============================================================================
// Event handlers
// ============================================================================

/**
 * Handle @insert event - create and add a child component.
 */
export async function handleInsert(
  parent: Component,
  _id: string,
  _name: string,
  data: unknown
): Promise<void> {
  const { component: definition } = data as InsertEventData;

  const syncChild = Factory.instance.createSync(definition);
  const child = syncChild ?? await Factory.instance.create(definition);

  Registry.instance.register(child);
  child._parentComponent = parent;

  const childEntry = buildChildEntry(child);
  parent._childEntries.push(childEntry);
  child._childEntry = childEntry;
  parent.children.push(child);

  if (!batchMode) flushSync();
}

/**
 * Handle @remove event - remove and cleanup a child component.
 */
export async function handleRemove(
  parent: Component,
  _id: string,
  _name: string,
  data: unknown
): Promise<void> {
  const { id: childId } = data as RemoveEventData;

  const childIndex = parent.children.findIndex((c) => c.id === childId);
  if (childIndex === -1) {
    logger.warn('Container', '@remove: Child not found', {
      childId,
      parentId: parent.id
    });
    return;
  }

  const child = parent.children[childIndex];

  deregisterTree(child);

  // Remove from flat child entries array
  const entryIndex = parent._childEntries.findIndex(e => e.id === childId);
  if (entryIndex !== -1) {
    parent._childEntries.splice(entryIndex, 1);
  }

  parent.children.splice(childIndex, 1);

  if (!batchMode) flushSync();
}

function deregisterTree(component: Component): void {
  for (const child of component.children) {
    deregisterTree(child);
  }
  Registry.instance.deregister(component.id);
}

/**
 * Handle @reparent event - move a child to a new parent.
 */
export async function handleReparent(
  parent: Component,
  _id: string,
  _name: string,
  data: unknown
): Promise<void> {
  const { id: childId, parent: newParentId } = data as ReparentEventData;

  const childIndex = parent.children.findIndex((c) => c.id === childId);
  if (childIndex === -1) {
    logger.warn('Container', '@reparent: Child not found', {
      childId,
      parentId: parent.id
    });
    return;
  }

  const child = parent.children[childIndex];

  // Same parent - no-op
  if (newParentId === parent.id) {
    return;
  }

  // Remove entry from current parent
  const entryIndex = parent._childEntries.findIndex(e => e.id === childId);
  if (entryIndex !== -1) {
    parent._childEntries.splice(entryIndex, 1);
  }

  // Flush to ensure old DynamicChild cleanup completes before re-inserting
  if (!batchMode) flushSync();

  parent.children.splice(childIndex, 1);

  // Find new parent
  const newParent = Registry.instance.get(newParentId) as Component | undefined;
  if (!newParent) {
    logger.error('Container', '@reparent: New parent not found', {
      childId,
      newParentId
    });
    return;
  }

  child._parentComponent = newParent;

  const newEntry = buildChildEntry(child);
  newParent._childEntries.push(newEntry);
  child._childEntry = newEntry;
  newParent.children.push(child);

  if (!batchMode) flushSync();
}

/**
 * Handle @reorder event - move a child to a new position in the flat array.
 */
export async function handleReorder(
  parent: Component,
  _id: string,
  _name: string,
  data: unknown
): Promise<void> {
  const { id: childId, index } = data as ReorderEventData;

  const fromIndex = parent._childEntries.findIndex(e => e.id === childId);
  if (fromIndex === -1 || fromIndex === index) {
    return;
  }

  logger.debug('Container', '@reorder', { childId, from: fromIndex, to: index });

  const newArray = [...parent._childEntries];
  const [moved] = newArray.splice(fromIndex, 1);
  newArray.splice(index, 0, moved);
  parent._childEntries = newArray;

  if (!batchMode) flushSync();
}
