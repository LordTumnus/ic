<script lang="ts">
  import { untrack } from 'svelte';
  import type { NumberFilterValue, RatingConfig } from '$lib/utils/table-utils';

  let {
    initialValue,
    config = {} as Partial<RatingConfig>,
    onchange,
  }: {
    initialValue?: unknown;
    config?: Partial<RatingConfig>;
    onchange?: (value: unknown) => void;
  } = $props();

  type Mode = 'stars' | 'isEmpty' | 'isNotEmpty';

  const maxStars = untrack(() => config?.maxStars ?? 5);
  const color = untrack(() => config?.color ?? '#f59e0b');

  function detectMode(val: unknown): Mode {
    if (val && typeof val === 'object') {
      if ('isEmpty' in (val as Record<string, unknown>)) return 'isEmpty';
      if ('isNotEmpty' in (val as Record<string, unknown>)) return 'isNotEmpty';
    }
    return 'stars';
  }

  const init = untrack(() => initialValue);
  const initMode = detectMode(init);
  let mode = $state<Mode>(initMode);
  let minRating = $state<number | null>(
    initMode === 'stars' ? ((init as NumberFilterValue)?.min ?? null) : null,
  );
  let hovered = $state<number | null>(null);

  function handleClick(star: number) {
    if (mode !== 'stars') {
      mode = 'stars';
    }
    // Clicking same star again clears filter
    if (minRating === star) {
      minRating = null;
      onchange?.(null);
    } else {
      minRating = star;
      onchange?.({ min: star } as NumberFilterValue);
    }
  }

  function toggleMode(m: 'isEmpty' | 'isNotEmpty') {
    if (mode === m) {
      mode = 'stars';
      emit();
    } else {
      mode = m;
      minRating = null;
      emit();
    }
  }

  function emit() {
    if (mode === 'isEmpty') { onchange?.({ isEmpty: true }); return; }
    if (mode === 'isNotEmpty') { onchange?.({ isNotEmpty: true }); return; }
    onchange?.(minRating != null ? { min: minRating } : null);
  }

  /** Star visual state for the filter row. */
  function isLit(star: number): boolean {
    const target = hovered ?? minRating;
    return target != null && star <= target;
  }
</script>

{#if mode === 'stars'}
  <div class="ic-tbl-fr">
    <div
      class="ic-tbl-fr__stars"
      role="group"
      onpointerleave={() => (hovered = null)}
    >
      {#each {length: maxStars} as _, idx (idx)}
        {@const star = idx + 1}
        <button
          class="ic-tbl-fr__star-btn"
          title="{star}+"
          onpointerenter={() => (hovered = star)}
          onclick={() => handleClick(star)}
        >
          <svg viewBox="0 0 24 24" width="18" height="18">
            <path
              d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14l-5-4.87 6.91-1.01z"
              fill={isLit(star) ? color : 'none'}
              stroke={color}
              stroke-width="1.5"
              opacity={isLit(star) ? 1 : 0.3}
            />
          </svg>
        </button>
      {/each}
    </div>
    {#if minRating != null}
      <div class="ic-tbl-fr__hint">{minRating}+ stars</div>
    {:else}
      <div class="ic-tbl-fr__hint ic-tbl-fr__hint--muted">Click to filter</div>
    {/if}
  </div>
{:else}
  <div class="ic-tbl-fr__hint">
    {mode === 'isEmpty' ? 'Showing empty cells' : 'Showing non-empty cells'}
  </div>
{/if}

<div class="ic-tbl-fn__pills">
  <button
    class="ic-tbl-fn__pill"
    class:ic-tbl-fn__pill--active={mode === 'isEmpty'}
    onclick={() => toggleMode('isEmpty')}
  >Empty</button>
  <button
    class="ic-tbl-fn__pill"
    class:ic-tbl-fn__pill--active={mode === 'isNotEmpty'}
    onclick={() => toggleMode('isNotEmpty')}
  >Has value</button>
</div>

<style>
  .ic-tbl-fr {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }
  .ic-tbl-fr__stars {
    display: flex;
    gap: 2px;
  }
  .ic-tbl-fr__star-btn {
    background: none;
    border: none;
    padding: 2px;
    cursor: pointer;
    line-height: 0;
    border-radius: 2px;
  }
  .ic-tbl-fr__star-btn:hover {
    background: var(--ic-secondary);
  }
  .ic-tbl-fr__hint {
    font-size: 0.7rem;
    color: var(--ic-foreground);
    text-align: center;
  }
  .ic-tbl-fr__hint--muted {
    color: var(--ic-muted-foreground);
    font-style: italic;
  }
  /* Shared pill styles (same as NumberFilter) */
  .ic-tbl-fn__pills {
    display: flex;
    gap: 4px;
    margin-top: 6px;
  }
  .ic-tbl-fn__pill {
    flex: 1;
    padding: 3px 0;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    font: inherit;
    font-size: 0.65rem;
    cursor: pointer;
    text-align: center;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
    transition: all 0.1s ease;
  }
  .ic-tbl-fn__pill:hover {
    background: var(--ic-muted);
    color: var(--ic-foreground);
  }
  .ic-tbl-fn__pill--active {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    border-color: var(--ic-primary);
    box-shadow: none;
  }
</style>
