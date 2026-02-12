/**
 * Shared Lucide icon map — imported once, used by Icon, Tag, TreePanel, TreeSelect.
 *
 * Vite's `import.meta.glob` with `eager: true` inlines all SVG strings at build time.
 * By centralizing this in a single module, the ~125KB of icon data is bundled into
 * one shared chunk instead of being duplicated in every consumer's asset.
 */

const lucideModules = import.meta.glob(
  '/node_modules/lucide-static/icons/*.svg',
  { query: '?raw', import: 'default', eager: true }
) as Record<string, string>;

export const iconMap = new Map<string, string>();
for (const [path, content] of Object.entries(lucideModules)) {
  const filename = path.split('/').pop()?.replace('.svg', '') ?? '';
  iconMap.set(filename, content);
}

/** Resolve an icon name to its SVG string, resized to the given pixel dimensions. */
export function resolveIcon(name: string | undefined, size: number): string {
  if (!name) return '';
  const k = name.toLowerCase();
  let svg = iconMap.get(k) ?? iconMap.get(name) ?? '';
  if (!svg) return '';
  svg = svg.replace(/width="[^"]*"/, `width="${size}"`);
  svg = svg.replace(/height="[^"]*"/, `height="${size}"`);
  return svg;
}

/** Structured icon descriptor from ic.IconType serialization. */
export interface IconTypeData {
  type: 'lucide' | 'path' | 'file' | 'raster';
  value: string;
}

/** Resolve a string icon name OR an IconTypeData object to its SVG/HTML string. */
export function resolveIconType(
  icon: string | IconTypeData | null | undefined,
  size: number
): string {
  if (!icon) return '';
  if (typeof icon === 'string') return resolveIcon(icon, size);
  switch (icon.type) {
    case 'lucide': return resolveIcon(icon.value, size);
    case 'path':
      return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${icon.value}"/></svg>`;
    case 'file':
      try {
        let svg = atob(icon.value);
        svg = svg.replace(/width="[^"]*"/, `width="${size}"`);
        svg = svg.replace(/height="[^"]*"/, `height="${size}"`);
        return svg;
      } catch { return ''; }
    case 'raster':
      return `<img src="${icon.value}" width="${size}" height="${size}" style="display:block" alt="" />`;
    default: return '';
  }
}
