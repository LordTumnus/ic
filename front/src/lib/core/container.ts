/**
 * Container - Event handlers for @insert, @remove, @reparent.
 *
 * This module exports handlers that orchestrate Factory, Registry, and Component
 * to manage parent-child relationships. Separated from Component to avoid
 * circular dependencies (Component ↔ Factory).
 */

import type { InsertEventData, RemoveEventData, ReparentEventData } from '../types';
import type Component from './component.svelte';
import Factory from './factory';
import Registry from './registry';

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

  // Create snippet and add to slots
  const snippet = child.createSnippet();
  child._snippet = snippet;

  if (!parent._snippets[target]) {
    throw new Error(`[Component] @insert: Target slot "${target}" not defined in component "${parent.id}"`);
  }
  parent._snippets[target].push(snippet);
  parent.children.push(child);
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
    console.warn(`[Component] @remove: Child "${childId}" not found in "${parent.id}"`);
    return;
  }

  const child = parent.children[childIndex];

  // Remove snippet from slots (triggers Svelte cleanup via snippet's destroy)
  for (const slotName of Object.keys(parent._snippets)) {
    const snippetIndex = parent._snippets[slotName].indexOf(child._snippet!);
    if (snippetIndex !== -1) {
      parent._snippets[slotName].splice(snippetIndex, 1);
      break;
    }
  }

  // Deregister from global registry
  Registry.instance.deregister(childId);

  // Remove from children array
  parent.children.splice(childIndex, 1);
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
    console.warn(`[Component] @reparent: Child "${childId}" not found in "${parent.id}"`);
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
    console.error(`[Component] @reparent: New parent "${newParentId}" not found`);
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
