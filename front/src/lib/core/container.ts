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
function buildChildProxies(child: Component): Omit<ChildEntry, 'snippet' | 'attach' | 'detach'> {
  const props: Record<string, any> = {};
  for (const name of child.propNames) {
    Object.defineProperty(props, name, {
      get: () => child.svelteProps[name],
      set: (v: any) => { child.svelteProps[name] = v; },
      enumerable: true, configurable: true
    });
  }

  // Expose childEntries for container children (e.g. Node → ports accessible from NodeEditor)
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
 * Build a complete ChildEntry for a child, handling headless/attachable modes.
 */
function buildChildEntry(child: Component): ChildEntry {
  if (child.mixins.includes('headless')) {
    return { ...buildChildProxies(child) };
  }
  if (child.mixins.includes('attachable')) {
    return {
      attach: (el: HTMLElement, ctx?: Map<any, any>) => child.mountInto(el, ctx),
      detach: () => child.unmountFrom(),
      ...buildChildProxies(child)
    };
  }
  return { snippet: child._snippet!, ...buildChildProxies(child) };
}

// ============================================================================
// Batch mode — skip flushSync() during bulk event processing
// ============================================================================

let batchMode = false;

/** Enable/disable batch mode. When enabled, flushSync() is deferred. */
export function setBatchMode(enabled: boolean): void {
  batchMode = enabled;
}

// ============================================================================
// Event handlers
// ============================================================================

/**
 * Handle @insert event - create and add a child component.
 * Tries sync creation first (cached modules), falls back to async.
 */
export async function handleInsert(
  parent: Component,
  _id: string,
  _name: string,
  data: unknown
): Promise<void> {
  const { component: definition, target } = data as InsertEventData;

  const syncChild = Factory.instance.createSync(definition);
  const child = syncChild ?? await Factory.instance.create(definition);

  Registry.instance.register(child);
  child._parentComponent = parent;

  if (definition.staticChildren?.length) {
    child.svelteProps.staticChildren = await createStaticChildren(child, definition.staticChildren);
  }

  const isHeadless = child.mixins.includes('headless');
  const isAttachable = child.mixins.includes('attachable');

  // Create snippet only for normal components (not headless or attachable)
  if (!isHeadless && !isAttachable) {
    const snippet = child.createSnippet();
    child._snippet = snippet;
  }

  if (!parent._childEntries[target]) {
    // Auto-create the slot when @insert arrives before @prop/targets.
    // This happens when an attached container sends events individually
    // (each publish() is a separate sendEventToHTMLSource call) and the
    // @prop/targets event hasn't been processed yet.
    parent._childEntries[target] = [];

    // Also update the 'targets' prop so Svelte templates that iterate
    // over targets (e.g. Splitter's {#each targets}) render a slot for
    // the new target immediately, rather than waiting for @prop/targets.
    // Use setPropSilently to avoid echoing back to MATLAB.
    const currentTargets = parent.svelteProps['targets'];
    if (Array.isArray(currentTargets) && !currentTargets.includes(target)) {
      parent.setPropSilently('targets', [...currentTargets, target]);
    }
  }

  const childEntry = buildChildEntry(child);
  parent._childEntries[target].push(childEntry);
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

  // Detach attachable components before removing
  if (child._childEntry?.detach) {
    child._childEntry.detach();
  }

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

  if (!batchMode) flushSync();
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
        if (!batchMode) flushSync();
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
  if (!batchMode) flushSync();

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

  const isHeadless = child.mixins.includes('headless');
  const isAttachable = child.mixins.includes('attachable');

  // Detach attachable from old parent before reparenting
  if (isAttachable && child._childEntry?.detach) {
    child._childEntry.detach();
  }

  // Create fresh snippet only for normal components
  if (!isHeadless && !isAttachable) {
    const newSnippet = child.createSnippet();
    child._snippet = newSnippet;
  }
  child._parentComponent = newParent;

  if (!newParent._childEntries[targetSlot]) {
    newParent._childEntries[targetSlot] = [];
  }

  const newEntry = buildChildEntry(child);
  newParent._childEntries[targetSlot].push(newEntry);
  child._childEntry = newEntry;

  newParent.children.push(child);

  if (!batchMode) flushSync();
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
  if (!child) {
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

  if (!batchMode) flushSync();
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
 * Tries sync creation first (cached modules), falls back to async.
 */
export async function createStaticChildren(
  parent: Component,
  defs: InsertEventData[]
): Promise<StaticChildrenMap> {
  const result: StaticChildrenMap = new Map();

  for (const def of defs) {
    const child = Factory.instance.createSync(def.component)
      ?? await Factory.instance.create(def.component);
    child._isStatic = true;
    child._parentComponent = parent;

    Registry.instance.register(child);

    const isHeadless = child.mixins.includes('headless');
    const isAttachable = child.mixins.includes('attachable');

    if (!isHeadless && !isAttachable) {
      const snippet = child.createSnippet();
      child._snippet = snippet;
    }

    parent.children.push(child);

    if (!result.has(def.target)) {
      result.set(def.target, []);
    }

    const childEntry = buildChildEntry(child);
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
