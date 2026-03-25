/**
 * Bridge — Bidirectional MATLAB ↔ JS communication via dedicated event channels.
 *
 * MATLAB → JS:  sendEventToHTMLSource(h, "ic", event)  →  addEventListener("ic")
 * JS → MATLAB:  sendEventToMATLAB("ic", events)        →  HTMLEventReceivedFcn
 *
 * Singleton. Access via `Bridge.instance`.
 */

import { flushSync } from 'svelte';
import type { JsEvent, MatlabHTML } from '../types';
import { setBatchMode } from './container';
import Factory from './factory';
import logger from './logger';


type Dispatcher = (event: JsEvent) => Promise<void>;
type SyncDispatcher = (event: JsEvent) => void;

class Bridge {
  private static _instance: Bridge | null = null;

  private matlabElement: MatlabHTML | null = null;
  private dispatcher: Dispatcher | null = null;
  private syncDispatcher: SyncDispatcher | null = null;
  private queue: JsEvent[] = [];
  private processing = false;
  private drainScheduled = false;

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
  }

  setDispatcher(dispatcher: Dispatcher, syncDispatcher: SyncDispatcher): void {
    this.dispatcher = dispatcher;
    this.syncDispatcher = syncDispatcher;
    // Drain any events that arrived before the dispatcher was wired
    if (this.queue.length > 0 && !this.processing && !this.drainScheduled) {
      this.drainScheduled = true;
      setTimeout(() => {
        this.drainScheduled = false;
        if (!this.processing && this.queue.length > 0) {
          this.processQueue();
        }
      }, 0);
    }
  }

  send(events: JsEvent[]): void {
    if (!this.matlabElement) {
      throw new Error('Bridge.send() called before setup().');
    }
    this.matlabElement.sendEventToMATLAB('ic', JSON.stringify(events));
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
    this.syncDispatcher = null;
    this.queue = [];
    this.processing = false;
    this.drainScheduled = false;
  }

  /**
   * Receives events from MATLAB (single or batched array) and queues them.
   *
   * Instead of calling processQueue() immediately, we schedule it via
   * setTimeout(0).  This lets ALL events from the same MATLAB function
   * call accumulate in the queue before processing starts — each
   * sendEventToHTMLSource() posts a separate macrotask, but setTimeout(0)
   * fires after all pending macrotasks.  One batch = one preload = one
   * synchronous dispatch = one flushSync.
   */
  private onEvent = (event: Event): void => {
    const raw = (event as any).Data;
    if (raw == null) return;
    const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (Array.isArray(data)) {
      for (const item of data) this.queue.push(item);
    } else {
      this.queue.push(data);
    }
    if (!this.processing && !this.drainScheduled) {
      this.drainScheduled = true;
      setTimeout(() => {
        this.drainScheduled = false;
        if (!this.processing && this.queue.length > 0) {
          this.processQueue();
        }
      }, 0);
    }
  };

  /**
   * Collects all unique component types from @insert events (including
   * nested static children) so they can be pre-loaded before processing.
   */
  private collectTypes(events: JsEvent[]): Set<string> {
    const types = new Set<string>();
    const walk = (data: any) => {
      if (!data?.component?.type) return;
      types.add(data.component.type);
      if (data.component.staticChildren) {
        for (const sc of data.component.staticChildren) walk(sc);
      }
    };
    for (const e of events) {
      if (e.name === '@insert') walk(e.data);
    }
    return types;
  }

  private dispatchSafeSync(event: JsEvent): void {
    try {
      this.syncDispatcher!(event);
    } catch (error) {
      logger.error('Bridge', 'dispatch failed', {
        error: error instanceof Error ? error.message : String(error),
        eventName: event.name,
        componentId: event.component,
      });
    }
  }

  /**
   * Drains the queue: preload all component modules first, then dispatch
   * every event **synchronously** in a single run and flush the DOM once.
   *
   * Synchronous dispatch is critical — any `await` yields a microtask tick
   * during which Svelte's reactive scheduler applies pending $state changes,
   * causing intermediate renders.  Containers like Splitter that build up
   * their targets and children across several events would be rendered in
   * incomplete states, breaking components that need a fully-formed DOM on
   * mount (e.g. CodeMirror inside CodeEditor).
   */
  private processQueue = async (): Promise<void> => {
    if (!this.dispatcher) return;

    this.processing = true;

    try {
      const events = [...this.queue];
      this.queue = [];

      logger.debug('Bridge', `processQueue: ${events.length} events`);

      // Pre-load ALL component modules before dispatching any events.
      // After this, Factory.createSync() succeeds for every type, so
      // handlers run fully synchronously with no microtask yields.
      const types = this.collectTypes(events);
      if (types.size > 0) {
        await Factory.instance.preload(types);
      }

      // Dispatch all events synchronously — no await, no microtask gaps,
      // no intermediate Svelte renders.  Uses the sync dispatch path
      // (receiveSync) which invokes callbacks without awaiting them.
      setBatchMode(true);
      for (const event of events) {
        this.dispatchSafeSync(event);
      }
      setBatchMode(false);
      flushSync();

      logger.debug('Bridge', `processQueue done. Remaining in queue: ${this.queue.length}`);
    } catch (error) {
      logger.error('Bridge', 'processQueue failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      setBatchMode(false);
    } finally {
      this.processing = false;
    }

    // Events may have arrived during the async preload; drain them.
    if (this.queue.length > 0 && !this.drainScheduled) {
      this.drainScheduled = true;
      setTimeout(() => {
        this.drainScheduled = false;
        if (!this.processing && this.queue.length > 0) {
          this.processQueue();
        }
      }, 0);
    }
  };
}

export default Bridge;
