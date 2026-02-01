/**
 * Core types for MATLAB-JavaScript communication.
 */

import type { Snippet } from 'svelte';


/** HTML connector from MATLAB. */
export interface MatlabHTML extends EventTarget {
  Data: JsEvent[]
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
 * Snippets record passed to Svelte components.
 * Keys are target names defined in MATLAB's Targets property.
 */
export type Snippets = Record<string, Snippet[]>;

/** Subscription callback. Receives event name and data. May be async. */
export type EventCallback = (id: string, name: string, data: unknown) => void | Promise<void>;

/** Unsubscribe function returned by subscribe(). */
export type Unsubscribe = () => void;

/**
 * Static child -> renderable snippet and its props
 */
export interface StaticChild {
  snippet: Snippet;
  props: Record<string, unknown>;  // The child's svelteProps
}

/**
 * Map of static child targets to arrays of their snippets and props.
 * Multiple children can share the same target slot.
 */
export type StaticChildrenMap = Map<string, StaticChild[]>;

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

/** Data for @theme events. CSS variables as kebab-case keys with values ready for CSS. */
export type ThemeEventData = Record<string, string>;
