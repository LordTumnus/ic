/**
 * PDF.js worker entry point for Vite.
 *
 * Vite bundles this as a separate IIFE file (worker.format: 'iife' in vite.config).
 * The `?worker` import gives a constructor that creates a classic Worker
 * loading the built file from a relative path — compatible with MATLAB's
 * CEF (Chromium 104) which supports file:// classic workers.
 *
 * Usage:
 *   import PdfWorker from '$lib/workers/pdf.worker?worker';
 *   GlobalWorkerOptions.workerPort = new PdfWorker();
 */

// Polyfill Promise.withResolvers for Chromium 104 (added in Chrome 119).
// Must run BEFORE pdf.js worker code, which uses this API.
// Workers have their own global scope — main-thread polyfills don't apply here.
import '$lib/utils/polyfills';

// Importing the pdf.js worker module causes it to self-register its
// message handlers on the worker's global scope.
import 'pdfjs-dist/build/pdf.worker.min.mjs';
