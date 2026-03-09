/**
 * Container - Event handlers for @insert, @remove, @reparent, @reorder.
 *
 * This module exports handlers that orchestrate Factory, Registry, and Component
 * to manage parent-child relationships. Separated from Component to avoid
 * circular dependencies (Component ↔ Factory).
 *
 * Each dynamic child is stored as a `ChildEntry` in the parent's `_childEntries`
 * record (keyed by target slot). The entry includes the renderable snippet plus
 * reactive proxy objects for props, events, and methods — the same mechanism
 * used by static children.
 */

import { flushSync } from 'svelte';
import type {
  ChildEntry,
  ComponentDefinition,
  InsertEventData,
  RemoveEventData,
  ReorderEventData,
  ReparentEventData,
  StaticChildrenMap
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
 *
 * Each proxy delegates get/set to the child's svelteProps, which in turn
 * reads/writes from `$state`-backed storage. This makes child data reactive
 * from the parent's Svelte template without mounting the child component.
 */
function buildChildProxies(child: Component): Omit<ChildEntry, 'snippet'> {
  const props: Record<string, any> = {};
  for (const name of child.propNames) {
    Object.defineProperty(props, name, {
      get: () => child.svelteProps[name],
      set: (v: any) => { child.svelteProps[name] = v; },
      enumerable: true, configurable: true
    });
  }

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
  const { component: definition, target } = data as InsertEventData;

  // Create child via Factory
  const child = await Factory.instance.create(definition);

  // Register child in global registry
  Registry.instance.register(child);

  // Set parent reference
  child._parentComponent = parent;

  // Create static children
  if (definition.staticChildren?.length) {
    child.svelteProps.staticChildren = await createStaticChildren(child, definition.staticChildren);
  }

  // Create snippet
  const snippet = child.createSnippet();
  child._snippet = snippet;

  if (!parent._childEntries[target]) {
    throw new Error(`[Component] @insert: Target slot "${target}" not defined in component "${parent.id}"`);
  }

  // Build ChildEntry with reactive proxies and add to parent
  const childEntry: ChildEntry = { snippet, ...buildChildProxies(child) };
  parent._childEntries[target].push(childEntry);
  child._childEntry = childEntry;
  parent.children.push(child);

  flushSync();
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

  // Find the child
  const childIndex = parent.children.findIndex((c) => c.id === childId);
  if (childIndex === -1) {
    logger.warn('Container', '@remove: Child not found', {
      childId,
      parentId: parent.id
    });
    return;
  }

  const child = parent.children[childIndex];

  // Recursively deregister all descendants (handles nested static children)
  deregisterTree(child);

  // Remove entry from parent's child entries
  for (const slotName of Object.keys(parent._childEntries)) {
    const entryIndex = parent._childEntries[slotName].findIndex(e => e.id === childId);
    if (entryIndex !== -1) {
      parent._childEntries[slotName].splice(entryIndex, 1);
      break;
    }
  }

  // Remove from children array
  parent.children.splice(childIndex, 1);

  flushSync();
}

/**
 * Recursively deregister a component and all its descendants.
 * Handles both dynamic children (in _childEntries) and static children (in children array).
 */
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
  const { id: childId, parent: newParentId, target } = data as ReparentEventData;

  // Find the child
  const childIndex = parent.children.findIndex((c) => c.id === childId);
  if (childIndex === -1) {
    logger.warn('Container', '@reparent: Child not found', {
      childId,
      parentId: parent.id
    });
    return;
  }

  const child = parent.children[childIndex];
  const targetSlot = target || 'default';

  // Same parent case - check if this is a no-op or a slot change
  if (newParentId === parent.id) {
    for (const slotName of Object.keys(parent._childEntries)) {
      const entryIndex = parent._childEntries[slotName].findIndex(e => e.id === childId);
      if (entryIndex !== -1) {
        if (slotName === targetSlot) {
          return; // Same parent, same slot - nothing to do
        }
        // Same parent, different slot - move entry without recreating
        const [movedEntry] = parent._childEntries[slotName].splice(entryIndex, 1);
        if (!parent._childEntries[targetSlot]) {
          parent._childEntries[targetSlot] = [];
        }
        parent._childEntries[targetSlot].push(movedEntry);
        flushSync();
        return;
      }
    }
    return; // Entry not found - shouldn't happen
  }

  // Different parent - full reparenting

  // Remove entry from current parent's slots
  for (const slotName of Object.keys(parent._childEntries)) {
    const entryIndex = parent._childEntries[slotName].findIndex(e => e.id === childId);
    if (entryIndex !== -1) {
      parent._childEntries[slotName].splice(entryIndex, 1);
      break;
    }
  }

  // Flush to ensure old snippet cleanup completes before creating new one
  flushSync();

  // Remove from current parent's children
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

  // Create fresh snippet and entry for new parent
  const newSnippet = child.createSnippet();
  child._snippet = newSnippet;
  child._parentComponent = newParent;

  if (!newParent._childEntries[targetSlot]) {
    newParent._childEntries[targetSlot] = [];
  }
  const newEntry: ChildEntry = { snippet: newSnippet, ...buildChildProxies(child) };
  newParent._childEntries[targetSlot].push(newEntry);
  child._childEntry = newEntry;

  newParent.children.push(child);

  flushSync();
}

