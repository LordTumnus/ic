<script lang="ts">
  import { untrack } from 'svelte';
  import type { TableColumn, FilterState, NumberFilterValue } from '$lib/utils/table-utils';

  let {
    column,
    filterValue = null,
    uniqueValues = [],
    onchange,
    onclose,
  }: {
    column: TableColumn;
    filterValue?: unknown;
    uniqueValues?: string[];
    onchange?: (field: string, value: unknown) => void;
    onclose?: () => void;
  } = $props();

  let popoverEl: HTMLDivElement;

  // Seed local state from prop — one-time capture is correct since
  // the popover is destroyed/recreated each time it opens
  const init = untrack(() => filterValue);
  let textValue = $state((init as string) ?? '');
  let numMin = $state((init as NumberFilterValue)?.min ?? null);
  let numMax = $state((init as NumberFilterValue)?.max ?? null);
  let badgeSelected = $state<string[]>(Array.isArray(init) ? init : []);
  let boolValue = $state<boolean | null>(init as boolean | null);

  function emitChange() {
    if (column.type === 'number') {
      const range: NumberFilterValue = {};
      if (numMin != null) range.min = numMin;
      if (numMax != null) range.max = numMax;
      onchange?.(column.field, (range.min != null || range.max != null) ? range : null);
    } else if (column.type === 'badge') {
      onchange?.(column.field, badgeSelected.length > 0 ? badgeSelected : null);
    } else if (column.type === 'boolean') {
      onchange?.(column.field, boolValue);
    } else {
      onchange?.(column.field, textValue || null);
    }
  }

  function handleClear() {
    textValue = '';
    numMin = null;
    numMax = null;
    badgeSelected = [];
    boolValue = null;
    onchange?.(column.field, null);
  }

  // Window-level fallback: close on Escape even when focus is outside the popover
  function handleWindowEscape(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose?.();
  }

  // Popover-level: stop ALL key events from reaching the header cell
  function handlePopoverKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      const headerCell = popoverEl?.closest('.ic-tbl__hcell') as HTMLElement | null;
      onclose?.();
      headerCell?.focus();
      e.stopPropagation();
      return;
    }
    // Enter on a checkbox label should toggle it (native checkboxes only respond to Space)
    if (e.key === 'Enter') {
      const target = e.target as HTMLElement;
      const checkLabel = target.closest('.ic-tbl-filter__check');
      if (checkLabel) {
        const checkbox = checkLabel.querySelector('input[type="checkbox"]') as HTMLInputElement | null;
        if (checkbox) {
          checkbox.click();
          e.preventDefault();
        }
      }
    }
    // Stop all key events from bubbling to the header cell
    e.stopPropagation();
  }

  function toggleBadge(val: string) {
    if (badgeSelected.includes(val)) {
      badgeSelected = badgeSelected.filter(v => v !== val);
    } else {
      badgeSelected = [...badgeSelected, val];
    }
    emitChange();
  }

  function cycleBool() {
    if (boolValue === null) boolValue = true;
    else if (boolValue === true) boolValue = false;
    else boolValue = null;
    emitChange();
  }

  // Auto-focus the first input when the popover opens
  $effect(() => {
    const input = popoverEl?.querySelector('input, button.ic-tbl-filter__bool') as HTMLElement | null;
    input?.focus();
  });

  // Close on outside click — capture phase so stopPropagation can't block it
  $effect(() => {
    function handleOutside(e: PointerEvent) {
      if (!popoverEl) return;
      const target = e.target as Node;
      if (popoverEl.contains(target)) return;
      // Don't close if clicking the filter button itself (its toggle handles open/close)
      if ((target as Element).closest?.('.ic-tbl__filter-btn')) return;
      onclose?.();
    }
    document.addEventListener('pointerdown', handleOutside, true);
    return () => document.removeEventListener('pointerdown', handleOutside, true);
  });
</script>

