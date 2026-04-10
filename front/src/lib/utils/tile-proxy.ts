/**
 * ProxiedTileLayer — custom Leaflet TileLayer that fetches tiles through
 * the IC framework's request() mechanism (MATLAB webread proxy).
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

export class ProxiedTileLayer extends L.TileLayer {
  private requestFn: RequestFn;
  private urlTemplate: string;
  private tileCache: Map<string, string> = new Map();

  constructor(options: ProxiedTileLayerOptions) {
    // Pass empty string as url — we override createTile entirely
    super('', options);
    this.requestFn = options.requestFn;
    this.urlTemplate = options.urlTemplate;
  }

  createTile(coords: L.Coords, done: L.DoneCallback): HTMLElement {
    const key = `${coords.z}/${coords.x}/${coords.y}`;
    const img = document.createElement('img');
    img.alt = '';
    img.setAttribute('role', 'presentation');

    const cached = this.tileCache.get(key);
    if (cached) {
      img.src = cached;
      // Use setTimeout to avoid synchronous done() call which can cause
      // issues with Leaflet's tile loading state machine
      setTimeout(() => done(undefined, img), 0);
      return img;
    }

    // Build the full URL for this tile (MATLAB will fetch it)
    const tileUrl = this.buildTileUrl(coords);

    logger.info('tile-proxy', `requesting tile ${key}, url: ${tileUrl}`);
    this.requestFn('getTile', { z: coords.z, x: coords.x, y: coords.y, url: tileUrl } as TileRequestData)
      .then((res) => {
        logger.info('tile-proxy', `response for ${key}: success=${res.success}, dataType=${typeof res.data}`);
        if (res.success) {
          const tileData = res.data as TileResponse;
          if (!tileData.data || !tileData.mime) {
            logger.warn('tile-proxy', `missing data/mime in response for ${key}: ${JSON.stringify(Object.keys(tileData))}`);
            done(new Error('Missing tile data'), img);
            return;
          }
          const dataUri = `data:${tileData.mime};base64,${tileData.data}`;
          this.tileCache.set(key, dataUri);
          img.src = dataUri;
          done(undefined, img);
        } else {
          logger.warn('tile-proxy', `error for ${key}: ${String(res.data)}`);
          done(new Error(String(res.data)), img);
        }
      })
      .catch((err) => {
        logger.warn('tile-proxy', `catch for ${key}: ${err}`);
        done(err, img);
      });

    return img;
  }

  /** Update the URL template (e.g. when provider changes) */
  setUrlTemplate(urlTemplate: string): void {
    this.urlTemplate = urlTemplate;
    this.tileCache.clear();
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
