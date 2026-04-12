/**
 * ProxiedWmsLayer — custom Leaflet WMS TileLayer that fetches tiles through
 * the IC framework's request() mechanism (MATLAB webread proxy).
 *
 * Reuses the same getTile request handler as ProxiedTileLayer. Leaflet's
 * L.TileLayer.WMS builds the full GetMap URL internally; we intercept it
 * in createTile and route through MATLAB.
 */
import L from 'leaflet';
import type { RequestFn } from '$lib/types';
import { TileLRU } from '$lib/utils/tile-proxy';
import logger from '$lib/core/logger';

interface WmsTileResponse {
  data: string; // base64-encoded image bytes
  mime: string;
}

export interface ProxiedWmsOptions extends L.WMSOptions {
  requestFn: RequestFn;
  /** MIME type to pass to MATLAB (avoids extension-based detection for query-string URLs) */
  mimeHint?: string;
}

export class ProxiedWmsLayer extends L.TileLayer.WMS {
  private requestFn: RequestFn;
  private mimeHint: string;
  private tileCache = new TileLRU(500);
  private inflight = new Set<string>();
  private viewportInflight = new Set<string>();
  /** Cache-buster token appended to tile URLs after refresh() */
  private cacheBuster = '';
  /** Callback for viewport loading state (drives spinner) */
  public onLoadingChange?: (loading: boolean) => void;
  /** Callback for total loading state (drives FetchEnd) */
  public onAllLoadingChange?: (loading: boolean) => void;

  constructor(baseUrl: string, options: ProxiedWmsOptions) {
    const { requestFn, mimeHint, ...wmsOpts } = options;
    super(baseUrl, wmsOpts);
    this.requestFn = requestFn;
    this.mimeHint = mimeHint || 'image/png';
  }

  createTile(coords: L.Coords, done: L.DoneCallback): HTMLElement {
    const key = `wms/${coords.z}/${coords.x}/${coords.y}`;
    const img = document.createElement('img');
    img.alt = '';
    img.setAttribute('role', 'presentation');

    // Serve from cache immediately
    const cached = this.tileCache.get(key);
    if (cached) {
      img.src = cached;
      setTimeout(() => done(undefined, img), 0);
      return img;
    }

    // Build the full WMS GetMap URL (Leaflet handles bbox, srs, layers, etc.)
    let tileUrl = this.getTileUrl(coords);
    if (this.cacheBuster) {
      tileUrl += `&_t=${this.cacheBuster}`;
    }

    this.fetchTile(key, tileUrl, true).then((dataUri) => {
      if (dataUri) {
        img.src = dataUri;
        done(undefined, img);
      } else {
        done(new Error('WMS tile fetch failed'), img);
      }
    });

    return img;
  }

  private async fetchTile(key: string, tileUrl: string, viewport = false): Promise<string | null> {
    const cached = this.tileCache.get(key);
    if (cached) return cached;

    if (this.inflight.has(key)) {
      return new Promise((resolve) => {
        const check = setInterval(() => {
          const val = this.tileCache.get(key);
          if (val || !this.inflight.has(key)) {
            clearInterval(check);
            resolve(val ?? null);
          }
        }, 50);
      });
    }

    this.inflight.add(key);
    if (this.inflight.size === 1) this.onAllLoadingChange?.(true);
    if (viewport) {
      this.viewportInflight.add(key);
      if (this.viewportInflight.size === 1) this.onLoadingChange?.(true);
    }

    try {
      const [z, x, y] = key.replace('wms/', '').split('/').map(Number);
      const res = await this.requestFn('getTile', {
        z, x, y,
        url: tileUrl,
        mime: this.mimeHint,
      });

      if (res.success) {
        const tileData = res.data as WmsTileResponse;
        if (tileData.data && tileData.mime) {
          const dataUri = `data:${tileData.mime};base64,${tileData.data}`;
          this.tileCache.set(key, dataUri);
          return dataUri;
        }
        logger.warn('wms-proxy', `missing data/mime for ${key}`);
        return null;
      } else {
        logger.warn('wms-proxy', `error for ${key}: ${String(res.data)}`);
        return null;
      }
    } catch (err) {
      logger.warn('wms-proxy', `catch for ${key}: ${err}`);
      return null;
    } finally {
      this.inflight.delete(key);
      this.viewportInflight.delete(key);
      if (this.viewportInflight.size === 0) this.onLoadingChange?.(false);
      if (this.inflight.size === 0) this.onAllLoadingChange?.(false);
    }
  }

  /** Clear caches and force re-fetch from the WMS server.
   *  A cache-buster param ensures MATLAB's TileCache also misses. */
  clearCache(): void {
    this.tileCache.clear();
    this.cacheBuster = String(Date.now());
    this.redraw();
  }
}
