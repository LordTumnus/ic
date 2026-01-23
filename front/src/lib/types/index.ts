/**
 * Core types for MATLAB-JavaScript communication.
 */



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

/** Data for @insert events. Sent by PARENT to create a CHILD. */
export interface InsertEventData {
  /** MATLAB class name (e.g., "ic.components.Button") */
  type: string;
  /** Unique ID for the new component */
  id: string;
  /** Reactive properties with their current values */
  props: PropDefinition[];
  /** Reactive events the component can emit to MATLAB */
  events: EventDefinition[];
  /** Reactive methods that MATLAB can invoke on the component */
  methods: MethodDefinition[];
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


/** Subscription callback. Receives event name and data. */
export type EventCallback = (id: string, name: string, data: unknown) => void;

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
   * @param name - Event name (e.g., "@insert", "@prop/Label", "click")
   * @param data - Event payload
   */
  receive(id: string, name: string, data: unknown): Promise<void>;
}
