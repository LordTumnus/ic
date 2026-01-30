<script lang="ts">
  import logger from '$lib/core/logger';

  // Import all icons at build time using Vite's glob import
  const iconModules = import.meta.glob('/static/icons/*.svg', {
    query: '?raw',
    import: 'default',
    eager: true
  }) as Record<string, string>;

  // Build lookup map: "info" -> svg content
  const iconMap = new Map<string, string>();
  for (const [path, content] of Object.entries(iconModules)) {
    const filename = path.split('/').pop()?.replace('.svg', '') ?? '';
    iconMap.set(filename, content);
  }

  let {
    name = $bindable('Info'),
    size = $bindable(24),
    color = $bindable(''),
    strokeWidth = $bindable(2),
    customSvg = $bindable(''),
  }: {
    name?: string;
    size?: number;
    color?: string;
    strokeWidth?: number;
    customSvg?: string;
  } = $props();

  function toKebabCase(str: string): string {
    // Ensure string, extract last part if it's a qualified name like "ic.IconName.File"
    const s = String(str);
    const parts = s.split('.');
    const iconName = parts[parts.length - 1];
    return iconName.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
  }

  function decodeBase64(base64: string): string {
    try {
      return atob(base64);
    } catch (e) {
      logger.error('Icon', `Failed to decode base64 SVG: ${e}`);
      return '';
    }
  }

  // Get SVG from bundled icons or custom base64
  let rawSvg = $derived.by(() => {
    if (customSvg) {
      return decodeBase64(customSvg);
    }
    const iconKey = toKebabCase(name);
    const svg = iconMap.get(iconKey);
    if (!svg) {
      logger.error('Icon', `Icon not found: ${iconKey}`);
      return '';
    }
    return svg;
  });

  // Process SVG to apply size, color, and strokeWidth
  let processedSvg = $derived.by(() => {
    if (!rawSvg) return '';

    let svg = rawSvg;

    // Set width and height
    svg = svg.replace(/width="[^"]*"/, `width="${size}"`);
    svg = svg.replace(/height="[^"]*"/, `height="${size}"`);
    if (!svg.includes('width=')) svg = svg.replace('<svg', `<svg width="${size}"`);
    if (!svg.includes('height=')) svg = svg.replace('<svg', `<svg height="${size}"`);

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
  style:width="{size}px"
  style:height="{size}px"
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
