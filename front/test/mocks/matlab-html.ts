/**
 * Mock of MATLAB's uihtml htmlComponent for testing.
 *
 * Simulates the event-based API:
 * - simulateEvent() dispatches "ic" events (one per JsEvent, like sendEventToHTMLSource)
 * - sendEventToMATLAB() captures outgoing events for assertions
 */

import type { JsEvent, MatlabHTML } from '$lib/types';

export class MockMatlabHTML extends EventTarget implements MatlabHTML {
  public lastSentData: unknown = null;
  public sentHistory: { eventName: string; eventData: unknown }[] = [];

  sendEventToMATLAB(eventName: string, eventData?: unknown): void {
    this.lastSentData = eventData;
    this.sentHistory.push({ eventName, eventData });
  }

  /**
   * Simulate MATLAB sending events via sendEventToHTMLSource.
   * Dispatches one "ic" event per JsEvent (matching real behavior).
   */
  async simulateEvent(events: JsEvent | JsEvent[]): Promise<void> {
    const eventArray = Array.isArray(events) ? events : [events];
    for (const item of eventArray) {
      const evt = new Event('ic') as any;
      evt.Data = item;
      queueMicrotask(() => this.dispatchEvent(evt));
    }
    await new Promise((resolve) => setTimeout(resolve, 0));
  }

  static createEvent(
    component: string,
    name: string,
    data: unknown,
    id?: string,
  ): JsEvent {
    return {
      component,
      name,
      data,
      id: id ?? crypto.randomUUID(),
    };
  }

  reset(): void {
    this.lastSentData = null;
    this.sentHistory = [];
  }
}

export default MockMatlabHTML;
