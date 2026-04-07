/**
 * Core types for MATLAB-JavaScript communication.
 */

import type { Snippet } from 'svelte';


/** HTML connector from MATLAB (uihtml htmlComponent object). */
export interface MatlabHTML extends EventTarget {
  sendEventToMATLAB(eventName: string, eventData?: unknown): void;
}

/** Event received from / sent to MATLAB. */
export interface JsEvent {
  /** Target component ID */
  component: string;
  /** Event name */
  name: string;
  /** Event payload */
  data: unknown;
  /** Unique ID for request/response correlation */
  id: string;
}

/** Response to an event that expects a reply. */
export interface Resolution {
  success: boolean;
  data: unknown;
}

/** Payload for frontend → MATLAB request/response. */
export interface RequestPayload {
  /** Unique request ID for response correlation */
  id: string;
  /** Request data */
  data: unknown;
}

/** Publish an event to MATLAB. */
export type PublishFn = (name: string, data?: unknown) => void;

/** Subscribe to events from MATLAB. Returns an unsubscribe function. */
export type SubscribeFn = (name: string, callback: EventCallback) => Unsubscribe;

/** Send a request to MATLAB and await the response. */
export type RequestFn = (name: string, data?: unknown) => Promise<Resolution>;

/** Component definition sent within @insert events. */
export interface ComponentDefinition {
  /** MATLAB class name (e.g., "ic.components.Button") */
  type: string;
  /** Unique ID for the new component */
  id: string;
  /** Reactive properties with their current values (includes 'targets' for containers) */
  props: PropDefinition[];
  /** Reactive events the component can emit to MATLAB */
  events: EventDefinition[];
  /** Reactive methods that MATLAB can invoke on the component */
  methods: MethodDefinition[];
  /** Mixin capabilities present on this component (e.g. "stylable", "effectable") */
  mixins: string[];
  /** Pre-rendered children declared in MATLAB constructor (recursive) */
  staticChildren?: InsertEventData[];
}

/** Data for @insert events. Sent by PARENT to create a CHILD. */
export interface InsertEventData {
  /** The component definition */
  component: ComponentDefinition;
  /** Target container element name  */
  target: string;
}

/** Data for @remove events. */
export interface RemoveEventData {
  id: string;
}

/** Data for @reparent events. */
export interface ReparentEventData {
  /** Component being moved */
  id: string;
  /** New parent ID */
  parent: string;
  /** Target container element name  */
  target: string;
}

/** Data for @reorder events. */
export interface ReorderEventData {
  /** Component being moved */
  id: string;
  /** New index within the target (0-based) */
  index: number;
  /** Target container element name */
  target: string;
}

/** Data for @prop events. */
export interface PropDefinition {
  /** Property name */
  name: string;
  /** Property value */
  value: unknown;
}

/**
 * Definition for an event that a component can publish to MATLAB.
*
*/
export interface EventDefinition {
  /** Event name sent to MATLAB */
  name: string;
}

/**
 * Definition for a method that MATLAB can invoke on a component.
*
*/
export interface MethodDefinition {
  /** Method name */
  name: string;
}

/**
 * A child component entry: renderable snippet + reactive metadata.
 *
 * `props` is a live reactive proxy into the child's data state.
 * `events` is a proxy into the child's event state — set a handler to intercept.
 * `methods` is a proxy into the child's method state — call to invoke.
 * `meta` provides name lists for building inspector UIs.
 *
 * Used for both dynamic children (via @insert) and static children
 * (declared in MATLAB constructor). For standalone Svelte usage
 * without an IC Component backing, use the `entry()` helper.
 *
 * Headless components omit `snippet` (no DOM).
 * Attachable components omit `snippet` but provide `attach`/`detach`
 * for mounting into a parent-provided element.
 */
