/**
 * Component - Base class for all UI components.
 *
 * This class manages:
 * - Reactive props that sync with MATLAB
 * - Event subscriptions and dispatch
 * - Svelte component mounting/unmounting
 * - Parent-child relationships via child entries
 *
 * Must be in a .svelte.ts file for $state rune to work!
 */

import { mount, unmount } from 'svelte';
import type { Component as SvelteComponent } from 'svelte';
import type {
  Registrable,
  EventCallback,
  Unsubscribe,
  PropDefinition,
  EventDefinition,
  MethodDefinition,
  Resolution,
  RequestPayload,
  ChildEntry,
  ChildEntries,
  StyleEventData,
  ClearStyleEventData,
  KeyframesEventData,
  RemoveKeyframesEventData,
  VarsEventData,
  JsEffectEventData,
  JsEffectRemoveEventData,
  KeyEventData,
  BinaryPushData
} from '../types';
import Bridge from './bridge';
import { handleInsert, handleRemove, handleReorder, handleReparent } from './container';
import EffectManager from './effect-manager.svelte';
import { KeyboardManager } from './keyboard-manager';
import StyleManager from './style-manager';
import logger from './logger';
import { cacheEmbeddedAssets } from '$lib/utils/asset-cache';
import { fetchBinary } from '$lib/utils/binary-channel';

/**
 * Component class - base class for all UI components.
 *
 * Implements `Registrable` so it can be registered in the Registry
 * and receive events from MATLAB.
 */
class Component implements Registrable {
  /** Unique component identifier (e.g., "btn1", "ic-frame"). */
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
   * Flat array of child entries. Containers filter by type/mixin when rendering.
   * @internal Used by container.ts
   */
  _childEntries: ChildEntries = $state([]);

  /**
   * Reference to parent component (for reparenting).
   * @internal Used by container-logic.ts
   */
  _parentComponent: Component | null = null;

  /**
   * This component's ChildEntry in its parent's _childEntries.
   * @internal Used by container.ts for reparenting
   */
  _childEntry: ChildEntry | null = null;

  /**
   * Whether this component has been mounted to the DOM.
   * Set to true by DynamicChild's $effect via notifyMounted().
   */
  private _isMounted = false;

  /** The root DOM element, found by DynamicChild via getElementById. */
  private _wrapperElement: Element | null = null;

  /** Callbacks waiting for the component to mount (flushed in setup()). */
  private _mountedCallbacks: ((element: Element) => void)[] = [];

  /** Event subscriptions: event name → set of callbacks. */
  private subscriptions: Map<string, Set<EventCallback>> = new Map();

  /** The mounted Svelte instance (only used by root Frame's mount/unmount). */
  private _svelteInstance: Record<string, unknown> | null = null;

  /** The Svelte component class to use for mounting. */
  private _svelteComponent: SvelteComponent<Record<string, unknown>> | null = null;

  /** Reactive storage for data properties only. */
  private _dataState: Record<string, unknown>;

  /** Reactive storage for method implementations only. */
  private _methodState: Record<string, unknown>;

  /** Reactive storage for event handlers (enabled/disabled by MATLAB listeners). */
  private _eventState: Record<string, unknown>;

  /** Data property names (camelCase). */
  readonly propNames: string[];

  /** Method names (camelCase). */
  readonly methodNames: string[];

  /** Event names (camelCase). */
  readonly eventNames: string[];

  /** Mixin capabilities present on this component (e.g. "stylable", "effectable"). */
  readonly mixins: string[];

  /** Flag to prevent echo when receiving updates from MATLAB. */
  private _updatingFromMatlab = false;

  /** Per-property debounce timers for throttling MATLAB sync. */
  private _propDebounceTimers: Map<string, number> = new Map();