/**
 * Handle @reorder event - move a child to a new position within its target slot.
 */
export async function handleReorder(
  parent: Component,
  _id: string,
  _name: string,
  data: unknown
): Promise<void> {
  const { id: childId, index, target } = data as ReorderEventData;

  // Find the child
  const child = parent.children.find((c) => c.id === childId);
  if (!child || !child._snippet) {
    logger.warn('Container', '@reorder: Child not found', { childId });
    return;
  }

  // Get the entries array for this target
  const entries = parent._childEntries[target];
  if (!entries) {
    logger.warn('Container', '@reorder: Target not found', { target });
    return;
  }

  // Find current position
  const fromIndex = entries.findIndex(e => e.id === childId);
  if (fromIndex === -1 || fromIndex === index) {
    return; // Not found or already at position
  }

  logger.debug('Container', '@reorder', { childId, target, from: fromIndex, to: index });

  // Simple array reorder: remove from old position, insert at new position
  const newArray = [...entries];
  const [moved] = newArray.splice(fromIndex, 1);
  newArray.splice(index, 0, moved);
  parent._childEntries[target] = newArray;

  flushSync();
}

// ============================================================================
// Static children
// ============================================================================

/**
 * Create Component instances for static children.
 *
 * Static children are declared in MATLAB constructor and included in the
 * parent's @insert payload. They're full Component instances with ChildEntry
 * objects, just rendered in fixed template locations instead of dynamic slots.
 *
 * @param parent - Parent component to attach children to
 * @param defs - Array of static child component definitions
 * @returns Map keyed by target name, each containing an array of ChildEntry for that target
 */
export async function createStaticChildren(
  parent: Component,
  defs: InsertEventData[]
): Promise<StaticChildrenMap> {
  const result: StaticChildrenMap = new Map();

  for (const def of defs) {
    const child = await Factory.instance.create(def.component);
    child._isStatic = true;
    child._parentComponent = parent;

    Registry.instance.register(child);
    const snippet = child.createSnippet();
    child._snippet = snippet;

    parent.children.push(child);

    if (!result.has(def.target)) {
      result.set(def.target, []);
    }

    const childEntry: ChildEntry = { snippet, ...buildChildProxies(child) };
    child._childEntry = childEntry;
    result.get(def.target)!.push(childEntry);

    // Recurse for nested static children
    if (def.component.staticChildren?.length) {
      const nested = await createStaticChildren(child, def.component.staticChildren);
      nested.forEach((children, key) => {
        if (!result.has(key)) {
          result.set(key, []);
        }
        result.get(key)!.push(...children);
      });
    }
  }

  return result;
}
