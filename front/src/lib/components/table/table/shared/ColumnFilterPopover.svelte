<script lang="ts">
  import type { TableColumn } from '$lib/utils/table-utils';
  import TextFilter from '../cells/text/TextFilter.svelte';
  import NumberFilter from '../cells/number/NumberFilter.svelte';
  import BooleanFilter from '../cells/boolean/BooleanFilter.svelte';
  import ProgressBarFilter from '../cells/progressbar/ProgressBarFilter.svelte';
  import SparklineFilter from '../cells/sparkline/SparklineFilter.svelte';
  import ImageFilter from '../cells/image/ImageFilter.svelte';
  import EnumFilter from '../cells/enum/EnumFilter.svelte';
  import RatingFilter from '../cells/rating/RatingFilter.svelte';
  import DateFilter from '../cells/date/DateFilter.svelte';

  let {
    column,
    filterValue = null,
    totalRowCount = 0,
    matchCount,
    onchange,
    onclose,
  }: {
    column: TableColumn;
    filterValue?: unknown;
    totalRowCount?: number;
    matchCount?: number;
    onchange?: (field: string, value: unknown) => void;
    onclose?: () => void;
  } = $props();

  let popoverEl = $state<HTMLDivElement>(null!);
  let flipX = $state(false);
  let flipY = $state(false);
  let clearCount = $state(0);

  function handleFilterChange(value: unknown) {
    onchange?.(column.field, value);
  }

  function handleClear() {
    onchange?.(column.field, null);
    clearCount++;
  }

  function handleWindowEscape(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose?.();
  }

  function handlePopoverKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      const headerCell = popoverEl?.closest('.ic-tbl__hcell') as HTMLElement | null;
      onclose?.();
      headerCell?.focus();
      e.stopPropagation();
      return;
    }
    e.stopPropagation();
  }

  // Flip logic: reposition if popup overflows the table container
  $effect(() => {
    if (!popoverEl) return;
    const table = popoverEl.closest('.ic-tbl') as HTMLElement;
    if (!table) return;
    const cell = popoverEl.offsetParent as HTMLElement;
    if (!cell) return;

    const cellRect = cell.getBoundingClientRect();
    const tableRect = table.getBoundingClientRect();
    const popRect = popoverEl.getBoundingClientRect();

    const spaceBelow = tableRect.bottom - cellRect.bottom - 2;
    const spaceAbove = cellRect.top - tableRect.top - 2;
    flipY = popRect.height > spaceBelow && spaceAbove > spaceBelow;

    const rightAlignSpace = cellRect.right - tableRect.left;
    const leftAlignSpace = tableRect.right - cellRect.left;
    flipX = popRect.width > rightAlignSpace && leftAlignSpace > rightAlignSpace;
  });

  // Close on outside click
  $effect(() => {
    function handleOutside(e: PointerEvent) {
      if (!popoverEl) return;
      const target = e.target as Node;
      if (popoverEl.contains(target)) return;
      if ((target as Element).closest?.('.ic-tbl__filter-btn')) return;
      onclose?.();
    }
    document.addEventListener('pointerdown', handleOutside, true);
    return () => document.removeEventListener('pointerdown', handleOutside, true);
  });
</script>

<svelte:window onkeydown={handleWindowEscape} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<div
  class="ic-tbl-filter"
  class:ic-tbl-filter--flip-x={flipX}
  class:ic-tbl-filter--flip-y={flipY}
  bind:this={popoverEl}
  role="dialog"
  tabindex={-1}
  onclick={(e: MouseEvent) => e.stopPropagation()}
  onkeydown={handlePopoverKeydown}
>
  <div class="ic-tbl-filter__header">
    <span class="ic-tbl-filter__title">{column.header}</span>
    <button class="ic-tbl-filter__clear" onclick={handleClear}>Clear</button>
  </div>

  <div class="ic-tbl-filter__body">
    {#key clearCount}
      {#if column.type === 'number'}
        <NumberFilter initialValue={filterValue} onchange={handleFilterChange} />
      {:else if column.type === 'progressbar'}
        <ProgressBarFilter initialValue={filterValue} config={column.config} onchange={handleFilterChange} />
      {:else if column.type === 'sparkline'}
        <SparklineFilter initialValue={filterValue} config={column.config} onchange={handleFilterChange} />
      {:else if column.type === 'image'}
        <ImageFilter initialValue={filterValue} onchange={handleFilterChange} />
      {:else if column.type === 'enum'}
        <EnumFilter initialValue={filterValue} config={column.config} onchange={handleFilterChange} />
      {:else if column.type === 'rating'}
        <RatingFilter initialValue={filterValue} config={column.config} onchange={handleFilterChange} />
      {:else if column.type === 'date'}
        <DateFilter initialValue={filterValue} onchange={handleFilterChange} />
      {:else if column.type === 'boolean'}
        <BooleanFilter initialValue={filterValue} onchange={handleFilterChange} />
      {:else}
        <TextFilter initialValue={filterValue} onchange={handleFilterChange} />
      {/if}
    {/key}
  </div>

  {#if matchCount != null}
    <div class="ic-tbl-filter__footer">
      {matchCount} of {totalRowCount} rows
    </div>
  {/if}
</div>

<style>
  .ic-tbl-filter {
    position: absolute;
    top: calc(100% + 2px);
    right: 0;
    z-index: 50;
    min-width: 170px;
    max-width: 240px;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 1px 0 rgba(0, 0, 0, 0.1), 0 2px 6px rgba(0, 0, 0, 0.12);
    font-size: 0.8rem;
  }
  .ic-tbl-filter--flip-y {
    top: auto;
    bottom: calc(100% + 2px);
  }
  .ic-tbl-filter--flip-x {
    right: auto;
    left: 0;
  }
  .ic-tbl-filter__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 5px 8px;
    border-bottom: 1px solid var(--ic-border);
  }
  .ic-tbl-filter__title {
    font-weight: 600;
    font-size: 0.7rem;
    color: var(--ic-muted-foreground);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ic-tbl-filter__clear {
    background: none;
    border: none;
    color: var(--ic-primary);
    cursor: pointer;
    font-size: 0.65rem;
    padding: 0;
    white-space: nowrap;
  }
  .ic-tbl-filter__clear:hover { text-decoration: underline; }
  .ic-tbl-filter__body {
    padding: 6px 8px 8px;
  }
  .ic-tbl-filter__footer {
    padding: 3px 8px 4px;
    border-top: 1px solid var(--ic-border);
    font-size: 0.65rem;
    color: var(--ic-muted-foreground);
    text-align: right;
    font-variant-numeric: tabular-nums;
  }
</style>
