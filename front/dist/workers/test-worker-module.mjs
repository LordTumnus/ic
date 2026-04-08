// ES module test worker — posts message immediately on load.
// Uses .mjs extension to be explicit about module format.
postMessage({ ok: true, method: 'file-module', timestamp: Date.now() });

self.onmessage = function (e) {
  postMessage({ echo: e.data, ok: true });
};
