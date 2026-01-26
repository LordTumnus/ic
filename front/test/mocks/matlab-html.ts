/**
 * Mock implementation of MATLAB's HTML communication element.
 *
 * This mock simulates the MatlabHTML interface that MATLAB provides for
 * bidirectional communication. It extends EventTarget to support the
 * DataChanged event pattern used by the Bridge.
 *
 * Usage:
 *   const mock = new MockMatlabHTML();
 *   bridge.setup(mock);
 *   mock.simulateEvent({ component: 'btn1', name: '@prop/label', data: 'Hello', id: '123' });
 */

import type { JsEvent, MatlabHTML } from '$lib/types';

/**
 * Mock MatlabHTML element for testing.
 *
 * Key behaviors:
 * - Setting `Data` triggers a `DataChanged` event (mimics MATLAB behavior)
 * - `lastSentData` captures what the frontend sends back to "MATLAB"
 * - `simulateEvent()` helper to easily inject events from "MATLAB"
 */
export class MockMatlabHTML extends EventTarget implements MatlabHTML {
  private _data: JsEvent[] = [];

  /** Stores the last data sent by the frontend (for assertions) */
  public lastSentData: JsEvent[] = [];

  /** History of all data sent by the frontend */
  public sentHistory: JsEvent[][] = [];

  /**
   * Get the current Data array.
   */
  get Data(): JsEvent[] {
    return this._data;
  }

  /**
   * Set the Data array - triggers DataChanged event.
   *
   * When the frontend (Bridge) sets Data, we capture it in lastSentData.
   * When tests set Data (simulating MATLAB), this triggers the event.
   */
  set Data(value: JsEvent[]) {
    this._data = value;

    // Capture outgoing events (frontend → MATLAB)
    this.lastSentData = value;
    this.sentHistory.push(value);

    // Fire DataChanged event (async to match real behavior)
    queueMicrotask(() => {
      this.dispatchEvent(new Event('DataChanged'));
    });
  }

  /**
   * Simulate an event from MATLAB.
   *
   * Convenience method that sets Data and returns a promise that resolves
   * after the event has been processed by the Bridge.
   *
   * @param events - Single event or array of events to simulate
   */
  async simulateEvent(events: JsEvent | JsEvent[]): Promise<void> {
    const eventArray = Array.isArray(events) ? events : [events];
    this.Data = eventArray;

    // Wait for microtask queue to process the DataChanged event
    await new Promise((resolve) => setTimeout(resolve, 0));
  }

  /**
   * Create a properly formatted JsEvent.
   *
   * @param component - Target component ID
   * @param name - Event name
   * @param data - Event payload
   * @param id - Optional event ID (auto-generated if not provided)
   */
  static createEvent(
    component: string,
    name: string,
    data: unknown,
    id?: string
  ): JsEvent {
    return {
      component,
      name,
      data,
      id: id ?? crypto.randomUUID(),
    };
  }

  /**
   * Reset the mock state.
   */
  reset(): void {
    this._data = [];
    this.lastSentData = [];
    this.sentHistory = [];
  }
}

export default MockMatlabHTML;
