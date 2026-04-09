<script lang="ts">
  import type { CssSize } from '$lib/utils/css';
  import { toSize, toNumericSize } from '$lib/utils/css';
  import { resolveIcon, type IconSource } from '$lib/utils/icons';

  let {
    id = '',
    source = $bindable<IconSource>(null),
    size = $bindable<CssSize>(16),
    color = $bindable(''),
    strokeWidth = $bindable(2),
  }: {
    id?: string;
    source?: IconSource;
    size?: CssSize;
    color?: string;
    strokeWidth?: number;
  } = $props();

  // Get numeric size for SVG attributes (default 24 if string)
  const svgSize = $derived(toNumericSize(size, 24));

  // Resolve icon source → sized SVG, then apply strokeWidth and color
  let processedSvg = $derived.by(() => {
    let svg = resolveIcon(source, svgSize);
    if (!svg) return '';

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
  {id}
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
