/**
 * ProxiedTileLayer — custom Leaflet TileLayer that fetches tiles through
 * the IC framework's request() mechanism (MATLAB webread proxy).
 *
 * Features:
 * - Tiles fetched via request('getTile', {z,x,y,url}) → MATLAB webread
 * - Frontend LRU cache (max 500 tiles)
 * - Debounced batch prefetch of neighboring tiles
 * - CSS loading animation on pending tiles
 */
import L from 'leaflet';
import type { RequestFn } from '$lib/types';
import logger from '$lib/core/logger';

interface TileRequestData {
  z: number;
  x: number;
  y: number;
  url: string;
}

interface TileResponse {
  data: string; // base64-encoded image bytes
  mime: string; // e.g. "image/png"
}

export interface ProxiedTileLayerOptions extends L.TileLayerOptions {
  /** The resolved URL template with {s}/{z}/{x}/{y} placeholders */
  urlTemplate: string;
  /** IC framework request function (from parent Map context) */
  requestFn: RequestFn;
}

/** Simple LRU cache: Map insertion order + size cap */
class TileLRU {
  private map = new Map<string, string>();
  private maxSize: number;

  constructor(maxSize: number) {
    this.maxSize = maxSize;
  }

  get(key: string): string | undefined {
    const val = this.map.get(key);
    if (val !== undefined) {
      // Move to end (most recently used)
      this.map.delete(key);
      this.map.set(key, val);
    }
    return val;
  }

  set(key: string, value: string): void {
    if (this.map.has(key)) {
      this.map.delete(key);
    }
    this.map.set(key, value);
    // Evict oldest entries if over capacity
    while (this.map.size > this.maxSize) {
      const oldest = this.map.keys().next().value;
      if (oldest !== undefined) this.map.delete(oldest);
    }
  }

  has(key: string): boolean {
    return this.map.has(key);
  }

  clear(): void {
    this.map.clear();
  }
}

export class ProxiedTileLayer extends L.TileLayer {
  private requestFn: RequestFn;
  private urlTemplate: string;
  private tileCache = new TileLRU(500);
  private prefetchTimer: ReturnType<typeof setTimeout> | null = null;
  private pendingPrefetch = new Set<string>();
  private inflight = new Set<string>();
  private viewportInflight = new Set<string>();
  private currentZoom = -1;
  /** Queued tile requests waiting for zoom to settle */
  private pendingTiles: { key: string; tileUrl: string; img: HTMLImageElement; done: L.DoneCallback }[] = [];
  private zoomDebounceTimer: ReturnType<typeof setTimeout> | null = null;
  /** Callback for viewport loading state (visible tiles only, drives spinner) */
  public onLoadingChange?: (loading: boolean) => void;
  /** Callback for total loading state (viewport + prefetch, drives FetchEnd) */
  public onAllLoadingChange?: (loading: boolean) => void;

  constructor(options: ProxiedTileLayerOptions) {
    // Pass empty string as url — we override createTile entirely.
    super('', options);
    this.requestFn = options.requestFn;
    this.urlTemplate = options.urlTemplate;
  }

  createTile(coords: L.Coords, done: L.DoneCallback): HTMLElement {
    const key = `${coords.z}/${coords.x}/${coords.y}`;
    const img = document.createElement('img');
    img.alt = '';
    img.setAttribute('role', 'presentation');

    // Serve from cache immediately (no debounce needed)
    const cached = this.tileCache.get(key);
    if (cached) {
      img.src = cached;
      setTimeout(() => done(undefined, img), 0);
      return img;
    }

    const intZoom = Math.round(coords.z);
    const zoomChanged = intZoom !== this.currentZoom;

    if (zoomChanged) {
      // Zoom is changing: queue this tile and debounce.
      // When zoom settles (150ms of no new tiles), flush the queue.
      this.currentZoom = intZoom;
      this.pendingPrefetch.clear();
      if (this.prefetchTimer) {
        clearTimeout(this.prefetchTimer);
        this.prefetchTimer = null;
      }
    }

    const tileUrl = this.buildTileUrl(coords);

    if (zoomChanged || this.zoomDebounceTimer) {
      // Zoom in flux: queue and debounce
      this.pendingTiles.push({ key, tileUrl, img, done });
      if (this.zoomDebounceTimer) clearTimeout(this.zoomDebounceTimer);
      this.zoomDebounceTimer = setTimeout(() => {
        this.zoomDebounceTimer = null;
        this.flushPendingTiles();
      }, 150);
    } else {
      // Same zoom (panning): fetch immediately
      this.fetchTile(key, tileUrl, true).then((dataUri) => {
        if (dataUri) {
          img.src = dataUri;
          done(undefined, img);
        } else {
          done(new Error('Tile fetch failed'), img);
        }
      });
      this.schedulePrefetch(coords);
    }

    return img;
  }

