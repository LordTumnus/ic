/**
 * Container - Event handlers for @insert, @remove, @reparent.
 *
 * This module exports handlers that orchestrate Factory, Registry, and Component
 * to manage parent-child relationships. Separated from Component to avoid
 * circular dependencies (Component ↔ Factory).
 */

import { flushSync } from 'svelte';
import type {
  ComponentDefinition,
  InsertEventData,
  RemoveEventData,
  ReorderEventData,
  ReparentEventData,
  StaticChild,
  StaticChildrenMap
} from '../types';
import type Component from './component.svelte';
import Factory from './factory';
import Registry from './registry';
import logger from './logger';

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

  // Create snippet and add to slots
  const snippet = child.createSnippet();
  child._snippet = snippet;

  if (!parent._snippets[target]) {
    throw new Error(`[Component] @insert: Target slot "${target}" not defined in component "${parent.id}"`);
  }
  parent._snippets[target].push(snippet);
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

  // Remove snippet from slots (triggers Svelte cleanup via snippet's destroy)
  for (const slotName of Object.keys(parent._snippets)) {
    const snippetIndex = parent._snippets[slotName].indexOf(child._snippet!);
    if (snippetIndex !== -1) {
      parent._snippets[slotName].splice(snippetIndex, 1);
      break;
    }
  }

  // Remove from children array
  parent.children.splice(childIndex, 1);

  flushSync();
}

/**
 * Recursively deregister a component and all its descendants.
 * Handles both dynamic children (in _snippets) and static children (in children array).
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
    // Find current slot
    for (const slotName of Object.keys(parent._snippets)) {
      const snippetIndex = parent._snippets[slotName].indexOf(child._snippet!);
      if (snippetIndex !== -1) {
        if (slotName === targetSlot) {
          // Same parent, same slot - nothing to do
          return;
        }
        // Same parent, different slot - move snippet without recreating
        parent._snippets[slotName].splice(snippetIndex, 1);
        if (!parent._snippets[targetSlot]) {
          parent._snippets[targetSlot] = [];
        }
        parent._snippets[targetSlot].push(child._snippet!);
        flushSync();
        return;
      }
    }
    // Snippet not found in any slot - shouldn't happen, but nothing to do
    return;
  }

  // Different parent - full reparenting

  // Remove snippet from current parent's slots
  for (const slotName of Object.keys(parent._snippets)) {
    const snippetIndex = parent._snippets[slotName].indexOf(child._snippet!);
    if (snippetIndex !== -1) {
      parent._snippets[slotName].splice(snippetIndex, 1);
      break;
    }
  }

  // Flush to ensure old snippet cleanup completes before creating new one
  // This prevents race conditions with _svelteInstance
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

  // Create fresh snippet for new parent
  const newSnippet = child.createSnippet();
  child._snippet = newSnippet;
  child._parentComponent = newParent;

  // Add to new parent's slots
  if (!newParent._snippets[targetSlot]) {
    newParent._snippets[targetSlot] = [];
  }
  newParent._snippets[targetSlot].push(newSnippet);

  // Add to new parent's children
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

  // Get the snippet array for this target
  const snippets = parent._snippets[target];
  if (!snippets) {
    logger.warn('Container', '@reorder: Target not found', { target });
    return;
  }

  // Find current position
  const fromIndex = snippets.indexOf(child._snippet);
  if (fromIndex === -1 || fromIndex === index) {
    return; // Not found or already at position
  }

  logger.debug('Container', '@reorder', { childId, target, from: fromIndex, to: index });

  // Simple array reorder: remove from old position, insert at new position
  const newArray = [...snippets];
  const [moved] = newArray.splice(fromIndex, 1);
  newArray.splice(index, 0, moved);
  parent._snippets[target] = newArray;

  flushSync();
}

/**
 * Create Component instances for static children.
 *
 * Static children are declared in MATLAB constructor and included in the
 * parent's @insert payload. They're full Component instances with snippets,
 * just rendered in fixed template locations instead of dynamic slots.
 *
 * @param parent - Parent component to attach children to
 * @param defs - Array of static child component definitions
 * @returns Map keyed by target name, each containing an array of children for that target
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

    // Push to target array (multiple children can share the same target)
    if (!result.has(def.target)) {
      result.set(def.target, []);
    }
    result.get(def.target)!.push({
      snippet,
      props: child.svelteProps
    });

    // Recurse for nested static children
    if (def.component.staticChildren?.length) {
      const nested = await createStaticChildren(child, def.component.staticChildren);
      // Merge nested results (concatenate arrays for same targets)
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
