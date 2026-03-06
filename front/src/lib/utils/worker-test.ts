/**
 * Worker capability tester for MATLAB's CEF (Chromium 104).
 *
 * Tests which Web Worker creation methods work in the current environment.
 * Results are returned as a structured report.
 */

export interface WorkerTestResult {
  method: string;
  success: boolean;
  error?: string;
  durationMs: number;
}

export interface WorkerTestReport {
  userAgent: string;
  protocol: string;
  location: string;
  results: WorkerTestResult[];
}

const TIMEOUT_MS = 3000;

/** Test a single Worker creation method. */
async function testMethod(
  name: string,
  factory: () => Worker,
): Promise<WorkerTestResult> {
  const start = performance.now();
  try {
    const worker = factory();

    const result = await new Promise<WorkerTestResult>((resolve) => {
      const timer = setTimeout(() => {
        worker.terminate();
        resolve({
          method: name,
          success: false,
          error: `Timeout (${TIMEOUT_MS}ms) — worker created but no response`,
          durationMs: performance.now() - start,
        });
      }, TIMEOUT_MS);

      worker.onmessage = () => {
        clearTimeout(timer);
        worker.terminate();
        resolve({
          method: name,
          success: true,
          durationMs: performance.now() - start,
        });
      };

      worker.onerror = (e) => {
        clearTimeout(timer);
        worker.terminate();
        resolve({
          method: name,
          success: false,
          error: `Worker error: ${e.message || 'unknown'}`,
          durationMs: performance.now() - start,
        });
      };
    });

    return result;
  } catch (err) {
    return {
      method: name,
      success: false,
      error: `Construction failed: ${err instanceof Error ? err.message : String(err)}`,
      durationMs: performance.now() - start,
    };
  }
}

/** Run all Worker creation method tests. */
export async function runWorkerTests(): Promise<WorkerTestReport> {
  const results: WorkerTestResult[] = [];

  // 1. Classic worker from blob URL
  results.push(
    await testMethod('classic-blob', () => {
      const blob = new Blob(["postMessage({ok:true})"], { type: 'text/javascript' });
      return new Worker(URL.createObjectURL(blob));
    }),
  );

  // 2. Module worker from blob URL (known failure baseline)
  results.push(
    await testMethod('module-blob', () => {
      const blob = new Blob(["postMessage({ok:true})"], { type: 'text/javascript' });
      return new Worker(URL.createObjectURL(blob), { type: 'module' });
    }),
  );

  // 3. Classic worker from data URL
  results.push(
    await testMethod('classic-data', () => {
      return new Worker(`data:text/javascript,${encodeURIComponent("postMessage({ok:true})")}`);
    }),
  );

  // 4. Module worker from data URL
  results.push(
    await testMethod('module-data', () => {
      return new Worker(
        `data:text/javascript,${encodeURIComponent("postMessage({ok:true})")}`,
        { type: 'module' },
      );
    }),
  );

  // 5. Classic worker from relative file path (same pattern as SwiftLaTeX)
  results.push(
    await testMethod('classic-file-rel', () => {
      return new Worker('./workers/test-worker.js');
    }),
  );

  // 6. Classic worker from absolute file:// path
  results.push(
    await testMethod('classic-file-abs', () => {
      const base = window.location.href.replace(/\/[^/]*$/, '');
      return new Worker(`${base}/workers/test-worker.js`);
    }),
  );

  // 7. Module worker from relative file path
  results.push(
    await testMethod('module-file-rel', () => {
      return new Worker('./workers/test-worker-module.mjs', { type: 'module' });
    }),
  );

  // 8. Module worker from absolute file:// path
  results.push(
    await testMethod('module-file-abs', () => {
      const base = window.location.href.replace(/\/[^/]*$/, '');
      return new Worker(`${base}/workers/test-worker-module.mjs`, { type: 'module' });
    }),
  );

  return {
    userAgent: navigator.userAgent,
    protocol: window.location.protocol,
    location: window.location.href,
    results,
  };
}
