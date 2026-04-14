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

  const provider = new UrlTemplateImageryProvider({
    url,
    credit: attribution ? new Credit(attribution) : undefined,
    maximumLevel: options.maximumLevel ?? 19,
  });

  // Override requestImage to fetch via binary channel instead of HTTP.
  // The parent class still handles tile-grid math, credits, and the
  // rest of the ImageryProvider contract.
  provider.requestImage = async function (x, y, level) {
    const key = `${level}/${x}/${y}`;
    const tileUrl = buildTileUrl(url, level, x, y);

    let buffer = cache.get(key);
    if (!buffer) {
      // Dedup in-flight requests for the same tile
      let promise = inflight.get(key);
      if (!promise) {
        promise = requestBinary(channel, { z: level, x, y, url: tileUrl });
        inflight.set(key, promise);
        if (inflight.size === 1) onLoadingChange?.(true);
      }
      try {
        buffer = await promise;
        cache.set(key, buffer);
      } catch (err) {
        logger.warn('cesium-imagery-provider', `tile fetch failed ${key}: ${err}`);
        throw err;
      } finally {
        inflight.delete(key);
        if (inflight.size === 0) onLoadingChange?.(false);
      }
    }

    // Browser sniffs image format (PNG/JPEG/WebP) from binary content.
    const blob = new Blob([buffer]);
    return createImageBitmap(blob);
  };

  return provider;
}

function buildTileUrl(template: string, z: number, x: number, y: number): string {
  return template
    .replace('{z}', String(z))
    .replace('{x}', String(x))
    .replace('{y}', String(y));
}
