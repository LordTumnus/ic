/**
 * Polyfills for APIs missing in Chromium 104 (MATLAB's embedded browser).
 *
 * Promise.withResolvers() — Chrome 119+, needed by pdfjs-dist v4+.
 * Import this module BEFORE any library that depends on these APIs.
 */

if (typeof Promise.withResolvers === 'undefined') {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (Promise as any).withResolvers = function <T>() {
    let resolve!: (value: T | PromiseLike<T>) => void;
    let reject!: (reason?: unknown) => void;
    const promise = new Promise<T>((res, rej) => {
      resolve = res;
      reject = rej;
    });
    return { promise, resolve, reject };
  };
}
