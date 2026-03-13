/**
 * Bridge — Bidirectional MATLAB ↔ JS communication via dedicated event channels.
 *
 * MATLAB → JS:  sendEventToHTMLSource(h, "ic", event)  →  addEventListener("ic")
 * JS → MATLAB:  sendEventToMATLAB("ic", events)        →  HTMLEventReceivedFcn
 *
 * Singleton. Access via `Bridge.instance`.
 */

import type { JsEvent, MatlabHTML } from '../types';
import logger from './logger';

type Dispatcher = (event: JsEvent) => Promise<void>;

class Bridge {
  private static _instance: Bridge | null = null;

  private matlabElement: MatlabHTML | null = null;
  private dispatcher: Dispatcher | null = null;
  private queue: JsEvent[] = [];
  private processing = false;

  private constructor() {}

  static get instance(): Bridge {
    if (!Bridge._instance) {
      Bridge._instance = new Bridge();
    }
    return Bridge._instance;
  }

  setup(element: MatlabHTML): void {
    if (this.matlabElement) {
      throw new Error('Bridge.setup() called more than once.');
    }
    this.matlabElement = element;
    this.matlabElement.addEventListener('ic', this.onEvent);
    this.matlabElement.sendEventToMATLAB('ic-ready');
  }

  setDispatcher(dispatcher: Dispatcher): void {
    this.dispatcher = dispatcher;
  }

  send(events: JsEvent[]): void {
    if (!this.matlabElement) {
      throw new Error('Bridge.send() called before setup().');
    }
    this.matlabElement.sendEventToMATLAB('ic', events);
  }

  get isReady(): boolean {
    return this.matlabElement !== null;
  }

  /** @internal */
  _reset(): void {
    if (this.matlabElement) {
      this.matlabElement.removeEventListener('ic', this.onEvent);
    }
    this.matlabElement = null;
    this.dispatcher = null;
    this.queue = [];
    this.processing = false;
  }

  /**
   * Receives individual events from MATLAB and queues them.
   * Kicks off sequential processing if not already running.
   */
  private onEvent = (event: Event): void => {
    const raw = (event as any).Data;
    if (raw == null) return;
    const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    this.queue.push(data);
    if (!this.processing) this.processQueue();
  };

  /**
   * Drains the queue sequentially. Awaiting each dispatch guarantees
   * that @insert completes (dynamic import) before subsequent @prop
   * events targeting the newly created component.
   */
  private processQueue = async (): Promise<void> => {
    if (!this.dispatcher) return;

    this.processing = true;
    while (this.queue.length > 0) {
      const item = this.queue.shift()!;
      try {
        await this.dispatcher(item);
      } catch (error) {
        logger.error('Bridge', 'dispatch failed', {
          error: error instanceof Error ? error.message : String(error),
          eventName: item.name,
          componentId: item.component,
        });
      }
    }
    this.processing = false;
  };
}

export default Bridge;
