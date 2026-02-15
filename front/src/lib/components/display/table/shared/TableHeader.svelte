<script lang="ts">
  import type { TableColumn, FilterState, PinnedInfo } from '$lib/utils/table-utils';
  import { resolveAlign, cycleSortDirection, MIN_RESIZE_WIDTH } from '$lib/utils/table-utils';
  import ResizeHandle from './ResizeHandle.svelte';
  import ColumnFilterPopover from './ColumnFilterPopover.svelte';

  let {
    columns,
    columnWidths = $bindable([]),
    sortField = '',
    sortDirection = 'none' as 'none' | 'asc' | 'desc',
    filters = {} as FilterState,
    showRowNumber = false,
    rowNumWidth = 24,
    pinnedOffsets = new Map() as Map<string, PinnedInfo>,
    selectable = false,
    activeColumns = [] as string[],
    disabled = false,
    uniqueValuesMap = {} as Record<string, string[]>,
    onsort,
    onfilterchange,
    oncolumnclick,
  }: {
    columns: TableColumn[];
    columnWidths?: number[];
    sortField?: string;
    sortDirection?: 'none' | 'asc' | 'desc';
    filters?: FilterState;
    showRowNumber?: boolean;
    rowNumWidth?: number;
    pinnedOffsets?: Map<string, PinnedInfo>;
    selectable?: boolean;
    activeColumns?: string[];
    disabled?: boolean;
    uniqueValuesMap?: Record<string, string[]>;
    onsort?: (field: string, direction: 'none' | 'asc' | 'desc') => void;
    onfilterchange?: (field: string, value: unknown) => void;
    oncolumnclick?: (field: string, shiftKey: boolean) => void;
  } = $props();

  let openFilterField = $state<string | null>(null);

  // SVG for sort arrows (6×6)
  const SORT_UP = '<svg width="6" height="6" viewBox="0 0 8 8"><path d="M4 1L7 5H1Z" fill="currentColor"/></svg>';
  const SORT_DOWN = '<svg width="6" height="6" viewBox="0 0 8 8"><path d="M4 7L1 3H7Z" fill="currentColor"/></svg>';
  // Filled funnel SVG (7×7)
  const FILTER_ICON = '<svg width="7" height="7" viewBox="0 0 10 10"><path d="M0 1h10L6.2 5.5V9L3.8 8V5.5Z" fill="currentColor"/></svg>';

  function handleHeaderClick(e: MouseEvent, col: TableColumn) {
    oncolumnclick?.(col.field, e.shiftKey);
  }

  function handleSortClick(e: MouseEvent, col: TableColumn) {
    e.stopPropagation();
    const newDir = col.field === sortField
      ? cycleSortDirection(sortDirection)
      : 'asc';
    onsort?.(col.field, newDir);
  }

  function handleFilterClick(e: MouseEvent, field: string) {
    e.stopPropagation();
    openFilterField = openFilterField === field ? null : field;
  }

  function handleFilterChange(field: string, value: unknown) {
    onfilterchange?.(field, value);
  }

  function handleFilterClose() {
    openFilterField = null;
  }

  function handleHeaderKeydown(e: KeyboardEvent, col: TableColumn) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      oncolumnclick?.(col.field, e.shiftKey);
    }
  }

  function handleResize(index: number, delta: number) {
    const current = columnWidths[index] ?? 150;
    const newWidth = Math.max(MIN_RESIZE_WIDTH, current + delta);
    columnWidths[index] = newWidth;
  }
</script>

