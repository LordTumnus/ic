/**
 * CesiumJS initialization for MATLAB CEF.
 *
 * CesiumJS's `TaskProcessor` (core/TaskProcessor.js) constructs module
 * workers via `new Worker(url, { type: 'module' })`. Module workers
 * fail in MATLAB's Chromium 104. We fix this by patching
 * `TaskProcessor.prototype.scheduleTask` and `initWebAssemblyModule`
 * to instantiate classic IIFE workers from our registry.
 *
 * The registry (cesium-workers-registry.ts) uses Vite's `?worker`
 * imports, which — combined with `worker: { format: 'iife' }` in
 * vite.config — emit standalone classic JS worker files.
 *
 * Safe to call from multiple components; the init promise is memoised.
 */

import { TaskProcessor } from '@cesium/engine';
import logger from '$lib/core/logger';
import { cesiumWorkerRegistry, type WorkerCtor } from './cesium-workers-registry';

let initPromise: Promise<'ready'> | null = null;

declare global {
  // eslint-disable-next-line no-var
  var CESIUM_BASE_URL: string | undefined;
}

function workerNameFromPath(workerPath: string): string {
  // TaskProcessor accepts a bare module ID like "createGeometry" or a path.
  // Strip any leading directories and trailing ".js".
  const basename = workerPath.split('/').pop() ?? workerPath;
  return basename.replace(/\.js$/, '');
}

function createClassicWorker(workerPath: string): Worker {
  const name = workerNameFromPath(workerPath);
  const Ctor: WorkerCtor | undefined = cesiumWorkerRegistry[name];
  if (!Ctor) {
    throw new Error(
      `[cesium-init] No classic IIFE worker registered for "${name}". ` +
      `Add it to cesium-workers-registry.ts.`,
    );
  }
  return new Ctor();
}

function patchTaskProcessor(): void {
  // Override scheduleTask to create workers from our registry instead of
  // the default module-worker path. The rest of the scheduling logic is
  // replicated by delegating back to the original implementation once
  // this._worker is set.
  const originalScheduleTask = TaskProcessor.prototype.scheduleTask;
  TaskProcessor.prototype.scheduleTask = function (
    this: TaskProcessor,
    parameters: unknown,
    transferableObjects?: unknown[],
  ): Promise<unknown> | undefined {
    if (!this._worker) {
      this._worker = createClassicWorker(this._workerPath);
    }
    return originalScheduleTask.call(this, parameters, transferableObjects);
  };

  // Same treatment for initWebAssemblyModule, which also calls
  // `createWorker` internally.
  const originalInitWasm = TaskProcessor.prototype.initWebAssemblyModule;
  TaskProcessor.prototype.initWebAssemblyModule = function (
    this: TaskProcessor,
    webAssemblyOptions: unknown,
  ): Promise<unknown> {
    if (!this._worker) {
      this._worker = createClassicWorker(this._workerPath);
    }
    return originalInitWasm.call(this, webAssemblyOptions);
  };
}

export function initCesium(): Promise<'ready'> {
  if (initPromise) return initPromise;

  initPromise = (async (): Promise<'ready'> => {
    if (typeof globalThis.CESIUM_BASE_URL === 'undefined') {
      globalThis.CESIUM_BASE_URL = './cesium/';
    }

    patchTaskProcessor();

    // Skip the runtime feature-detection that creates a module worker.
    // Chromium 104 supports ArrayBuffer transfer natively; the check
    // would otherwise hang because the private createWorker() function
    // in TaskProcessor.js builds a module worker which fails silently.
    (TaskProcessor as unknown as { _canTransferArrayBuffer: boolean })._canTransferArrayBuffer = true;

    logger.info('cesium-init', 'initialized', {
      base: globalThis.CESIUM_BASE_URL,
      workers: Object.keys(cesiumWorkerRegistry).length,
    });

    return 'ready';
  })();

  return initPromise;
}

// Type augmentation: TaskProcessor internals we touch.
declare module '@cesium/engine' {
  interface TaskProcessor {
    _worker?: Worker;
    _workerPath: string;
  }
}
