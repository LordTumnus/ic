// Classic (IIFE) test worker — posts message immediately on load.
// Must NOT use import/export syntax (classic worker).
postMessage({ ok: true, method: 'file-classic', timestamp: Date.now() });

self.onmessage = function (e) {
  postMessage({ echo: e.data, ok: true });
};
