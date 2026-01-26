/**
 * Component - Base class for all UI components.
 *
 * This class manages:
 * - Reactive props that sync with MATLAB
 * - Event subscriptions and dispatch
 * - Svelte component mounting/unmounting
 * - Parent-child relationships via snippets
 *
 * Must be in a .svelte.ts file for $state rune to work!
 */

import { mount, unmount, createRawSnippet } from 'svelte';
import type { Component as SvelteComponent, Snippet } from 'svelte';
import type {
  Registrable,
  EventCallback,
  Unsubscribe,
  PropDefinition,
  EventDefinition,
  MethodDefinition,
  Resolution,
  Snippets
} from '../types';
import Bridge from './bridge';
import { handleInsert, handleRemove, handleReparent } from './container';


/**
 * Component class - base class for all UI components.
 *
 * Implements `Registrable` so it can be registered in the Registry
 * and receive events from MATLAB.
 */
class Component implements Registrable {
  /** Unique component identifier (e.g., "btn1", "@ic.frame"). */
  readonly id: string;

  /** MATLAB class name (e.g., "ic.components.Button"). */
  readonly type: string;

  /**
   * Reactive object with optional bidirectional MATLAB sync.
   *
   * **Note**: Regular destructuring without `$bindable` only syncs MATLAB → Svelte (one-way).
   * Use `$bindable()` for full bidirectional sync.
   */
  readonly svelteProps: Record<string, unknown>;

  /** Child components (reactive array for Svelte rendering). */
  children: Component[] = $state([]);

  /**
   * Child snippets organized by target slot name.
   * @internal Used by container.ts
   */
  _snippets: Snippets = $state({ default: [] });

  /**
   * Reference to parent component (for reparenting).
   * @internal Used by container-logic.ts
   */
  _parentComponent: Component | null = null;

  /**
   * This component's snippet (created lazily, used when inserted into a parent).
   * @internal Used by container-logic.ts
   */
  _snippet: Snippet | null = null;

  /** Event subscriptions: event name → set of callbacks. */
  private subscriptions: Map<string, Set<EventCallback>> = new Map();

  /** The mounted Svelte component instance (returned by mount()). */
  private _svelteInstance: Record<string, unknown> | null = null;

  /** The Svelte component class to use for mounting. */
  private _svelteComponent: SvelteComponent<Record<string, unknown>> | null = null;

  /**
   * Internal reactive storage for reactive properties and methods.
   */
  private _reactiveState: Record<string, unknown>;

  /** Flag to prevent echo when receiving updates from MATLAB. */
  private _updatingFromMatlab = false;

  /**
   * Create a new Component.
   *
   * @param id - Unique identifier
   * @param type - MATLAB class name
   * @param propDefinitions - Array of prop definitions with default values
   * @param eventDefinitions - Array of event definitions for JS → MATLAB events
   * @param svelteComponent - Optional Svelte component class for mounting
   */
  constructor(
    id: string,
    type: string,
    propDefinitions: PropDefinition[] = [],
    eventDefinitions: EventDefinition[] = [],
    methodDefinitions: MethodDefinition[] = [],
    targetDefinitions: string[] = ["default"],
    svelteComponent: SvelteComponent<any> | null = null
  ) {
    this.id = id;
    this.type = type;
    this._reactiveState = $state({});
    this._svelteComponent = svelteComponent;

    // Create state object with getters/setters pointing to $state
    // This enables reactivity in the direction Svelte -> MATLAB
    const stateObj: Record<string, unknown> = {};
    for (const { name, value } of propDefinitions) {
      this._reactiveState[name] = value;

      Object.defineProperty(stateObj, name, {
        get: () => this._reactiveState[name],
        set: (value: unknown) => {
          this._reactiveState[name] = value;
          // Publish to MATLAB unless this update came from MATLAB
          if (!this._updatingFromMatlab) {
            this.publish(`@prop/${name}`, value );
          }
        },
        enumerable: true,
        configurable: true
      });
    }

    // Wire up event handlers (non-reactive props that publish to MATLAB)
    for (const eventDef of eventDefinitions) {
      const propName = eventDef.name;
      stateObj[propName] = (eventData?: unknown) => {
        this.publish(`@event/${eventDef.name}`, eventData);
      };
    }

    // Wire up method handlers (non-reactive props that invoke Svelte methods)
    for (const methodDef of methodDefinitions) {
      const methodName = methodDef.name;
      this._reactiveState[methodName] = (data: unknown): Resolution => {
        return { success: true, data: null };
      }

      Object.defineProperty(stateObj, methodName, {
        get: () => this._reactiveState[methodName],
        set: (value: (data?: unknown) => Resolution) => {
          this._reactiveState[methodName] = value;
        },
        enumerable: true,
        configurable: true
      });
    }

    // Initialize snippet arrays for each target definition
    for (const targetName of targetDefinitions) {
      if (!this._snippets[targetName]) {
        this._snippets[targetName] = [];
      }
    }

    // Expose all snippets as a single 'snippets' prop
    Object.defineProperty(stateObj, 'snippets', {
      get: () => this._snippets,
      enumerable: true,
      configurable: true
    });

    this.svelteProps = stateObj;

    // Set up built-in event handlers
    this._setupListeners(propDefinitions.map((p) => p.name), methodDefinitions.map((m) => m.name));

    // Set up container handlers (@insert, @remove, @reparent)
    this.subscribe('@insert', (id, name, data) => handleInsert(this, id, name, data));
    this.subscribe('@remove', (id, name, data) => handleRemove(this, id, name, data));
    this.subscribe('@reparent', (id, name, data) => handleReparent(this, id, name, data));
  }

