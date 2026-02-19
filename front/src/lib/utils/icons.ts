/**
 * Shared Lucide icon map and asset-aware icon/image resolvers.
 *
 * Vite's `import.meta.glob` with `eager: true` inlines all SVG strings at build time.
 * By centralizing this in a single module, the ~125KB of icon data is bundled into
 * one shared chunk instead of being duplicated in every consumer's asset.
 */

import type { AssetData } from './asset-cache';
import { resolveAssetAsString, resolveAssetAsDataUri } from './asset-cache';

// --- Lucide map (internal) ---
const lucideModules = import.meta.glob(
  '/node_modules/lucide-static/icons/*.svg',
  { query: '?raw', import: 'default', eager: true }
) as Record<string, string>;

export const iconMap = new Map<string, string>();
for (const [path, content] of Object.entries(lucideModules)) {
  iconMap.set(path.split('/').pop()?.replace('.svg', '') ?? '', content);
}

// --- Types ---

/** Icon source: Lucide name, file SVG asset, or empty */
export type IconSource = string | AssetData | null | undefined;

/** Image source: always an encoded asset or empty */
export type ImageSource = AssetData | null | undefined;

// --- Helpers ---
function applySvgSize(svg: string, size: number): string {
  if (svg.includes('width='))
    svg = svg.replace(/width="[^"]*"/, `width="${size}"`);
  else
    svg = svg.replace('<svg', `<svg width="${size}"`);
  if (svg.includes('height='))
    svg = svg.replace(/height="[^"]*"/, `height="${size}"`);
  else
    svg = svg.replace('<svg', `<svg height="${size}"`);
  return svg;
}

// --- Public API ---

/**
 * Resolve an icon source to its SVG string, resized to the given pixel dimensions.
 *
 * Handles:
 *   - string → Lucide icon name lookup
 *   - AssetData ({hash, mime?, data?}) → file-based SVG via asset cache
 *   - null/undefined → empty string
 */
export function resolveIcon(source: IconSource, size: number): string {
  if (!source) return '';

  // String → Lucide icon name
  if (typeof source === 'string') {
    const svg = iconMap.get(source.toLowerCase()) ?? iconMap.get(source);
    return svg ? applySvgSize(svg, size) : '';
  }

  // Object → file-based SVG icon (ic.Asset with file/url type)
  if (source.hash) {
    const svg = resolveAssetAsString(source);
    return svg ? applySvgSize(svg, size) : '';
  }

  return '';
}

/**
 * Resolve an image asset to a data URI suitable for `<img src>`.
 */
export function resolveImageSource(source: ImageSource): string {
  if (!source) return '';
  return resolveAssetAsDataUri(source);
}