<div class="ic-tbl__header" class:ic-tbl__header--disabled={disabled}>
  {#if showRowNumber}
    <div
      class="ic-tbl__hcell ic-tbl__hcell--rownum ic-tbl__hcell--pinned"
      style:flex="0 0 {rowNumWidth}px"
      style:width="{rowNumWidth}px"
      style:position="sticky"
      style:left="0px"
      style:z-index={5}
    >
      #
    </div>
  {/if}

  {#each columns as col, i (col.field)}
    {@const isSorted = sortField === col.field && sortDirection !== 'none'}
    {@const align = resolveAlign(col)}
    {@const hasActiveFilter = filters[col.field] != null}
    {@const isActive = activeColumns.includes(col.field)}
    {@const pinInfo = pinnedOffsets.get(col.field)}
    <div
      class="ic-tbl__hcell"
      class:ic-tbl__hcell--sorted={isSorted}
      class:ic-tbl__hcell--active={isActive}
      class:ic-tbl__hcell--selectable={selectable}
      class:ic-tbl__hcell--pinned={pinInfo != null}
      class:ic-tbl__hcell--left={align === 'left'}
      class:ic-tbl__hcell--center={align === 'center'}
      class:ic-tbl__hcell--right={align === 'right'}
      style:width="{columnWidths[i] ? columnWidths[i] + 'px' : 'auto'}"
      style:flex="{columnWidths[i] ? '0 0 ' + columnWidths[i] + 'px' : '1 1 0%'}"
      style:min-width="{col.minWidth || MIN_RESIZE_WIDTH}px"
      style:position={pinInfo ? 'sticky' : undefined}
      style:left={pinInfo?.side === 'left' ? pinInfo.offset + 'px' : undefined}
      style:right={pinInfo?.side === 'right' ? pinInfo.offset + 'px' : undefined}
      style:z-index={pinInfo ? 5 : undefined}
      role="columnheader"
      tabindex={0}
      onclick={(e: MouseEvent) => handleHeaderClick(e, col)}
      onkeydown={(e: KeyboardEvent) => handleHeaderKeydown(e, col)}
    >
      <span class="ic-tbl__hcell-label">{col.header}</span>

      {#if col.sortable || col.filterable}
        <div class="ic-tbl__hcell-actions">
          {#if col.sortable}
            <button
              class="ic-tbl__sort-btn"
              class:ic-tbl__sort-btn--active={isSorted}
              onclick={(e: MouseEvent) => handleSortClick(e, col)}
              aria-label="Sort {col.header}"
            >
              {#if isSorted && sortDirection === 'desc'}
                {@html SORT_DOWN}
              {:else}
                {@html SORT_UP}
              {/if}
            </button>
          {/if}
          {#if col.filterable}
            <button
              class="ic-tbl__filter-btn"
              class:ic-tbl__filter-btn--active={hasActiveFilter}
              class:ic-tbl__filter-btn--open={openFilterField === col.field}
              onclick={(e: MouseEvent) => handleFilterClick(e, col.field)}
              aria-label="Filter {col.header}"
            >
              {@html FILTER_ICON}
            </button>
          {/if}
        </div>
      {/if}

      {#if col.resizable !== false}
        <ResizeHandle onresize={(delta) => handleResize(i, delta)} />
      {/if}

      {#if openFilterField === col.field}
        <ColumnFilterPopover
          column={col}
          filterValue={filters[col.field] ?? null}
          uniqueValues={uniqueValuesMap[col.field] ?? []}
          onchange={handleFilterChange}
          onclose={handleFilterClose}
        />
      {/if}
    </div>
  {/each}
</div>

<style>
  .ic-tbl__header {
    display: flex;
    position: sticky;
    top: 0;
    z-index: 4;
    background: var(--ic-secondary);
    box-shadow: inset 0 -1px 0 var(--ic-border), inset 0 -2px 4px rgba(0, 0, 0, 0.04);
    font-weight: 600;
    font-size: 0.75em;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    user-select: none;
  }
  .ic-tbl__header--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-tbl__hcell {
    position: relative;
    display: flex;
    align-items: center;
    gap: 3px;
    padding: 0 6px;
    box-sizing: border-box;
    border: 1px solid transparent;
    transition: border-color 0.12s ease;
  }
  /* Pinned header cell — opaque so scrolling content doesn't bleed through */
  .ic-tbl__hcell--pinned {
    background: var(--ic-secondary);
    box-shadow: 2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__hcell--selectable {
    cursor: pointer;
  }
  .ic-tbl__hcell--selectable:hover {
    background: rgba(0, 0, 0, 0.05);
  }
  .ic-tbl__hcell--active {
    border-color: var(--ic-primary);
    background: rgba(59, 130, 246, 0.06);
  }

  .ic-tbl__hcell--left { justify-content: flex-start; }
  .ic-tbl__hcell--center { justify-content: center; }
  .ic-tbl__hcell--right { justify-content: flex-end; }

  .ic-tbl__hcell-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    min-width: 0;
  }

  /* Vertical actions column (sort + filter stacked) */
  .ic-tbl__hcell-actions {
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0;
    margin-left: 2px;
  }

  /* Sort button */
  .ic-tbl__sort-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0px 1px;
    border-radius: 1px;
    opacity: 0;
    transition: opacity 0.12s ease, color 0.12s ease;
    line-height: 0;
  }
  .ic-tbl__hcell:hover .ic-tbl__sort-btn {
    opacity: 0.4;
  }
  .ic-tbl__sort-btn:hover {
    opacity: 0.8;
    background: rgba(0, 0, 0, 0.08);
  }
  .ic-tbl__sort-btn--active {
    opacity: 1;
    color: var(--ic-primary);
  }

  /* Filter button */
  .ic-tbl__filter-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0px 1px;
    border-radius: 1px;
    opacity: 0.25;
    transition: opacity 0.12s ease, color 0.12s ease;
    line-height: 0;
  }
  .ic-tbl__hcell:hover .ic-tbl__filter-btn {
    opacity: 0.45;
  }
  .ic-tbl__filter-btn:hover {
    opacity: 0.8;
  }
  .ic-tbl__filter-btn--open {
    opacity: 0.8;
    color: var(--ic-foreground);
  }
  /* Filter applied — prominent filled icon */
  .ic-tbl__filter-btn--active {
    opacity: 1;
    color: var(--ic-primary);
  }

  /* Row number gutter — recessed channel */
  .ic-tbl__hcell--rownum {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 2px;
    color: var(--ic-foreground);
    opacity: 0.7;
    font-size: 0.8em;
    font-weight: 600;
    background: var(--ic-secondary);
    border-right: 2px solid var(--ic-border);
    box-shadow: inset -3px 0 6px rgba(0, 0, 0, 0.08);
    cursor: default;
  }
</style>
