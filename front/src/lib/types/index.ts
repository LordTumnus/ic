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
export interface PropEventData {
  /** Property name */
  name: string;
  /** Property value */
  value: unknown;
}

/** Subscription callback. Receives event name and data. */
export type EventCallback = (name: string, data: unknown) => void;

/** Unsubscribe function returned by subscribe(). */
export type Unsubscribe = () => void;