export interface ChildEntry {
  snippet?: Snippet;
  attach?: (target: HTMLElement, context?: Map<any, any>) => void;
  detach?: () => void;
  id: string;
  type: string;
  props: Record<string, unknown>;
  events: Record<string, ((data?: unknown) => void) | undefined>;
  methods: Record<string, ((data?: unknown) => Resolution | Promise<Resolution>) | undefined>;
  meta: {
    propNames: string[];
    eventNames: string[];
    methodNames: string[];
    mixins: string[];
  };
}

/**
 * Children organized by target slot name.
 * Keys are target names defined in MATLAB's Targets property.
 */
export type ChildEntries = Record<string, ChildEntry[]>;

/**
 * Map of static child targets to arrays of child entries.
 * Multiple children can share the same target slot.
 */
export type StaticChildrenMap = Map<string, ChildEntry[]>;

/**
 * Create a minimal ChildEntry wrapping a raw Svelte snippet.
 * Use this for standalone Svelte usage (no IC Component backing).
 */
export function entry(snippet: Snippet): ChildEntry {
  return {
    snippet, id: '', type: '',
    props: {}, events: {}, methods: {},
    meta: { propNames: [], eventNames: [], methodNames: [], mixins: [] }
  };
}

/** Subscription callback. Receives event name and data. May be async. */
export type EventCallback = (id: string, name: string, data: unknown) => void | Promise<void>;

/** Unsubscribe function returned by subscribe(). */
export type Unsubscribe = () => void;

/**
 * Minimal interface for components that can be registered in the Registry.
 *
 */
export interface Registrable {
  /** Unique component identifier */
  readonly id: string;
  /**
   * Handle an incoming event.
   *
   * Returns a Promise to support async operations like dynamic imports.
   *
   * @param id - Unique event ID for request/response correlation
   * @param name - Event name
   * @param data - Event payload
   */
  receive(id: string, name: string, data: unknown): Promise<void>;
}

// ============================================================================
// Styling Event Data
// ============================================================================

/** Data for @style events (instance-level styling). */
export interface StyleEventData {
  selector: string;
  styles: Record<string, string>;
}

/** Data for @clearStyle events. */
export interface ClearStyleEventData {
  selector: string;
}

/** Data for @globalStyle events (type-level styling). */
export interface GlobalStyleEventData {
  type: string;
  selector: string;
  styles: Record<string, string>;
}

/** Data for @clearGlobalStyle events. */
export interface ClearGlobalStyleEventData {
  type: string;
  selector: string;
}

/** Data for @clearGlobalStyles events. */
export interface ClearGlobalStylesEventData {
  type: string;
}

/** Data for @keyframes events. */
export interface KeyframesEventData {
  name: string;
  frames: Record<string, Record<string, string>>;
}

/** Data for @removeKeyframes events. */
export interface RemoveKeyframesEventData {
  name: string;
}

/** Data for @vars events. Sets CSS custom properties on a scoped selector. */
export interface VarsEventData {
  selector: string;
  vars: Record<string, string>;
}

/** Data for @theme events. CSS variables as kebab-case keys with values ready for CSS. */
export type ThemeEventData = Record<string, string>;

// ============================================================================
// Effect Event Data
// ============================================================================

/** Event data for creating a JS effect. */
export interface JsEffectEventData {
  /** Unique effect ID (for removal) */
  id: string;
  /** Map of parameter name → component ID (single) or component IDs (array) */
  components: Record<string, string | string[]>;
  /** Arrow function expression: (p1, p2) => { ... } */
  expression: string;
}

/** Event data for removing a JS effect. */
export interface JsEffectRemoveEventData {
  id: string;
}

// ============================================================================
// Keyboard Event Data
// ============================================================================

/** Data for @onKey / @updateKey / @offKey events from MATLAB. */
export interface KeyEventData {
  shortcut: string;
  preventDefault?: boolean;
  stopPropagation?: boolean;
}

/** Data published by KeyboardManager on shortcut match → MATLAB. */
export interface KeyPressedEventData {
  shortcut: string;
  key: string;
  code: string;
}