  /** Flush queued tiles after zoom has settled */
  private flushPendingTiles(): void {
    const tiles = this.pendingTiles.splice(0);
    for (const { key, tileUrl, img, done } of tiles) {
      // Check cache first (might have been cached from a previous zoom level)
      const cached = this.tileCache.get(key);
      if (cached) {
        img.src = cached;
        setTimeout(() => done(undefined, img), 0);
        continue;
      }
      this.fetchTile(key, tileUrl, true).then((dataUri) => {
        if (dataUri) {
          img.src = dataUri;
          done(undefined, img);
        } else {
          done(new Error('Tile fetch failed'), img);
        }
      });
    }
    // Prefetch neighbors of the last tile (representative of current viewport)
    if (tiles.length > 0) {
      const last = tiles[tiles.length - 1].key.split('/').map(Number);
      this.schedulePrefetch({ z: last[0], x: last[1], y: last[2] } as L.Coords);
    }
  }

  /** Fetch a single tile, deduplicating inflight requests.
   *  viewport=true means this tile is visible; only viewport tiles affect the loading spinner. */
  private async fetchTile(key: string, tileUrl: string, viewport = false): Promise<string | null> {
    // Check cache again (might have been prefetched)
    const cached = this.tileCache.get(key);
    if (cached) return cached;

    // Skip if already in flight
    if (this.inflight.has(key)) {
      // Wait for inflight to complete by polling cache
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
      const res = await this.requestFn('getTile', {
        z: parseInt(key.split('/')[0]),
        x: parseInt(key.split('/')[1]),
        y: parseInt(key.split('/')[2]),
        url: tileUrl,
      } as TileRequestData);

      if (res.success) {
        const tileData = res.data as TileResponse;
        if (tileData.data && tileData.mime) {
          const dataUri = `data:${tileData.mime};base64,${tileData.data}`;
          this.tileCache.set(key, dataUri);
          return dataUri;
        }
        logger.warn('tile-proxy', `missing data/mime for ${key}`);
        return null;
      } else {
        logger.warn('tile-proxy', `error for ${key}: ${String(res.data)}`);
        return null;
      }
    } catch (err) {
      logger.warn('tile-proxy', `catch for ${key}: ${err}`);
      return null;
    } finally {
      this.inflight.delete(key);
      this.viewportInflight.delete(key);
      if (this.viewportInflight.size === 0) this.onLoadingChange?.(false);
      if (this.inflight.size === 0) this.onAllLoadingChange?.(false);
    }
  }

  /** Schedule prefetch of 4 direct neighbors (N/S/E/W), debounced 200ms */
  private schedulePrefetch(coords: L.Coords): void {
    const neighbors = [
      { dx: 0, dy: -1 }, // north
      { dx: 0, dy:  1 }, // south
      { dx: -1, dy: 0 }, // west
      { dx:  1, dy: 0 }, // east
    ];
    for (const { dx, dy } of neighbors) {
      const key = `${coords.z}/${coords.x + dx}/${coords.y + dy}`;
      if (!this.tileCache.has(key) && !this.inflight.has(key)) {
        this.pendingPrefetch.add(key);
      }
    }

    if (this.prefetchTimer) clearTimeout(this.prefetchTimer);
    this.prefetchTimer = setTimeout(() => {
      this.executePrefetch();
    }, 200);
  }

  /** Fire off prefetch requests for all pending neighbors */
  private executePrefetch(): void {
    const keys = [...this.pendingPrefetch];
    this.pendingPrefetch.clear();

    for (const key of keys) {
      if (this.tileCache.has(key) || this.inflight.has(key)) continue;
      const [z, x, y] = key.split('/').map(Number);
      const tileUrl = this.buildTileUrl({ z, x, y } as L.Coords);
      this.fetchTile(key, tileUrl);
    }
  }

  /** Update the URL template (e.g. when provider changes) */
  setUrlTemplate(urlTemplate: string): void {
    this.urlTemplate = urlTemplate;
    this.tileCache.clear();
    this.inflight.clear();
    this.pendingPrefetch.clear();
    this.redraw();
  }

  /** Clear the frontend tile cache */
  clearCache(): void {
    this.tileCache.clear();
  }

  private buildTileUrl(coords: L.Coords): string {
    const subdomains = (this.options.subdomains as string) || 'abc';
    const s = subdomains[Math.abs(coords.x + coords.y) % subdomains.length];
    return this.urlTemplate
      .replace('{s}', s)
      .replace('{z}', String(coords.z))
      .replace('{x}', String(coords.x))
      .replace('{y}', String(coords.y));
  }
}
