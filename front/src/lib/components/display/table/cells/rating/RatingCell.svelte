<script lang="ts">
  import type { RatingConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';
  import { toComparable } from './utils';

  let {
    value,
    config = {} as Partial<RatingConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<RatingConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
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
  function starState(i: number, val: number): 'full' | 'half' | 'empty' {
    if (val >= i) return 'full';
    if (allowHalf && val >= i - 0.5) return 'half';
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

  // ── Edit mode ──────────────────────────────────
  let hoverVal = $state<number | null>(null);

  // The value shown by stars: hover preview > current display value
  const renderVal = $derived(editing && hoverVal != null ? hoverVal : displayVal);

  function handleStarClick(e: MouseEvent, starIndex: number) {
    if (!editing) return;
    e.stopPropagation();
    const clickVal = getStarValue(e, starIndex);
    oncommitedit?.(value, clickVal);
  }

  function handleStarEnter(e: MouseEvent, starIndex: number) {
    if (!editing) return;
    hoverVal = getStarValue(e, starIndex);
  }

  function handleContainerLeave() {
    hoverVal = null;
  }

  /** Get value from mouse position relative to star. Left half = N-0.5, right half = N. */
  function getStarValue(e: MouseEvent, starIndex: number): number {
    if (!allowHalf) return starIndex;
    const target = e.currentTarget as HTMLElement;
    const rect = target.getBoundingClientRect();
    const isLeftHalf = (e.clientX - rect.left) < rect.width / 2;
    return isLeftHalf ? starIndex - 0.5 : starIndex;
  }

  function handleEditKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Escape') {
      e.preventDefault();
      oncanceledit?.();
    }
  }
</script>

{#if !isNaN(numVal) || editing}
  <span
    class="ic-tbl-cell-rating"
    class:ic-tbl-cell-rating--editing={editing}
    title={editing ? '' : tooltip}
    role="radiogroup"
    onpointerleave={handleContainerLeave}
    onkeydown={handleEditKeydown}
    tabindex={editing ? 0 : -1}
  >
    {#each {length: maxStars} as _, idx (idx)}
      {@const state = starState(idx + 1, renderVal)}
      <svg
        class="ic-tbl-cell-rating__star"
        class:ic-tbl-cell-rating__star--clickable={editing}
        viewBox="0 0 24 24"
        width="14"
        height="14"
        role="radio"
        aria-checked={state === 'full'}
        tabindex={-1}
        onclick={(e: MouseEvent) => handleStarClick(e, idx + 1)}
        onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') handleStarClick(e as any, idx + 1); }}
        onpointerenter={(e: MouseEvent) => handleStarEnter(e, idx + 1)}
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
  .ic-tbl-cell-rating--editing {
    outline: 1px solid var(--ic-primary);
    outline-offset: 1px;
    border-radius: 2px;
    padding: 1px 2px;
  }
  .ic-tbl-cell-rating__star {
    display: block;
    flex-shrink: 0;
  }
  .ic-tbl-cell-rating__star--clickable {
    cursor: pointer;
  }
</style>
