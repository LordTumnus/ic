/**
 * ProxiedResource — CesiumJS Resource that fetches through the IC
 * BinaryChannel instead of HTTP.
 *
 * CesiumJS uses `Resource` as its abstraction for any URL fetch
 * (terrain layer.json + per-tile .terrain bytes, 3D Tiles tileset.json
 * + .b3dm/.i3dm/.pnts content, etc.). Sub-resources are created by
 * `Resource.getDerivedResource()` when Cesium walks an asset hierarchy.
 *
 * To proxy ALL fetches — including derived ones — we subclass Resource
 * and override:
 *   - `_makeRequest()`: the lowest-level fetch hook (used by everything)
 *   - `clone()`: ensures derived Resources stay subclassed
 *
 * Each ProxiedResource carries (channel, queue) state so all derived
 * Resources share the same dedup + LRU + concurrency limit.
 *
 * Used by:
 *   - GlobeTerrain.svelte → CesiumTerrainProvider.fromUrl(proxiedResource)
 *   - GlobeTileset3D.svelte → Cesium3DTileset.fromUrl(proxiedResource)
 */

import { Resource } from '@cesium/engine';
import { TileLRU } from './tile-proxy';
import logger from '$lib/core/logger';

export type RequestBinaryFn = (channel: string, data?: unknown) => Promise<ArrayBuffer>;

export interface BinaryFetchQueueOptions {
  channel: string;
  requestBinary: RequestBinaryFn;
  cacheSize?: number;     // Max ArrayBuffers cached in-memory. Default 200.
  maxInFlight?: number;   // Max concurrent MATLAB requests. Default 6.
  maxQueued?: number;     // Max waiting requests before the queue saturates. Default 24.
  onLoadingChange?: (loading: boolean) => void;
}

/**
 * Per-instance fetch queue with LRU caching, in-flight dedup, and
 * concurrency limiting. Mirrors the proven pattern from
 * `cesium-imagery-provider.ts` so terrain/tileset3d behave consistently
 * under sustained camera motion.
 */
export interface BinaryFetchQueue {
  fetch(url: string): Promise<ArrayBuffer>;
}

export function createBinaryFetchQueue(opts: BinaryFetchQueueOptions): BinaryFetchQueue {
  const {
    channel,
    requestBinary,
    // Small LRU: Cesium already caches decoded geometry/textures in its
    // own tile cache. This one only helps on hard refreshes / eviction.
    // 50 entries × ~200 KB avg = ~10 MB ceiling.
    cacheSize = 50,
    // MATLAB webread is serial (single-threaded event loop), so extra
    // frontend concurrency just lengthens the queue without adding
    // throughput. 4 is enough to keep MATLAB saturated while leaving
    // event-loop headroom for property syncs.
    maxInFlight = 4,
    // Queue deep enough that transient bursts during camera motion
    // don't get rejected (rejected tiles cost Cesium a retry frame),
    // but bounded so pathological inputs can't unbounded-grow.
    maxQueued = 128,
    onLoadingChange,
  } = opts;

  const cache = new TileLRU<ArrayBuffer>(cacheSize);
  const inflight = new Map<string, Promise<ArrayBuffer>>();

  /**
   * Transparently inflate gzip-compressed responses. Cesium Ion/S3
   * serves many .terrain and layer.json assets with Content-Encoding:
   * gzip, which browsers normally handle invisibly. But we fetch
   * through MATLAB's webread, which returns the compressed bytes as-is.
   * DecompressionStream ('gzip') is a native Chromium 104+ API — no
   * wasm, no npm dep — that inflates an ArrayBuffer.
   *
   * Sniffs the 0x1f 0x8b magic header so uncompressed payloads pass
   * through unchanged. Inflated bytes are what we cache, so cache hits
   * skip decompression entirely.
   */
  async function maybeGunzip(buf: ArrayBuffer): Promise<ArrayBuffer> {
    if (buf.byteLength < 2) return buf;
    const view = new Uint8Array(buf, 0, 2);
    if (view[0] !== 0x1f || view[1] !== 0x8b) return buf;

    const ds = new DecompressionStream('gzip');
    const stream = new Response(buf).body;
    if (!stream) return buf;
    return new Response(stream.pipeThrough(ds)).arrayBuffer();
  }
  let inFlightCount = 0;
  interface Waiter {
    run: () => void;
    reject: (err: Error) => void;
  }
  const waiterList: Waiter[] = [];

  function acquire(): Promise<void> {
    if (inFlightCount < maxInFlight) {
      inFlightCount++;
      return Promise.resolve();
    }
    return new Promise<void>((resolve, reject) => {
      waiterList.push({
        run: () => { inFlightCount++; resolve(); },
        reject: (err) => reject(err),
      });
      // When saturated, reject the OLDEST waiter with a retryable error
      // so Cesium re-requests that tile on a later frame (instead of
      // silently waiting forever, which would leave tiles permanently
      // missing and render as their coarser ancestor).
      if (waiterList.length > maxQueued) {
        const dropped = waiterList.shift();
        dropped?.reject(new Error('binary-fetch-queue: saturated, retry'));
      }
    });
  }

  function release(): void {
    inFlightCount--;
    // LIFO: newest waiter runs first (matches current camera view).
    const next = waiterList.pop();
    if (next) next.run();
  }

  return {
    fetch(url: string): Promise<ArrayBuffer> {
      // Cesium transfers tile ArrayBuffers to decoder workers (which
      // detaches the source buffer), so anything we cache MUST NOT be
      // the same object we hand back. Always return a slice clone.
      const cached = cache.get(url);
      if (cached) return Promise.resolve(cached.slice(0));

      const existing = inflight.get(url);
      if (existing) return existing.then((b) => b.slice(0));

      const promise = (async () => {
        await acquire();
        try {
          const raw = await requestBinary(channel, { url });
          const buf = await maybeGunzip(raw);
          cache.set(url, buf);
          return buf.slice(0);
        } finally {
          release();
        }
      })();

      inflight.set(url, promise);
      if (inflight.size === 1) onLoadingChange?.(true);

      return promise.finally(() => {
        inflight.delete(url);
        if (inflight.size === 0) onLoadingChange?.(false);
      });
    },
  };
}

