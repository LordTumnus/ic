<script lang="ts">
  import { untrack } from 'svelte';
  import type { TableColumn, NumberFilterValue } from '$lib/utils/table-utils';
  import Select from '$lib/components/form/select/Select.svelte';

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

  type FilterMode = 'default' | 'isEmpty' | 'isNotEmpty';

  function detectMode(val: unknown): FilterMode {
    if (val && typeof val === 'object' && !Array.isArray(val)) {
      const obj = val as Record<string, unknown>;
      if ('isEmpty' in obj) return 'isEmpty';
      if ('isNotEmpty' in obj) return 'isNotEmpty';
    }
    return 'default';
  }

  // Seed local state from prop — one-time capture is correct since
  // the popover is destroyed/recreated each time it opens
  const init = untrack(() => filterValue);
  const initMode = detectMode(init);

  let filterMode = $state<FilterMode>(initMode);
  let textValue = $state(initMode === 'default' ? ((init as string) ?? '') : '');
  let numMin = $state(initMode === 'default' ? ((init as NumberFilterValue)?.min ?? null) : null);
  let numMax = $state(initMode === 'default' ? ((init as NumberFilterValue)?.max ?? null) : null);
  let badgeSelected = $state<string[]>(Array.isArray(init) ? init : []);
  let boolValue = $state<boolean | null>(init as boolean | null);

  // Flip state for overflow positioning
  let flipX = $state(false);
  let flipY = $state(false);

  // Mode label mapping for the Select component
  const modeItems = $derived(column.type === 'number'
    ? ['Range', 'Is empty', 'Is not empty']
    : ['Contains', 'Is empty', 'Is not empty']);

  function modeToLabel(mode: FilterMode): string {
    if (mode === 'isEmpty') return 'Is empty';
    if (mode === 'isNotEmpty') return 'Is not empty';
    return column.type === 'number' ? 'Range' : 'Contains';
  }

  function labelToMode(label: string | null): FilterMode {
    if (label === 'Is empty') return 'isEmpty';
    if (label === 'Is not empty') return 'isNotEmpty';
    return 'default';
  }

  const modeLabel = $derived(modeToLabel(filterMode));

  function emitChange() {
    // isEmpty / isNotEmpty modes (text + number types)
    if (filterMode === 'isEmpty') {
      onchange?.(column.field, { isEmpty: true });
      return;
    }
    if (filterMode === 'isNotEmpty') {
      onchange?.(column.field, { isNotEmpty: true });
      return;
    }

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
    filterMode = 'default';
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
      // If a nested Select dropdown is open, let it close first
      const openSelect = popoverEl?.querySelector('.ic-select--open');
      if (openSelect) {
        e.stopPropagation();
        return;
      }
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

  // Auto-focus the best interactive element when the popover opens or mode changes
  $effect(() => {
    if (!popoverEl) return;
    const _mode = filterMode; // track mode changes to re-focus
    const body = popoverEl.querySelector('.ic-tbl-filter__body');
    if (!body) return;
    // Priority: text/number input > checkbox > Select combobox > boolean button
    const input = body.querySelector('input') as HTMLElement | null;
    const sel = body.querySelector('[role="combobox"]') as HTMLElement | null;
    const btn = body.querySelector('button.ic-tbl-filter__bool') as HTMLElement | null;
    (input || sel || btn)?.focus();
  });

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

    // Vertical: flip above if not enough space below and more space above
    const spaceBelow = tableRect.bottom - cellRect.bottom - 2;
    const spaceAbove = cellRect.top - tableRect.top - 2;
    flipY = popRect.height > spaceBelow && spaceAbove > spaceBelow;

    // Horizontal: flip to left-aligned if right-aligned would overflow past table left
    const rightAlignSpace = cellRect.right - tableRect.left;
    const leftAlignSpace = tableRect.right - cellRect.left;
    flipX = popRect.width > rightAlignSpace && leftAlignSpace > rightAlignSpace;
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
<div class="ic-tbl-filter" class:ic-tbl-filter--flip-x={flipX} class:ic-tbl-filter--flip-y={flipY} bind:this={popoverEl} role="dialog" tabindex={-1} onclick={(e: MouseEvent) => e.stopPropagation()} onkeydown={handlePopoverKeydown}>
  <div class="ic-tbl-filter__header">
    <span class="ic-tbl-filter__title">Filter: {column.header}</span>
    <button class="ic-tbl-filter__clear" onclick={handleClear}>Clear</button>
  </div>

  <div class="ic-tbl-filter__body">
    {#if column.type === 'number'}
      <Select
        items={modeItems}
        value={modeLabel}
        size="sm"
        variant="secondary"
        maxPopupHeight={120}
        valueChanged={(data) => {
          filterMode = labelToMode((data as {value: string | null})?.value ?? null);
          emitChange();
        }}
      />
      {#if filterMode === 'default'}
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
      {/if}
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
      <Select
        items={modeItems}
        value={modeLabel}
        size="sm"
        variant="secondary"
        maxPopupHeight={120}
        valueChanged={(data) => {
          filterMode = labelToMode((data as {value: string | null})?.value ?? null);
          emitChange();
        }}
      />
      {#if filterMode === 'default'}
        <input
          type="text"
          class="ic-tbl-filter__input ic-tbl-filter__input--full"
          bind:value={textValue}
          oninput={emitChange}
          placeholder="Search..."
        />
      {/if}
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

  .ic-tbl-filter__body :global(.ic-select) {
    margin-bottom: 6px;
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
