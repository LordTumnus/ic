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
