<script lang="ts">
  import type { RatingConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';
  import { toComparable } from './utils';

  let {
    value,
    config = {} as Partial<RatingConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<RatingConfig>;
    style?: string;
  } = $props();

  const maxStars = $derived(config.maxStars ?? 5);
  const allowHalf = $derived(config.allowHalf !== false);
  const color = $derived(config.color ?? '#f59e0b');

  const numVal = $derived(value != null ? Number(value) : NaN);
  const displayVal = $derived.by(() => {
    if (isNaN(numVal)) return 0;
    const clamped = Math.max(0, Math.min(numVal, maxStars));
    return allowHalf ? Math.round(clamped * 2) / 2 : Math.round(clamped);
  });

  const tooltip = $derived(
    !isNaN(numVal) ? `${numVal} / ${maxStars}` : '',
  );

  /** Star state for position i (1-based). */
  function starState(i: number): 'full' | 'half' | 'empty' {
    if (displayVal >= i) return 'full';
    if (allowHalf && displayVal >= i - 0.5) return 'half';
    return 'empty';
  }

  // Color rules
  const colorRules = $derived(config.colorRules as ColorRuleConfig[] | undefined);
  const bgColor = $derived(
    !isNaN(numVal) && colorRules?.length
      ? evaluateColorRules(numVal, colorRules, toComparable)
      : null
  );

  $effect(() => {
    style = bgColor
      ? `background-color: ${bgColor}; color: rgba(0,0,0,0.85);`
      : '';
  });
</script>

{#if !isNaN(numVal)}
  <span class="ic-tbl-cell-rating" title={tooltip}>
    {#each {length: maxStars} as _, idx (idx)}
      {@const state = starState(idx + 1)}
      <svg
        class="ic-tbl-cell-rating__star"
        viewBox="0 0 24 24"
        width="14"
        height="14"
      >
        <!-- Empty star (always rendered as background) -->
        <path
          d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14l-5-4.87 6.91-1.01z"
          fill="none"
          stroke={color}
          stroke-width="1.5"
          opacity="0.3"
        />
        {#if state === 'full'}
          <path
            d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14l-5-4.87 6.91-1.01z"
            fill={color}
            stroke="none"
          />
        {:else if state === 'half'}
          <path
            d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14l-5-4.87 6.91-1.01z"
            fill={color}
            stroke="none"
            clip-path="inset(0 50% 0 0)"
          />
        {/if}
      </svg>
    {/each}
  </span>
{/if}

<style>
  .ic-tbl-cell-rating {
    display: inline-flex;
    align-items: center;
    gap: 1px;
    line-height: 1;
    white-space: nowrap;
  }
  .ic-tbl-cell-rating__star {
    display: block;
    flex-shrink: 0;
  }
</style>
