/**
 * ProxiedImageryProvider — CesiumJS ImageryProvider that fetches tiles
 * through the IC framework's BinaryChannel.
 *
 * Flow for each tile:
 *   1. Build tile URL from template ({z}/{x}/{y})
 *   2. requestBinary('tile', { z, x, y, url }) → ArrayBuffer
 *      (MATLAB: webread → writeBinary → returns file path)
 *   3. new Blob([buffer]) → createImageBitmap → ImageBitmap
 *   4. Return to CesiumJS for GPU upload
 *
 * The provider sub-classes UrlTemplateImageryProvider so tile grid math,
 * credits, and the rest of the ImageryProvider contract come for free.
 * Only `requestImage` is overridden.
 *
 * Caching: frontend LRU keyed by "{z}/{x}/{y}". Stores ArrayBuffers
 * (cheap) and re-creates ImageBitmap per cache hit. Inflight requests
 * are deduped so rapid pan/zoom never duplicates the same binary fetch.
 */

import { UrlTemplateImageryProvider, Credit } from '@cesium/engine';
import { TileLRU } from './tile-proxy';
import { tileProviders } from './tile-providers';
import logger from '$lib/core/logger';

export type RequestBinaryFn = (channel: string, data?: unknown) => Promise<ArrayBuffer>;

export interface ProxiedImageryProviderOptions {
  /**
   * Provider preset name (key in tileProviders). Ignored if `url` is given.
   * Examples: 'openstreetmap', 'cartodb-light', 'esri-worldimagery'.
   */
  provider?: string;

  /** Custom URL template with {z}/{x}/{y} placeholders. Overrides `provider`. */
  url?: string;

  /** Function that sends a binary request to MATLAB (from component.requestBinary). */
  requestBinary: RequestBinaryFn;

  /** Override the preset's attribution credit. Defaults to the preset attribution. */
  attribution?: string;

  /** Max tiles to keep in the frontend ArrayBuffer cache. Default 800. */
  cacheSize?: number;

  /** Max zoom level the provider will request. Default 19. */
  maximumLevel?: number;

  /** Optional channel name for the binary request. Default 'tile'. */
  channel?: string;

  /**
   * Callback fired when tile loading begins/ends (aggregate over all
   * in-flight requests). Useful for a loading spinner overlay.
   */
  onLoadingChange?: (loading: boolean) => void;

  /** Max concurrent binary requests to MATLAB. Default 6. */
  maxInFlight?: number;

  /** Max queued requests waiting for a slot. When full, oldest is dropped. Default 12. */
  maxQueued?: number;
}

/**
 * Factory: returns a ready UrlTemplateImageryProvider with requestImage
 * patched to route through the IC BinaryChannel.
 */
export function createProxiedImageryProvider(
  options: ProxiedImageryProviderOptions,
): UrlTemplateImageryProvider {
  // Resolve URL template + attribution.
  let url: string;
  let attribution: string;
  if (options.url) {
    url = options.url;
    attribution = options.attribution ?? '';
  } else if (options.provider && options.provider in tileProviders) {
    const p = tileProviders[options.provider];
    url = p.url;
    attribution = options.attribution ?? p.attribution;
  } else {
    throw new Error(
      `[ProxiedImageryProvider] unknown provider "${options.provider}" and no custom url given`,
    );
  }

  const channel = options.channel ?? 'tile';
  const { requestBinary, onLoadingChange } = options;
  const cache = new TileLRU<ArrayBuffer>(options.cacheSize ?? 800);
  const inflight = new Map<string, Promise<ArrayBuffer>>();

  // Concurrency limit + LIFO queue for the MATLAB binary channel.
  // Prevents rapid camera motion (flyTo, drag, zoom) from flooding
  // MATLAB's single-threaded event loop. When the queue is saturated,
  // requestImage returns `undefined` synchronously so CesiumJS knows to
  // retry on a later frame — NOT to mark the tile as permanently failed.
  const maxInFlight = options.maxInFlight ?? 6;
  const maxQueued = options.maxQueued ?? 12;
  let inFlightCount = 0;
  // LIFO queue: newer requests processed first, matching what the
  // camera view actually needs right now.
  const queue: Array<() => void> = [];

  function isSaturated(): boolean {
    return inFlightCount >= maxInFlight && queue.length >= maxQueued;
  }

  function acquire(): Promise<void> {
    if (inFlightCount < maxInFlight) {
      inFlightCount++;
      return Promise.resolve();
    }
    return new Promise<void>((resolve) => {
      queue.push(() => { inFlightCount++; resolve(); });
    });
  }

  function release(): void {
    inFlightCount--;
    // LIFO: pop the most recently queued request
    const next = queue.pop();
    if (next) next();
  }

  const provider = new UrlTemplateImageryProvider({
    url,
    credit: attribution ? new Credit(attribution) : undefined,
    maximumLevel: options.maximumLevel ?? 19,
  });

  // Override requestImage to fetch via binary channel instead of HTTP.
  // The parent class still handles tile-grid math, credits, and the
  // rest of the ImageryProvider contract.
  provider.requestImage = function (x, y, level) {
    const key = `${level}/${x}/${y}`;

    // Serve from cache if we already have the bytes (no scheduling needed)
    const cached = cache.get(key);
    if (cached) {
      return createImageBitmap(new Blob([cached]), { imageOrientation: 'flipY' });
    }

    // Saturation back-pressure: tell CesiumJS to retry this tile on a
    // later frame. Returning undefined is the contract for "too busy" —
    // CesiumJS re-calls requestImage automatically (vs rejecting, which
    // would be interpreted as a permanent fetch failure).
    // Exception: if this tile is already in-flight, we still attach to
    // its promise rather than asking CesiumJS to retry (no extra work).
    if (!inflight.has(key) && isSaturated()) {
      return undefined;
    }

    const tileUrl = buildTileUrl(url, level, x, y);

    let promise = inflight.get(key);
    if (!promise) {
      promise = (async () => {
        await acquire();
        try {
          return await requestBinary(channel, { z: level, x, y, url: tileUrl });
        } finally {
          release();
        }
      })();
      inflight.set(key, promise);
      if (inflight.size === 1) onLoadingChange?.(true);
    }

    return (async () => {
      try {
        const buffer = await promise!;
        cache.set(key, buffer);
        // Browser sniffs image format (PNG/JPEG/WebP) from binary content.
        // imageOrientation: 'flipY' gives a GL-ready bitmap (bottom-left
        // origin); without it every tile renders upside-down because
        // CesiumJS uploads tiles to WebGL textures expecting Y-up.
        return createImageBitmap(new Blob([buffer]), { imageOrientation: 'flipY' });
      } catch (err) {
        logger.warn('cesium-imagery-provider', `tile fetch failed ${key}: ${err}`);
        throw err;
      } finally {
        inflight.delete(key);
        if (inflight.size === 0) onLoadingChange?.(false);
      }
    })();
  };

  return provider;
}

function buildTileUrl(template: string, z: number, x: number, y: number): string {
  return template
    .replace('{z}', String(z))
    .replace('{x}', String(x))
    .replace('{y}', String(y));
}