  /** Debounce delay (ms) for prop → MATLAB publishing. */
  private static readonly PROP_DEBOUNCE_MS = 50;

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
    svelteComponent: SvelteComponent<any> | null = null,
    mixins: string[] = []
  ) {
    this.id = id;
    this.type = type;
    this._dataState = $state({});
    this._methodState = $state({});
    this._eventState = $state({});
    this._svelteComponent = svelteComponent;
    this.mixins = mixins;

    // Store name lists for external consumers (e.g. EffectManager)
    this.propNames = propDefinitions.map(p => p.name);
    this.methodNames = methodDefinitions.map(m => m.name);
    this.eventNames = eventDefinitions.map(e => e.name);

    // Create state object with getters/setters pointing to $state
    // This enables reactivity in the direction Svelte -> MATLAB
    const stateObj: Record<string, unknown> = {};
    for (const { name, value } of propDefinitions) {
      cacheEmbeddedAssets(value);
      this._dataState[name] = value;

      Object.defineProperty(stateObj, name, {
        get: () => this._dataState[name],
        set: (value: unknown) => {
          this._dataState[name] = value;
          // Debounced publish to MATLAB (unless this update came from MATLAB)
          if (!this._updatingFromMatlab) {
            const existing = this._propDebounceTimers.get(name);
            if (existing !== undefined) clearTimeout(existing);
            this._propDebounceTimers.set(name,
              window.setTimeout(() => {
                this._propDebounceTimers.delete(name);
                this.publish(`@prop/${name}`, this._dataState[name]);
              }, Component.PROP_DEBOUNCE_MS)
            );
          }
        },
        enumerable: true,
        configurable: true
      });
    }

    // Wire up event handlers: initially disabled (enabled when MATLAB adds a listener)
    for (const eventDef of eventDefinitions) {
      this._eventState[eventDef.name] = undefined;
      Object.defineProperty(stateObj, eventDef.name, {
        get: () => this._eventState[eventDef.name],
        set: (value: unknown) => {
          this._eventState[eventDef.name] = value;
        },
        enumerable: true,
        configurable: true
      });
    }

    // Wire up method handlers (reactive storage so Svelte components can re-assign)
    for (const methodDef of methodDefinitions) {
      const methodName = methodDef.name;
      this._methodState[methodName] = (data: unknown): Resolution => {
        return { success: true, data: null };
      }

      Object.defineProperty(stateObj, methodName, {
        get: () => this._methodState[methodName],
        set: (value: (data?: unknown) => Resolution) => {
          this._methodState[methodName] = value;
        },
        enumerable: true,
        configurable: true
      });
    }

    // Expose child entries as 'childEntries' prop
    Object.defineProperty(stateObj, 'childEntries', {
      get: () => this._childEntries,
      enumerable: true,
      configurable: true
    });

    // Expose communication primitives for advanced Svelte component usage
    Object.defineProperty(stateObj, 'publish', {
      value: (name: string, data?: unknown) => this.publish(name, data),
      enumerable: true,
      configurable: true
    });

    Object.defineProperty(stateObj, 'subscribe', {
      value: (name: string, callback: EventCallback) => this.subscribe(name, callback),
      enumerable: true,
      configurable: true
    });

    Object.defineProperty(stateObj, 'request', {
      value: (name: string, data?: unknown) => this.request(name, data),
      enumerable: true,
      configurable: true
    });

    // Binary channel (only for components with BinaryChannel mixin)
    if (this.mixins.includes('binarychannel')) {
      Object.defineProperty(stateObj, 'onBinary', {
        value: (channel: string, callback: (buffer: ArrayBuffer) => void): Unsubscribe => {
          return this.subscribe(`@binary/${channel}`, async (_id, _name, data) => {
            const { file, v } = data as BinaryPushData;
            const buffer = await fetchBinary(file, v);
            callback(buffer);
          });
        },
        enumerable: true,
        configurable: true
      });

      Object.defineProperty(stateObj, 'requestBinary', {
        value: async (channel: string, data?: unknown): Promise<ArrayBuffer> => {
          const requestId = crypto.randomUUID();
          return new Promise<ArrayBuffer>((resolve, reject) => {
            const unsub = this.subscribe(`@binaryResp/${requestId}`, async (_id, _name, respData) => {
              unsub();
              const resp = respData as BinaryPushData | { error: string };
              if ('error' in resp) {
                reject(new Error(resp.error));
                return;
              }
              try {
                const buffer = await fetchBinary(resp.file, resp.v);
                this.publish(`@binaryEvict/${requestId}`, null);
                resolve(buffer);
              } catch (e) {
                reject(e);
              }
            });
            Bridge.instance.send([{
              component: this.id,
              name: `@binaryRequest/${channel}`,
              data: { id: requestId, data },
              id: requestId
            }]);
          });
        },
        enumerable: true,
        configurable: true
      });
    }

    // Expose the component ID so Svelte components can set it on their root element
    Object.defineProperty(stateObj, 'id', { value: id, enumerable: true });

    this.svelteProps = stateObj;

    // Set up built-in event handlers
    this._setupListeners(propDefinitions.map((p) => p.name), methodDefinitions.map((m) => m.name));

    // Enable/disable event handlers based on MATLAB listener presence
    this.subscribe('@listenEvent', (_id, _name, data) => {
      const eventName = data as string;
      this._eventState[eventName] = (eventData?: unknown) => {
        this.publish(`@event/${eventName}`, eventData);
      };
    });
    this.subscribe('@unlistenEvent', (_id, _name, data) => {
      const eventName = data as string;
      this._eventState[eventName] = undefined;
    });

    // Set up container handlers (@insert, @remove, @reparent, @reorder)
    this.subscribe('@insert', (id, name, data) => handleInsert(this, id, name, data));
    this.subscribe('@remove', (id, name, data) => handleRemove(this, id, name, data));
    this.subscribe('@reparent', (id, name, data) => handleReparent(this, id, name, data));
    this.subscribe('@reorder', (id, name, data) => handleReorder(this, id, name, data));

    // Set up style handlers (only if component has Stylable mixin and is not headless)
    const isHeadless = this.mixins.includes('headless');
    if (this.mixins.includes('stylable') && !isHeadless) {
      this.subscribe('@style', (_id, _name, data) => {
        const { selector, styles } = data as StyleEventData;
        StyleManager.instance.setStyles(this.id, selector, styles);
      });
      this.subscribe('@clearStyle', (_id, _name, data) => {
        const { selector } = data as ClearStyleEventData;
        StyleManager.instance.clearStyle(this.id, selector);
      });
      this.subscribe('@clearStyles', () => {
        StyleManager.instance.clearStyles(this.id);
      });
      this.subscribe('@keyframes', (_id, _name, data) => {
        const { name, frames } = data as KeyframesEventData;
        StyleManager.instance.setKeyframes(this.id, name, frames);
      });
      this.subscribe('@removeKeyframes', (_id, _name, data) => {
        const { name } = data as RemoveKeyframesEventData;
        StyleManager.instance.removeKeyframes(this.id, name);
      });
      this.subscribe('@vars', (_id, _name, data) => {
        const { selector, vars } = data as VarsEventData;
        StyleManager.instance.setVars(this.id, selector, vars);
      });
    }

    // JS effects (only if component has Effectable mixin and is not headless)
    if (this.mixins.includes('effectable') && !isHeadless) {
      this.subscribe('@jsEffect', (_id, _name, data) => {
        EffectManager.instance.createEffect(data as JsEffectEventData);
      });
      this.subscribe('@jsEffectRemove', (_id, _name, data) => {
        EffectManager.instance.removeEffect((data as JsEffectRemoveEventData).id);
      });
    }

    // Keyboard shortcuts (only if component has Keyable mixin and is not headless)
    if (this.mixins.includes('keyable') && !isHeadless) {
      KeyboardManager.instance.register(this.id);
      this.subscribe('@onKey', (_id, _name, data) => {
        const { shortcut, preventDefault, stopPropagation } = data as KeyEventData;
        KeyboardManager.instance.addShortcut(this.id, shortcut, { preventDefault, stopPropagation });
      });
      this.subscribe('@updateKey', (_id, _name, data) => {
        const { shortcut, preventDefault, stopPropagation } = data as KeyEventData;
        KeyboardManager.instance.updateShortcut(this.id, shortcut, { preventDefault, stopPropagation });
      });
      this.subscribe('@offKey', (_id, _name, data) => {
        KeyboardManager.instance.removeShortcut(this.id, (data as KeyEventData).shortcut);
      });
      this.subscribe('@clearKeys', () => {
        KeyboardManager.instance.clearShortcuts(this.id);
      });
    }
  }

  /**
   * Set up listeners for reactive props and methods.
   */
  private _setupListeners(properties: string[], methods: string[]): void {
    // Handle @prop events from MATLAB
    for (const prop of properties) {
      this.subscribe(`@prop/${prop}`, (_id: string, _name: string, data: unknown) => {
        this._updatingFromMatlab = true;
        cacheEmbeddedAssets(data);
        this._dataState[prop] = data;
        this._updatingFromMatlab = false;
      });
    }

    // Handle @method events from MATLAB
    for (const method of methods) {
      this.subscribe(method, (id: string, _name: string, data: unknown) => {
        const methodFunc = this._methodState[method] as (data?: unknown) => Resolution;
        const result = methodFunc(data);
        this.publish(`@resp/${id}`, result);
      });
    }
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
   * Update a prop value without publishing to MATLAB.
   *
   * Used by DevTools for optimistic updates that bypass the reactive
   * @prop/ channel (the request path handles MATLAB synchronization).
   */
  setPropSilently(name: string, value: unknown): void {
    this._updatingFromMatlab = true;
    this._dataState[name] = value;
    this._updatingFromMatlab = false;
  }

  /**
   * Publish an event to MATLAB.
   *
   * @param name - Event name (e.g., "click", "@prop/Label")
   * @param data - Event payload
   */
  publish(name: string, data?: unknown): void {
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
   * Send a request to MATLAB and await the response.
   *
   * This mirrors MATLAB's `publish` → `Promise` pattern but in reverse:
   * the frontend sends `@request/{name}` with a unique ID, and MATLAB
   * responds with `@resp/{id}` containing a Resolution.
   *
   * @param name - Request name (camelCase, e.g., "loadChunk")
   * @param data - Request payload
   * @returns Promise that resolves with MATLAB's response
   */
  request(name: string, data?: unknown): Promise<Resolution> {
    const requestId = crypto.randomUUID();

    return new Promise<Resolution>((resolve) => {
      // Listen for MATLAB's response on @resp/{requestId}
      const unsub = this.subscribe(`@resp/${requestId}`, (_id, _name, responseData) => {
        unsub();
        resolve(responseData as Resolution);
      });

      // Send the request to MATLAB
      Bridge.instance.send([
        {
          component: this.id,
          name: `@request/${name}`,
          data: { id: requestId, data } satisfies RequestPayload,
          id: requestId
        }
      ]);
    });
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
   * Callbacks are awaited sequentially to ensure proper ordering.
   * This is critical for @insert handlers which are async and must
   * complete before subsequent events (like method calls) are processed.
   *
   * @param id - Unique event ID
   * @param name - Event name
   * @param data - Event payload
   */
  async receive(id: string, name: string, data: unknown): Promise<void> {
    const callbacks = this.subscriptions.get(name);
    if (callbacks) {
      for (const callback of callbacks) {
        await callback(id, name, data);
      }
    }
  }

  /**
   * Synchronous variant of receive().  Callbacks are invoked without
   * awaiting — their side effects run synchronously.  Used by the Bridge
   * after preloading, when all handlers are known to be synchronous, to
   * avoid microtask yields that let Svelte render intermediate states.
   */
  receiveSync(id: string, name: string, data: unknown): void {
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
   * Register a callback to run when this component's snippet is mounted to the DOM.
   * If already mounted, the callback fires immediately (synchronously).
   *
   * Use this instead of polling/retrying for DOM element availability.
   */
  onMounted(callback: (element: Element) => void): void {
    if (this._isMounted && this._wrapperElement) {
      callback(this._wrapperElement);
    } else {
      this._mountedCallbacks.push(callback);
    }
  }

  /** Flush all pending mount callbacks. Called via notifyMounted(). */
  private _flushMounted(element: Element): void {
    this._isMounted = true;
    this._wrapperElement = element;
    for (const cb of this._mountedCallbacks) {
      cb(element);
    }
    this._mountedCallbacks = [];
  }

  /**
   * Set the Svelte component class (used by factory after construction).
   *
   * @param component - Svelte component class
   */
  setSvelteComponent(component: SvelteComponent<Record<string, unknown>>): void {
    this._svelteComponent = component;
  }

  /** Expose the Svelte component class for DynamicChild rendering. */
  get svelteComponentClass(): SvelteComponent<Record<string, unknown>> | null {
    return this._svelteComponent;
  }

  /**
   * Notify that this component has been mounted to the DOM.
   * Called by DynamicChild's $effect after the component renders.
   */
  notifyMounted(element: Element | null): void {
    if (element) {
      this._flushMounted(element);
    }
  }

  /**
   * Notify that this component has been unmounted from the DOM.
   * Called by DynamicChild's $effect cleanup.
   */
  notifyUnmounted(): void {
    this._isMounted = false;
    this._wrapperElement = null;
    StyleManager.instance.clearStyles(this.id);
    KeyboardManager.instance.unregister(this.id);
  }
}

export default Component;
