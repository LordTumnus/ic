<script lang="ts">
  import logger from '$lib/core/logger';
  import type { CssSize } from '$lib/utils/css';
  import { toSize, toNumericSize } from '$lib/utils/css';
  import { iconMap } from '$lib/utils/icons';

  let {
    name = $bindable('info'),
    size = $bindable<CssSize>(16),
    color = $bindable(''),
    strokeWidth = $bindable(2),
    pathData = $bindable(''),
    customSvg = $bindable(''),
  }: {
    name?: string;
    size?: CssSize;
    color?: string;
    strokeWidth?: number;
    pathData?: string;
    customSvg?: string;
  } = $props();

  // Get numeric size for SVG attributes (default 24 if string)
  const svgSize = $derived(toNumericSize(size, 24));

  function resolveIconName(str: string): string {
    // Direct kebab-case lookup (primary path: "chevron-down")
    const key = String(str);
    if (iconMap.has(key)) return key;
    // Lowercase fallback ("Info" → "info")
    const lower = key.toLowerCase();
    if (iconMap.has(lower)) return lower;
    // Not found
    return key;
  }

  function decodeBase64(base64: string): string {
    try {
      return atob(base64);
    } catch (e) {
      logger.error('Icon', `Failed to decode base64 SVG: ${e}`);
      return '';
    }
  }

  // Create SVG wrapper for path data
  function createPathSvg(d: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>`;
  }

  // Get SVG from: customSvg (file) > pathData > name (built-in)
  let rawSvg = $derived.by(() => {
    // Priority 1: Custom SVG from file (base64)
    if (customSvg) {
      return decodeBase64(customSvg);
    }
    // Priority 2: SVG path data
    if (pathData) {
      return createPathSvg(pathData);
    }
    // Priority 3: Built-in icon by name
    const iconKey = resolveIconName(name);
    const svg = iconMap.get(iconKey);
    if (!svg) {
      logger.error('Icon', `Icon not found: "${name}". Browse https://lucide.dev/icons`);
      return '';
    }
    return svg;
  });

  // Process SVG to apply size, color, and strokeWidth
  let processedSvg = $derived.by(() => {
    if (!rawSvg) return '';

    let svg = rawSvg;

    // Set width and height (use numeric svgSize for SVG attributes)
    svg = svg.replace(/width="[^"]*"/, `width="${svgSize}"`);
    svg = svg.replace(/height="[^"]*"/, `height="${svgSize}"`);
    if (!svg.includes('width=')) svg = svg.replace('<svg', `<svg width="${svgSize}"`);
    if (!svg.includes('height=')) svg = svg.replace('<svg', `<svg height="${svgSize}"`);

    // Set stroke-width
    svg = svg.replace(/stroke-width="[^"]*"/g, `stroke-width="${strokeWidth}"`);

    // Apply color
    if (color) {
      svg = svg.replace(/stroke="currentColor"/g, `stroke="${color}"`);
      svg = svg.replace(/fill="currentColor"/g, `fill="${color}"`);
    }

    return svg;
  });
</script>

<span
  class="ic-icon"
  style:width={toSize(size)}
  style:height={toSize(size)}
  style:color={color || null}
>
  {#if processedSvg}
    {@html processedSvg}
  {/if}
</span>

<style>
  .ic-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
</style>
