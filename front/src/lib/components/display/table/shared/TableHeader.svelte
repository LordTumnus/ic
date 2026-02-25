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
    stickingFields = new Set<string>(),
    selectable = false,
    activeColumns = [] as string[],
    disabled = false,
    totalRowCount = 0,
    filterMatchCounts = {} as Record<string, number>,
    onsort,
    onfilterchange,
    oncolumnclick,
    oncolumnresized,
  }: {
    columns: TableColumn[];
    columnWidths?: number[];
    sortField?: string;
    sortDirection?: 'none' | 'asc' | 'desc';
    filters?: FilterState;
    showRowNumber?: boolean;
    rowNumWidth?: number;
    pinnedOffsets?: Map<string, PinnedInfo>;
    stickingFields?: Set<string>;
    selectable?: boolean;
    activeColumns?: string[];
    disabled?: boolean;
    totalRowCount?: number;
    filterMatchCounts?: Record<string, number>;
    onsort?: (field: string, direction: 'none' | 'asc' | 'desc') => void;
    onfilterchange?: (field: string, value: unknown) => void;
    oncolumnclick?: (field: string, shiftKey: boolean) => void;
    oncolumnresized?: (field: string, width: number) => void;
  } = $props();

  let openFilterField = $state<string | null>(null);
  let hoveredSortCol = $state<string | null>(null);

  // SVG for sort arrows (6×6) and clear icon
  const SORT_UP = '<svg width="6" height="6" viewBox="0 0 8 8"><path d="M4 1L7 5H1Z" fill="currentColor"/></svg>';
  const SORT_DOWN = '<svg width="6" height="6" viewBox="0 0 8 8"><path d="M4 7L1 3H7Z" fill="currentColor"/></svg>';
  const SORT_CLEAR = '<svg width="6" height="6" viewBox="0 0 8 8"><path d="M2 2L6 6M6 2L2 6" stroke="currentColor" stroke-width="1.5" fill="none"/></svg>';
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
    // Safety net — popover's own onkeydown stops propagation, but guard just in case
    if ((e.target as Element).closest?.('.ic-tbl-filter')) return;

    switch (e.key) {
      case 'ArrowLeft':
      case 'ArrowRight': {
        e.preventDefault();
        const headerEl = (e.currentTarget as HTMLElement).parentElement;
        if (!headerEl) break;
        const cells = [...headerEl.querySelectorAll<HTMLElement>('.ic-tbl__hcell:not(.ic-tbl__hcell--rownum)')];
        const idx = cells.indexOf(e.currentTarget as HTMLElement);
        if (e.key === 'ArrowLeft') {
          if (idx > 0) {
            cells[idx - 1]?.focus();
          } else if (showRowNumber) {
            // First header → go to row-number header
            const rn = headerEl.querySelector('.ic-tbl__hcell--rownum') as HTMLElement | null;
            rn?.focus();
          }
        } else {
          cells[idx + 1]?.focus();
        }
        break;
      }
      case 'ArrowDown': {
        e.preventDefault();
        const table = (e.currentTarget as HTMLElement).closest('.ic-tbl');
        const firstRow = table?.querySelector('.ic-tbl__body .ic-tbl__row');
        if (firstRow) {
          // Focus the data cell at the same column index
          const hcells = [...(e.currentTarget as HTMLElement).parentElement!.querySelectorAll<HTMLElement>('.ic-tbl__hcell:not(.ic-tbl__hcell--rownum)')];
          const colIdx = hcells.indexOf(e.currentTarget as HTMLElement);
          const cell = firstRow.querySelectorAll<HTMLElement>(':scope > .ic-tbl__cell:not(.ic-tbl__cell--rownum)')[colIdx];
          cell?.focus();
        }
        break;
      }
      case 'Enter': {
        e.preventDefault();
        if (selectable) oncolumnclick?.(col.field, e.shiftKey);
        break;
      }
      case 's':
      case 'S': {
        if (col.sortable) {
          e.preventDefault();
          const newDir = col.field === sortField ? cycleSortDirection(sortDirection) : 'asc';
          onsort?.(col.field, newDir);
        }
        break;
      }
      case 'f':
      case 'F': {
        if (col.filterable) {
          e.preventDefault();
          openFilterField = openFilterField === col.field ? null : col.field;
        }
        break;
      }
    }
  }

  function handleResize(index: number, delta: number) {
    const current = columnWidths[index] ?? 150;
    const newWidth = Math.max(MIN_RESIZE_WIDTH, current + delta);
    columnWidths[index] = newWidth;
  }

  function handleRowNumHeaderKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'ArrowDown': {
        e.preventDefault();
        const table = (e.currentTarget as HTMLElement).closest('.ic-tbl');
        const firstRowNum = table?.querySelector('.ic-tbl__body .ic-tbl__row .ic-tbl__cell--rownum') as HTMLElement | null;
        firstRowNum?.focus();
        break;
      }
      case 'ArrowRight': {
        e.preventDefault();
        const header = (e.currentTarget as HTMLElement).parentElement;
        const firstHcell = header?.querySelector('.ic-tbl__hcell:not(.ic-tbl__hcell--rownum)') as HTMLElement | null;
        firstHcell?.focus();
        break;
      }
    }
  }
