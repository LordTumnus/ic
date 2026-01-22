/**
 * Registry - Central lookup for all registered components.
 *
 */

import type { JsEvent, Registrable } from '../types';

/**
 * Registry class - singleton that maintains a flat map of all components.
 *
 */
class Registry {
  private static _instance: Registry | null = null;

  /** Map of component ID → component instance */
  private components: Map<string, Registrable> = new Map();

  private constructor() {
    // Private constructor enforces singleton
  }

  /** Get the singleton instance. */
  static get instance(): Registry {
    if (!Registry._instance) {
      Registry._instance = new Registry();
    }
    return Registry._instance;
  }

  /**
   * Register a component in the registry.
   *
   * @param component - The component to register
   * @throws Error if a component with the same ID is already registered
   */
  register(component: Registrable): void {
    if (this.components.has(component.id)) {
      throw new Error(`Component with ID "${component.id}" is already registered.`);
    }
    this.components.set(component.id, component);
  }

  /**
   * Remove a component from the registry.
   *
   * @param id - The ID of the component to remove
   * @returns true if the component was found and removed, false otherwise
   */
  deregister(id: string): boolean {
    return this.components.delete(id);
  }

  /**
   * Retrieve a component by ID.
   *
   * @param id - The component ID to look up
   * @returns The component, or undefined if not found
   */
  get(id: string): Registrable | undefined {
    return this.components.get(id);
  }

  /**
   * Dispatch an event to the target component.
   *
   * Called by Bridge when events arrive from MATLAB.
   * Routes the event to the correct component based on event.component ID.
   *
   * Async to support sequential event processing - Bridge awaits each dispatch
   * to ensure events like @insert complete before subsequent events.
   *
   * @param event - The event to dispatch
   */
  async dispatch(event: JsEvent): Promise<void> {
    const component = this.components.get(event.component);

    if (!component) {
      console.warn(
        `[Registry] No component found for ID "${event.component}". Event "${event.name}" dropped.`
      );
      return;
    }

    await component.receive(event.id, event.name, event.data);
  }

  /**
   * Check if a component is registered.
   *
   * @param id - The component ID to check
   */
  has(id: string): boolean {
    return this.components.has(id);
  }

  /**
   * Get the number of registered components.
   */
  get size(): number {
    return this.components.size;
  }

  /**
   * Reset the Registry state. Used for testing.
   *
   * @internal
   */
  _reset(): void {
    this.components.clear();
  }
}

export default Registry;
