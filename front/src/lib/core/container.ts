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

  // Remove snippet from current parent's slots
  for (const slotName of Object.keys(parent._snippets)) {
    const snippetIndex = parent._snippets[slotName].indexOf(child._snippet!);
    if (snippetIndex !== -1) {
      parent._snippets[slotName].splice(snippetIndex, 1);
      break;
    }
  }

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
  const slotName = target || 'default';
  if (!newParent._snippets[slotName]) {
    newParent._snippets[slotName] = [];
  }
  newParent._snippets[slotName].push(newSnippet);

  // Add to new parent's children
  newParent.children.push(child);
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