<svelte:window onkeydown={handleWindowEscape} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<div class="ic-tbl-filter" bind:this={popoverEl} role="dialog" tabindex={-1} onclick={(e: MouseEvent) => e.stopPropagation()} onkeydown={handlePopoverKeydown}>
  <div class="ic-tbl-filter__header">
    <span class="ic-tbl-filter__title">Filter: {column.header}</span>
    <button class="ic-tbl-filter__clear" onclick={handleClear}>Clear</button>
  </div>

  <div class="ic-tbl-filter__body">
    {#if column.type === 'number'}
      <div class="ic-tbl-filter__range">
        <label>
          Min
          <input
            type="number"
            class="ic-tbl-filter__input"
            bind:value={numMin}
            oninput={emitChange}
            placeholder="—"
          />
        </label>
        <label>
          Max
          <input
            type="number"
            class="ic-tbl-filter__input"
            bind:value={numMax}
            oninput={emitChange}
            placeholder="—"
          />
        </label>
      </div>
    {:else if column.type === 'badge'}
      <div class="ic-tbl-filter__badges">
        {#each uniqueValues as val}
          <label class="ic-tbl-filter__check">
            <input
              type="checkbox"
              checked={badgeSelected.includes(val)}
              onchange={() => toggleBadge(val)}
            />
            <span>{val}</span>
          </label>
        {/each}
        {#if uniqueValues.length === 0}
          <span class="ic-tbl-filter__empty">No values</span>
        {/if}
      </div>
    {:else if column.type === 'boolean'}
      <button class="ic-tbl-filter__bool" onclick={cycleBool}>
        {boolValue === null ? 'All' : boolValue ? 'True' : 'False'}
      </button>
    {:else}
      <input
        type="text"
        class="ic-tbl-filter__input ic-tbl-filter__input--full"
        bind:value={textValue}
        oninput={emitChange}
        placeholder="Search..."
      />
    {/if}
  </div>
</div>

<style>
  .ic-tbl-filter {
    position: absolute;
    top: calc(100% + 2px);
    right: 0;
    z-index: 50;
    min-width: 180px;
    max-width: 260px;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    font-size: 0.8rem;
  }

  .ic-tbl-filter__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 8px;
    border-bottom: 1px solid var(--ic-border);
  }
  .ic-tbl-filter__title {
    font-weight: 500;
    font-size: 0.75rem;
    color: var(--ic-muted-foreground);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ic-tbl-filter__clear {
    background: none;
    border: none;
    color: var(--ic-primary);
    cursor: pointer;
    font-size: 0.7rem;
    padding: 0;
    white-space: nowrap;
  }
  .ic-tbl-filter__clear:hover { text-decoration: underline; }

  .ic-tbl-filter__body {
    padding: 6px 8px 8px;
  }

  .ic-tbl-filter__input {
    width: 100%;
    padding: 4px 6px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    color: var(--ic-foreground);
    font: inherit;
    font-size: 0.8rem;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    box-sizing: border-box;
  }
  .ic-tbl-filter__input:focus {
    outline: none;
    border-color: var(--ic-primary);
  }
  .ic-tbl-filter__input--full {
    width: 100%;
  }

  .ic-tbl-filter__range {
    display: flex;
    gap: 6px;
  }
  .ic-tbl-filter__range label {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 0.7rem;
    color: var(--ic-muted-foreground);
  }

  .ic-tbl-filter__badges {
    max-height: 160px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .ic-tbl-filter__check {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 2px 0;
    cursor: pointer;
    font-size: 0.8rem;
  }
  .ic-tbl-filter__check input {
    accent-color: var(--ic-primary);
  }
  .ic-tbl-filter__empty {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    font-size: 0.75rem;
  }

  .ic-tbl-filter__bool {
    width: 100%;
    padding: 4px 8px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-secondary);
    color: var(--ic-foreground);
    cursor: pointer;
    font: inherit;
    font-size: 0.8rem;
    text-align: center;
  }
  .ic-tbl-filter__bool:hover {
    background: var(--ic-muted);
  }
</style>