/**
 * Subclass that overrides Cesium's request pipeline. The shared queue
 * lives on `__icQueue` so derived clones inherit it.
 */
class ProxiedResource extends Resource {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  private __icQueue: BinaryFetchQueue;

  constructor(options: ConstructorParameters<typeof Resource>[0], queue: BinaryFetchQueue) {
    super(options);
    this.__icQueue = queue;
  }

  /**
   * Cesium's lowest-level fetch hook. Every higher-level helper
   * (fetchArrayBuffer, fetchJson, fetchText, fetchBlob, fetchImage)
   * funnels through here. Returning a Promise<ArrayBuffer | string |
   * object | Blob> based on responseType keeps CesiumJS's contract.
   *
   * Cesium calls _makeRequest internally; the public-facing fetchX
   * helpers wrap it. Overriding here catches everything.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  _makeRequest(options: { responseType?: string } = {}): Promise<any> | undefined {
    const responseType = options.responseType ?? 'arraybuffer';
    const url = this.url;

    return this.__icQueue.fetch(url).then((buf) => {
      switch (responseType) {
        case 'json': {
          const text = new TextDecoder().decode(new Uint8Array(buf));
          try {
            return JSON.parse(text);
          } catch (err) {
            logger.warn('cesium-resource-proxy', `JSON parse failed for ${url}: ${err}`);
            throw err;
          }
        }
        case 'text':
          return new TextDecoder().decode(new Uint8Array(buf));
        case 'blob':
          return new Blob([buf]);
        case 'arraybuffer':
        default:
          return buf;
      }
    });
  }

  /**
   * Cesium calls clone() internally during getDerivedResource(), retry
   * machinery, and a few other paths. The default implementation returns
   * a plain Resource — losing our proxy. Re-instantiate ProxiedResource
   * with the same queue, then let super.clone() copy the rest of the
   * fields (headers, query params, etc.).
   */
  clone(result?: ProxiedResource): ProxiedResource {
    if (!result) {
      result = new ProxiedResource({ url: this.url }, this.__icQueue);
    }
    super.clone(result);
    // super.clone may have overwritten our queue if `result` was passed
    // by Cesium itself (e.g., already-typed ProxiedResource). Re-anchor.
    result.__icQueue = this.__icQueue;
    return result;
  }
}

export interface ProxiedResourceOptions extends BinaryFetchQueueOptions {
  url: string;
}

/**
 * Factory: returns a Resource configured to fetch through the IC binary
 * channel. All sub-resources derived from it (via getDerivedResource,
 * cloning, etc.) inherit the proxied behavior automatically.
 */
export function createProxiedResource(options: ProxiedResourceOptions): Resource {
  const queue = createBinaryFetchQueue(options);
  return new ProxiedResource({ url: options.url }, queue);
}
