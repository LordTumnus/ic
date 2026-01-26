/**
 * Factory - Dynamically loads Svelte components and creates Component instances.
 *
 */

import type { Component as SvelteComponent } from 'svelte';
import type { ComponentDefinition } from '../types';
import Component from './component.svelte';
import componentMap from './component-map';

/**
 * Factory class - singleton that handles dynamic component loading and creation.
 *
 */
class Factory {
  private static _instance: Factory | null = null;

  private constructor() {
    // Private constructor enforces singleton
  }

  /** Get the singleton instance. */
  static get instance(): Factory {
    if (!Factory._instance) {
      Factory._instance = new Factory();
    }
    return Factory._instance;
  }

  /**
   * Load a Svelte component class by its MATLAB type.
   *
   * @param type - MATLAB class name
   * @returns Promise resolving to the Svelte component class
   * @throws Error if the type is not registered in component-map.ts
   */
  async loadSvelteComponent(type: string): Promise<SvelteComponent<Record<string, unknown>>> {
    const loader = componentMap[type];
    if (!loader) {
      throw new Error(
        `Unknown component type "${type}". ` +
        `Make sure it's registered in component-map.ts.`
      );
    }

    const module = await loader() as { default: SvelteComponent<Record<string, unknown>> };
    return module.default;
  }

  /**
   * Create a Component instance from a ComponentDefinition.
   *
   *
   * @param definition - The component definition from MATLAB
   * @returns Promise resolving to a ready-to-mount Component instance
   * @throws Error if the MATLAB type is not registered in component-map.ts
   */
  async create(definition: ComponentDefinition): Promise<Component> {
    const { type, id, props, events, methods, targets } = definition;

    const svelteComp = await this.loadSvelteComponent(type);

    return new Component(id, type, props, events, methods, targets, svelteComp);
  }

  /**
   * Check if a MATLAB type has a registered Svelte component.
   *
   * @param type - MATLAB class name to check
   */
  hasComponent(type: string): boolean {
    return type in componentMap;
  }

  /**
   * Get all registered MATLAB type names.
   *
   * Useful for debugging and introspection.
   */
  getRegisteredTypes(): string[] {
    return Object.keys(componentMap);
  }
}

export default Factory;
