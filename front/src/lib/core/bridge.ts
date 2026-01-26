/**
 * Bridge - Handles bidirectional communication with MATLAB.
 *
 * Class singleton pattern. Access via `Bridge.instance`.
 */

import type { JsEvent, MatlabHTML } from '../types';

/** Callback type for dispatching events (typically to Registry). */
type Dispatcher = (event: JsEvent) => Promise<void>;

/**
 * Bridge class - singleton that manages MATLAB ↔ JS communication.
 *
 * The Bridge is a thin communication layer:
 * - Receives events from MATLAB via DataChanged listener
 * - Sends events to MATLAB by setting the Data property
 * - Delegates event routing to a dispatcher (set by main.ts to call Registry)
 */
class Bridge {
  private static _instance: Bridge | null = null;

  private matlabElement: MatlabHTML | null = null;
  private dispatcher: Dispatcher | null = null;

  private constructor() {
    // Private constructor enforces singleton
  }

  /** Get the singleton instance. */
  static get instance(): Bridge {
    if (!Bridge._instance) {
      Bridge._instance = new Bridge();
    }
    return Bridge._instance;
  }

  /**
   * Initialize the Bridge with the MATLAB HTML element.
   *
   * @param element - The HTML element MATLAB uses for communication
   * @throws Error if setup is called more than once
   */
  setup(element: MatlabHTML): void {
    if (this.matlabElement) {
      throw new Error('Bridge.setup() called more than once.');
    }

    this.matlabElement = element;
    this.matlabElement.addEventListener('DataChanged', this.handleDataChanged);
  }

  /**
   * Set the dispatcher function that routes events to components.
   *
   * @param dispatcher - Function to call for each incoming event
   */
  setDispatcher(dispatcher: Dispatcher): void {
    this.dispatcher = dispatcher;
  }

  /**
   * Send events to MATLAB.
   *
   * @param events - The events to send to MATLAB
   * @throws Error if Bridge has not been set up
   */
  send(events: JsEvent[]): void {
    if (!this.matlabElement) {
      throw new Error('Bridge.send() called before setup().');
    }

    this.matlabElement.Data = events;
  }

  /**
   * Check if the Bridge has been set up.
   */
  get isReady(): boolean {
    return this.matlabElement !== null;
  }

  /**
   * Reset the Bridge state. Used for testing.
   *
   * @internal
   */
  _reset(): void {
    if (this.matlabElement) {
      this.matlabElement.removeEventListener('DataChanged', this.handleDataChanged);
    }
    this.matlabElement = null;
    this.dispatcher = null;
  }

  /**
   * Handle MATLAB's DataChanged events.
   *
   * Events are processed sequentially with await to ensure proper ordering.
   * This prevents race conditions where a component receives events before
   * it finishes being created (e.g., @insert followed by @prop).
   *
   * Arrow function to preserve `this` binding when used as event listener.
   */
  private handleDataChanged = async (): Promise<void> => {
    if (!this.matlabElement || !this.dispatcher) return;

    const data = this.matlabElement.Data;
    if (!Array.isArray(data)) return;

    for (const event of data) {
      try {
        await this.dispatcher(event);
      } catch (error) {
        console.error('[Bridge] Error dispatching event:', error);
      }
    }
  };
}

export default Bridge;