  /**
   * Set up listeners
   *
   * Handles:
   * - @properties events from MATLAB to update reactive props (MATLAB → Svelte)
   * - @methods events from MATLAB to invoke component methods (MATLAB → Svelte)
   */
  private _setupListeners(properties: string[], methods: string[]): void {
    // Handle @prop events from MATLAB
    for (const prop of properties) {
      this.subscribe(`@prop/${prop}`, (_id: string, _name: string, data: unknown) => {
        // Set flag to prevent echo back to MATLAB
        this._updatingFromMatlab = true;
        this._reactiveState[prop] = data;
        this._updatingFromMatlab = false;
      });
    }

    // Handle @method events from MATLAB
    for (const method of methods) {
      this.subscribe(method, (id: string, _name: string, data: unknown) => {
        const methodFunc = this._reactiveState[method] as (data?: unknown) => Resolution;
        const result = methodFunc(data);
        // Publish response back to MATLAB
        this.publish(`@resp/${id}`, result);
      });
    }
  }

  /**
   * Create a Svelte snippet for this component.
   *
   */
  createSnippet(): Snippet {
    return createRawSnippet(() => ({
      render: () => `<div style="display: contents" id="${this.id}"></div>`,
      setup: (element: Element) => {
        if (!this._svelteComponent) {
          console.error(`[Component] Cannot create snippet: "${this.id}" has no Svelte component`);
          return;
        }

        this._svelteInstance = mount(this._svelteComponent, {
          target: element,
          props: this.svelteProps
        });

        // Return cleanup function
        return () => {
          if (this._svelteInstance) {
            unmount(this._svelteInstance);
            this._svelteInstance = null;
          }
        };
      }
    }));
  }

  /**
   * Update a prop value (convenience method).
   *
   * Equivalent to `this.svelteProps[name] = value`
   *
   * @param name - Property name
   * @param value - New value
   */
  setProp(name: string, value: unknown): void {
    this.svelteProps[name] = value;
  }

  /**
   * Publish an event to MATLAB.
   *
   * @param name - Event name (e.g., "click", "@prop/Label")
   * @param data - Event payload
   */
  publish(name: string, data: unknown): void {
    Bridge.instance.send([
      {
        component: this.id,
        name,
        data,
        id: crypto.randomUUID()
      }
    ]);
  }

  /**
   * Subscribe to an event.
   *
   * @param name - Event name
   * @param callback - Function to call when event is received
   * @returns Unsubscribe function
   */
  subscribe(name: string, callback: EventCallback): Unsubscribe {
    if (!this.subscriptions.has(name)) {
      this.subscriptions.set(name, new Set());
    }
    this.subscriptions.get(name)!.add(callback);

    // Return unsubscribe function
    return () => {
      const callbacks = this.subscriptions.get(name);
      if (callbacks) {
        callbacks.delete(callback);
        if (callbacks.size === 0) {
          this.subscriptions.delete(name);
        }
      }
    };
  }

  /**
   * Handle an incoming event from MATLAB.
   *
   * @param id - Unique event ID
   * @param name - Event name
   * @param data - Event payload
   */
  async receive(id: string, name: string, data: unknown): Promise<void> {
    const callbacks = this.subscriptions.get(name);
    if (callbacks) {
      for (const callback of callbacks) {
        callback(id, name, data);
      }
    }
  }

  /**
   * Mount the Svelte component to the DOM.
   *
   * @param target - DOM element to mount into
   * @throws Error if no Svelte component was provided
   */
  mount(target: HTMLElement): void {
    if (!this._svelteComponent) {
      throw new Error(`Component "${this.id}" has no Svelte component to mount.`);
    }

    this._svelteInstance = mount(this._svelteComponent, {
      target,
      props: this.svelteProps
    });
  }

  /**
   * Unmount the Svelte component from the DOM.
   *
   * @param options - Unmount options (e.g., { outro: true } for transitions)
   */
  async unmount(options?: { outro?: boolean }): Promise<void> {
    if (this._svelteInstance) {
      await unmount(this._svelteInstance, options);
      this._svelteInstance = null;
    }
  }

  /**
   * Set the Svelte component class (used by factory after construction).
   *
   * @param component - Svelte component class
   */
  setSvelteComponent(component: SvelteComponent<Record<string, unknown>>): void {
    this._svelteComponent = component;
  }
}

export default Component;
