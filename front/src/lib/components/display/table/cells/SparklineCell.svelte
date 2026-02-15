<script lang="ts">
  let {
    value,
    config = {},
  }: {
    value?: unknown;
    config?: Record<string, unknown>;
  } = $props();

  const sparkType = $derived((config.type as string) ?? 'line');
  const height = $derived((config.height as number) ?? 20);
  const colorVar = $derived(`var(--ic-${(config.color as string) ?? 'primary'})`);

  const data = $derived(Array.isArray(value) ? value.map(Number) : []);

  // Compute SVG points for line sparkline
  const linePath = $derived.by(() => {
    if (data.length < 2) return '';
    const min = Math.min(...data);
    const max = Math.max(...data);
    const range = max - min || 1;
    const w = 80;
    const h = height - 4; // 2px padding top/bottom
    const step = w / (data.length - 1);
    return data
      .map((v, i) => {
        const x = i * step;
        const y = h - ((v - min) / range) * h + 2;
        return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(' ');
  });

  // Compute bar positions
  const bars = $derived.by(() => {
    if (data.length === 0) return [];
    const min = Math.min(...data);
    const max = Math.max(...data);
    const range = max - min || 1;
    const w = 80;
    const h = height - 4;
    const barW = Math.max(1, (w / data.length) - 1);
    const step = w / data.length;
    return data.map((v, i) => {
      const barH = ((v - min) / range) * h;
      return {
        x: i * step,
        y: h - barH + 2,
        width: barW,
        height: Math.max(1, barH),
      };
    });
  });
</script>

{#if data.length > 0}
  <svg
    class="ic-tbl-cell-spark"
    width="80"
    height={height}
    viewBox="0 0 80 {height}"
    fill="none"
  >
    {#if sparkType === 'bar'}
      {#each bars as bar}
        <rect
          x={bar.x}
          y={bar.y}
          width={bar.width}
          height={bar.height}
          fill={colorVar}
          opacity="0.7"
        />
      {/each}
    {:else}
      <path d={linePath} stroke={colorVar} stroke-width="1.5" fill="none" />
    {/if}
  </svg>
{/if}

<style>
  .ic-tbl-cell-spark {
    display: block;
    flex-shrink: 0;
  }
</style>
