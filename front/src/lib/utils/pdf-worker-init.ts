/**
 * PDF.js worker initialization for MATLAB CEF.
 *
 * Tries to create a real Worker (background thread) for pdf.js parsing.
 * Falls back to main-thread parsing if Workers are unavailable.
 *
 * Singleton — safe to call from multiple components (PDFViewer, Latex).
 */

import { GlobalWorkerOptions } from 'pdfjs-dist';
import logger from '$lib/core/logger';
// @ts-ignore — Vite ?worker import returns a Worker constructor
import PdfWorkerCtor from '$lib/workers/pdf.worker?worker';

let initPromise: Promise<'worker' | 'main-thread'> | null = null;

/**
 * Initialize the pdf.js worker. Call before any `getDocument()`.
 *
 * On first call, attempts to create a real Worker from the Vite-built
 * IIFE file (same pattern as SwiftLaTeX). If that fails, falls back to
 * main-thread parsing via globalThis.pdfjsWorker.
 *
 * Subsequent calls return the cached result immediately.
 */
export function initPdfWorker(): Promise<'worker' | 'main-thread'> {
  if (initPromise) return initPromise;

  initPromise = (async (): Promise<'worker' | 'main-thread'> => {
    try {
      const worker: Worker = new PdfWorkerCtor();

      // Verify the worker is alive with a timeout.
      // pdf.js worker sends a "ready" message after self-initialization.
      // We just check for any message as proof-of-life.
      await Promise.race([
        new Promise<void>((resolve) => {
          worker.onmessage = () => resolve();
        }),
        new Promise<void>((_, reject) =>
          setTimeout(() => reject(new Error('Worker init timeout (3s)')), 3000),
        ),
      ]);

      // Worker is alive — hand it to pdf.js.
      // Clear our diagnostic handler; pdf.js uses addEventListener internally.
      worker.onmessage = null;
      GlobalWorkerOptions.workerPort = worker;
      logger.info('pdf-worker', 'Real Worker initialized (background thread)');
      return 'worker';
    } catch (err) {
      logger.warn(
        'pdf-worker',
        'Worker creation failed, falling back to main-thread parsing',
        { error: err instanceof Error ? err.message : String(err) },
      );

      // Fallback: import worker module on main thread (current approach)
      // @ts-ignore — no type declarations for the worker bundle
      const pdfjsWorker = await import('pdfjs-dist/build/pdf.worker.min.mjs');
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (globalThis as any).pdfjsWorker = pdfjsWorker;
      return 'main-thread';
    }
  })();

  return initPromise;
}