</script>

<div class="ic-tbl__header" class:ic-tbl__header--disabled={disabled}>
  {#if showRowNumber}
    <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
    <div
      class="ic-tbl__hcell ic-tbl__hcell--rownum"
      class:ic-tbl__hcell--sticking={stickingFields.has('__rownum__')}
      style:flex="0 0 {rowNumWidth}px"
      style:width="{rowNumWidth}px"
      style:position="sticky"
      style:left="0px"
      style:z-index={5}
      role="columnheader"
      tabindex={-1}
      onkeydown={handleRowNumHeaderKeydown}
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
      class:ic-tbl__hcell--pinned-right={pinInfo?.side === 'right'}
      class:ic-tbl__hcell--sticking={pinInfo != null && stickingFields.has(col.field)}
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
      data-field={col.field}
      role="columnheader"
      tabindex={-1}
      onclick={(e: MouseEvent) => handleHeaderClick(e, col)}
      onkeydown={(e: KeyboardEvent) => handleHeaderKeydown(e, col)}
    >
      <span class="ic-tbl__hcell-label">{col.header}</span>

      {#if col.sortable || col.filterable}
        <div class="ic-tbl__hcell-actions">
          {#if col.sortable}
            {@const isHovering = hoveredSortCol === col.field}
            <button
              class="ic-tbl__sort-btn"
              class:ic-tbl__sort-btn--active={isSorted}
              onclick={(e: MouseEvent) => handleSortClick(e, col)}
              onpointerenter={() => { hoveredSortCol = col.field; }}
              onpointerleave={() => { if (hoveredSortCol === col.field) hoveredSortCol = null; }}
              tabindex={-1}
              aria-label="Sort {col.header}"
            >
              {#if isHovering}
                {#if isSorted && sortDirection === 'asc'}
                  {@html SORT_DOWN}
                {:else if isSorted && sortDirection === 'desc'}
                  {@html SORT_CLEAR}
                {:else}
                  {@html SORT_UP}
                {/if}
              {:else}
                {#if isSorted && sortDirection === 'asc'}
                  {@html SORT_UP}
                {:else if isSorted && sortDirection === 'desc'}
                  {@html SORT_DOWN}
                {:else}
                  {@html SORT_UP}
                {/if}
              {/if}
            </button>
          {/if}
          {#if col.filterable}
            <button
              class="ic-tbl__filter-btn"
              class:ic-tbl__filter-btn--active={hasActiveFilter}
              class:ic-tbl__filter-btn--open={openFilterField === col.field}
              onclick={(e: MouseEvent) => handleFilterClick(e, col.field)}
              tabindex={-1}
              aria-label="Filter {col.header}"
            >
              {@html FILTER_ICON}
            </button>
          {/if}
        </div>
      {/if}

      {#if col.resizable !== false}
        <ResizeHandle
          onresize={(delta) => handleResize(i, delta)}
          onresizeend={() => oncolumnresized?.(col.field, columnWidths[i])}
        />
      {/if}

      {#if openFilterField === col.field}
        <ColumnFilterPopover
          column={col}
          filterValue={filters[col.field] ?? null}
          {totalRowCount}
          matchCount={filterMatchCounts[col.field]}
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
    transition: background-color 0.12s ease;
  }
  /* Pinned header cell — always opaque so scrolling content doesn't bleed through */
  .ic-tbl__hcell--pinned {
    background: var(--ic-secondary);
  }
  /* Sticking — directional shadow when sticky position is active */
  .ic-tbl__hcell--sticking {
    box-shadow: 2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__hcell--sticking.ic-tbl__hcell--pinned-right {
    box-shadow: -2px 0 4px rgba(0, 0, 0, 0.06);
  }
  .ic-tbl__hcell:focus {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
  }
  .ic-tbl__hcell--selectable {
    cursor: pointer;
  }
  .ic-tbl__hcell--selectable:hover {
    background: rgba(0, 0, 0, 0.05);
  }
  .ic-tbl__hcell--pinned.ic-tbl__hcell--selectable:hover {
    background: linear-gradient(rgba(0, 0, 0, 0.05), rgba(0, 0, 0, 0.05)), var(--ic-secondary);
  }
  .ic-tbl__hcell--active {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    box-shadow: none;
  }
  .ic-tbl__hcell--active.ic-tbl__hcell--selectable:hover {
    background: var(--ic-primary);
    color: var(--ic-primary-foreground);
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.15);
  }
  .ic-tbl__hcell--pinned.ic-tbl__hcell--active {
    background: var(--ic-primary);
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
  /* When header is selected, make icons visible on primary bg */
  .ic-tbl__hcell--active .ic-tbl__sort-btn,
  .ic-tbl__hcell--active .ic-tbl__filter-btn {
    color: var(--ic-primary-foreground);
    opacity: 0.7;
  }
  .ic-tbl__hcell--active .ic-tbl__sort-btn--active,
  .ic-tbl__hcell--active .ic-tbl__filter-btn--active {
    opacity: 1;
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
  .ic-tbl__hcell--rownum:focus {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
    box-shadow: inset 0 0 0 1px var(--ic-primary);
  }
</style>
