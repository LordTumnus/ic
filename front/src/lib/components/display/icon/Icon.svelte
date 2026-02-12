<script lang="ts">
  import logger from '$lib/core/logger';
  import type { CssSize } from '$lib/utils/css';
  import { toSize, toNumericSize } from '$lib/utils/css';
  import { iconMap } from '$lib/utils/icons';

  interface IconTypeData {
    type: 'lucide' | 'path' | 'file';
    value: string;
  }

  let {
    iconType = $bindable<IconTypeData | null>(null),
    size = $bindable<CssSize>(16),
    color = $bindable(''),
    strokeWidth = $bindable(2),
  }: {
    iconType?: IconTypeData | null;
    size?: CssSize;
    color?: string;
    strokeWidth?: number;
  } = $props();

  // Get numeric size for SVG attributes (default 24 if string)
  const svgSize = $derived(toNumericSize(size, 24));

  // Resolve raw SVG string from iconType descriptor
  let rawSvg = $derived.by(() => {
    if (!iconType) return '';

    switch (iconType.type) {
      case 'lucide': {
        const key = iconType.value;
        const svg = iconMap.get(key) ?? iconMap.get(key.toLowerCase());
        if (!svg) {
          logger.error('Icon', `Icon not found: "${key}". Browse https://lucide.dev/icons`);
          return '';
        }
        return svg;
      }
      case 'file': {
        try {
          return atob(iconType.value);
        } catch (e) {
          logger.error('Icon', `Failed to decode base64 SVG: ${e}`);
          return '';
        }
      }
      case 'path':
        return `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${iconType.value}"/></svg>`;
      default:
        return '';
    }
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
