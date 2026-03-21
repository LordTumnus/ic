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
    this.queue = [];
    this.processing = false;
  }

  /**
   * Receives events from MATLAB (single or batched array) and queues them.
   * Kicks off sequential processing if not already running.
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
    if (!this.processing) this.processQueue();
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

  private async dispatchSafe(event: JsEvent): Promise<void> {
    try {
      await this.dispatcher!(event);
    } catch (error) {
      logger.error('Bridge', 'dispatch failed', {
        error: error instanceof Error ? error.message : String(error),
        eventName: event.name,
        componentId: event.component,
      });
    }
  }

  /**
   * Drains the queue in two phases:
   * 1. Async — process events normally while pre-loading component modules.
   * 2. Sync  — once modules are cached, dispatch remaining events without
   *    microtask yields and flush the DOM once at the end.
   */
  private processQueue = async (): Promise<void> => {
    if (!this.dispatcher) return;

    this.processing = true;

    const events = [...this.queue];
    this.queue = [];

    // Pre-load all component modules needed by @insert events
    const types = this.collectTypes(events);
    const preloadDone = types.size > 0
      ? Factory.instance.preload(types)
      : Promise.resolve();

    let preloaded = false;
    preloadDone.then(() => { preloaded = true; });

    // Phase 1: async — renders frame, loads first modules
    let i = 0;
    while (i < events.length && !preloaded) {
      await this.dispatchSafe(events[i]);
      i++;
    }

    await preloadDone;

    // Phase 2: sync — no yields, single DOM flush at the end
    if (i < events.length) {
      setBatchMode(true);
      for (; i < events.length; i++) {
        this.dispatchSafe(events[i]);
      }
      setBatchMode(false);
      flushSync();
    }

    this.processing = false;
  };
}

export default Bridge;
