<script lang="ts">
  import type { EnumConfig } from '$lib/utils/table-utils';
  import { buildEnumColorMap } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<EnumConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<EnumConfig>;
    style?: string;
  } = $props();

  const items = $derived(config.items ?? []);
  const colorMap = $derived(buildEnumColorMap(config));

  const strVal = $derived(value != null && value !== '' ? String(value) : '');
  const isKnown = $derived(strVal !== '' && items.includes(strVal));
  const color = $derived(strVal ? (colorMap[strVal] ?? '') : '');

  /** Convert hex (#rrggbb) to an rgba string at the given alpha. */
  function hexToRgba(hex: string, alpha: number): string {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  const tagStyle = $derived.by((): string => {
    if (!strVal || !color) return '';
    return [
      `background:${hexToRgba(color, 0.10)}`,
      `color:${color}`,
      `border-color:${hexToRgba(color, 0.25)}`,
      `box-shadow:inset 0 1px 0 ${hexToRgba(color, 0.08)}`,
    ].join(';');
  });

  $effect(() => { style = ''; });
</script>

{#if strVal}
  {#if isKnown}
    <span class="ic-tbl-cell-enum" class:ic-tbl-cell-enum--muted={!color} style={tagStyle || null}>
      {strVal}
    </span>
  {:else}
    <span class="ic-tbl-cell-enum__text">{strVal}</span>
  {/if}
{/if}

<style>
  .ic-tbl-cell-enum {
    display: inline-block;
    padding: 1px 6px;
    border: 1px solid transparent;
    border-radius: 2px;
    font-weight: 500;
    line-height: 1.4;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
  }
  .ic-tbl-cell-enum--muted {
    background: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    border-color: var(--ic-border);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }
  .ic-tbl-cell-enum__text {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
