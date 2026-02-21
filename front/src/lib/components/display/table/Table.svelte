<script lang="ts">
  import type { Resolution } from '$lib/types';
  import type { TableColumn, TableRow as TRow, FilterState, IndexedRow } from '$lib/utils/table-utils';
  import type { PinnedInfo } from '$lib/utils/table-utils';
  import {
    normalizeTableData,
    computeColumnWidths,
    computePinnedOffsets,
    sortRows,
    filterRows,
    ROW_HEIGHTS,
  } from '$lib/utils/table-utils';
  import logger from '$lib/core/logger';
  import TableHeader from './shared/TableHeader.svelte';
  import TableRowComp from './shared/TableRow.svelte';

  let {
    // Reactive props
    data = $bindable(null as unknown),
    columns = $bindable([] as TableColumn[]),
    disabled = $bindable(false),
    size = $bindable('md'),
    height = $bindable('auto'),
    selectable = $bindable(false),
    showRowNumbers = $bindable(false),
    striped = $bindable(false),
    sortField = $bindable(''),
    sortDirection = $bindable('none' as 'none' | 'asc' | 'desc'),
    value = $bindable(null as number[] | null),
    filters = $bindable({} as FilterState),

    // Events
    valueChanged,
    sortChanged,
    filterChanged,
    cellClicked,
    rowClicked,
    columnClicked,

    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    scrollToRow = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
  }: {
    data?: unknown;
    columns?: TableColumn[];
    disabled?: boolean;
    size?: string;
    height?: string | number;
    selectable?: boolean;
    showRowNumbers?: boolean;
    striped?: boolean;
    sortField?: string;
    sortDirection?: 'none' | 'asc' | 'desc';
    value?: number[] | null;
    filters?: FilterState;
    valueChanged?: (data?: unknown) => void;
    sortChanged?: (data?: unknown) => void;
    filterChanged?: (data?: unknown) => void;
    cellClicked?: (data?: unknown) => void;
    rowClicked?: (data?: unknown) => void;
    columnClicked?: (data?: unknown) => void;
    focus?: () => Resolution;
    clearSelection?: () => Resolution;
    scrollToRow?: (data?: unknown) => Resolution;
  } = $props();

  let containerEl: HTMLDivElement;

  // Active selection state (local UI — not synced to MATLAB)
  let activeColumns = $state<string[]>([]);
  let activeCells = $state<{ field: string; rowIndex: number }[]>([]);

  // Normalize MATLAB data (row-oriented or column-oriented) to rows
  const rows = $derived.by(() => {
    const r = normalizeTableData(data);
    logger.info('Table', 'Data received', { format: Array.isArray(data) ? 'row' : 'column', rows: r.length });
    return r;
  });

  // Wrap rows with original indices so selection survives sort/filter
  const indexedRows: IndexedRow[] = $derived(
    rows.map((data, i) => ({ data, originalIndex: i }))
  );

  // Client-side sort (preserves original indices)
  const sortedRows = $derived(sortRows(indexedRows, sortField, sortDirection));

  // Client-side filter (preserves original indices)
  const filteredRows = $derived(filterRows(sortedRows, filters, columns));

  // Dynamic row number width based on total rows (not filtered — avoids layout shift)
  const rowNumWidth = $derived.by(() => {
    const count = rows.length;
    if (count === 0) return 24;
    const digits = Math.floor(Math.log10(count)) + 1;
    return digits * 8 + 10;
  });

  // Compute column widths
  let columnWidths = $state<number[]>([]);
  $effect(() => {
    if (columns.length > 0 && containerEl) {
      const w = containerEl.clientWidth;
      let reserved = 0;
      if (showRowNumbers) reserved += rowNumWidth;
      columnWidths = computeColumnWidths(columns, w - reserved);
    }
  });

  // Pinned column offsets (row number gutter is always pinned-left when visible)
  const pinnedOffsets = $derived(
    computePinnedOffsets(columns, columnWidths, showRowNumbers ? rowNumWidth : 0)
  );

  // Track horizontal scroll — each pinned column activates its visual treatment
  // only when content is actually scrolling behind it (i.e. it has reached its
  // sticky position). Row number gutter uses the sentinel key '__rownum__'.
  // Both scrollLeft and maxScroll are tracked as reactive state so the derived
  // always uses fresh values (DOM properties aren't reactive on their own).
  let scrollLeft = $state(0);
  let maxScroll = $state(0);
  function handleScroll() {
    scrollLeft = containerEl.scrollLeft;
    maxScroll = containerEl.scrollWidth - containerEl.clientWidth;
  }
  // Also seed maxScroll once layout is known (before any scroll happens)
  $effect(() => {
    if (containerEl && columns.length > 0 && columnWidths.length > 0) {
      maxScroll = containerEl.scrollWidth - containerEl.clientWidth;
    }
  });

  const stickingFields = $derived.by(() => {
    const result = new Set<string>();

    // Nothing is scrollable — no pinned visuals needed
    if (maxScroll <= 0) return result;

    // Row number gutter: sticky left=0, sticks immediately on any scroll
    if (showRowNumbers && scrollLeft > 0) result.add('__rownum__');

    // Left-pinned: sticks when scrollLeft > naturalLeft - stickyOffset
    let naturalLeft = showRowNumbers ? rowNumWidth : 0;
    for (let i = 0; i < columns.length; i++) {
      const col = columns[i];
      const w = columnWidths[i] ?? 0;
      const pinInfo = pinnedOffsets.get(col.field);

      if (pinInfo?.side === 'left' && scrollLeft > naturalLeft - pinInfo.offset) {
        result.add(col.field);
      }

      naturalLeft += w;
    }

    // Right-pinned: sticks when scroll hasn't reached the far right
    if (scrollLeft < maxScroll) {
      let naturalRight = 0;
      for (let i = columns.length - 1; i >= 0; i--) {
        const col = columns[i];
        const w = columnWidths[i] ?? 0;
        const pinInfo = pinnedOffsets.get(col.field);

        if (pinInfo?.side === 'right') {
          const scrollFromRight = maxScroll - scrollLeft;
          if (scrollFromRight > naturalRight - pinInfo.offset) {
            result.add(col.field);
          }
        }

        naturalRight += w;
      }
    }

    return result;
  });

  // Selection
  const selectedSet = $derived(new Set(value ?? []));

  // Height style
  const heightStyle = $derived(
    height === 'auto' ? 'auto' : typeof height === 'number' ? `${height}px` : height
  );

  const rowH = $derived(ROW_HEIGHTS[size as keyof typeof ROW_HEIGHTS] ?? ROW_HEIGHTS.md);

  // Total width for horizontal scroll (only meaningful when all columns have fixed widths)
  const hasAutoColumns = $derived(columnWidths.some(w => w === 0));
  const totalWidth = $derived.by(() => {
    if (hasAutoColumns) return 0; // flex handles it
    let w = columnWidths.reduce((s, v) => s + v, 0);
    if (showRowNumbers) w += rowNumWidth;
    return w;
  });

  // ── Handlers ──────────────────────────────────────────

  function handleSort(field: string, direction: 'none' | 'asc' | 'desc') {
    logger.debug('Table', 'Sort', { field, direction });
    sortField = field;
    sortDirection = direction;
    sortChanged?.({ field, direction });
  }

  function handleFilterChange(field: string, val: unknown) {
    logger.debug('Table', 'Filter change', { field, value: val });
    if (val == null) {
      const { [field]: _, ...rest } = filters;
      filters = rest;
    } else {
      filters = { ...filters, [field]: val };
    }
    filterChanged?.({ field, value: val, filters });
  }

  function handleRowClick(rowIndex: number, rowData: TRow) {
    logger.debug('Table', 'Row click', { rowIndex });
    if (selectable) {
      activeColumns = [];
      activeCells = [];
      if (value != null) {
        value = null;
        valueChanged?.({ value: null });
      }
    }
    rowClicked?.({ rowIndex, rowData });
  }

  function handleCellClick(field: string, rowIndex: number, val: unknown, rowData: TRow, shiftKey: boolean) {
    logger.debug('Table', 'Cell click', { field, rowIndex, shiftKey });
    if (selectable) {
      activeColumns = [];
      if (value != null) {
        value = null;
        valueChanged?.({ value: null });
      }
      const exists = activeCells.some(c => c.field === field && c.rowIndex === rowIndex);
      if (shiftKey) {
        if (exists) {
          activeCells = activeCells.filter(c => !(c.field === field && c.rowIndex === rowIndex));
        } else {
          activeCells = [...activeCells, { field, rowIndex }];
        }
      } else {
        activeCells = exists ? [] : [{ field, rowIndex }];
      }
      logger.debug('Table', 'Active cells', { count: activeCells.length, cells: activeCells });
    }
    cellClicked?.({ field, rowIndex, value: val, rowData });
  }

  function handleColumnClick(field: string, shiftKey: boolean) {
    logger.debug('Table', 'Column click', { field, shiftKey });
    if (selectable) {
      activeCells = [];
      if (value != null) {
        value = null;
        valueChanged?.({ value: null });
      }
      const exists = activeColumns.includes(field);
      if (shiftKey) {
        activeColumns = exists
          ? activeColumns.filter(f => f !== field)
          : [...activeColumns, field];
      } else {
        activeColumns = exists ? [] : [field];
      }
      logger.debug('Table', 'Active columns', { columns: activeColumns });
    }
    const col = columns.find(c => c.field === field);
    columnClicked?.({ field, column: col });
  }

  function handleRowNumClick(rowIndex: number, shiftKey: boolean) {
    if (!selectable) return;
    logger.debug('Table', 'Row num click', { rowIndex, shiftKey });
    activeColumns = [];
    activeCells = [];

    let newValue: number[];
    if (shiftKey) {
      if (selectedSet.has(rowIndex)) {
        newValue = (value ?? []).filter(i => i !== rowIndex);
      } else {
        newValue = [...(value ?? []), rowIndex];
      }
    } else {
      newValue = selectedSet.has(rowIndex) ? [] : [rowIndex];
    }
    value = newValue.length > 0 ? newValue : null;
    logger.debug('Table', 'Selection', { value });
    valueChanged?.({ value });
  }

  // ── Container keydown — entry/exit the grid ──────────
  function handleContainerKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && e.target !== containerEl) {
      logger.debug('Table', 'Escape → exit grid, clear selection');
      e.preventDefault();
      activeColumns = [];
      activeCells = [];
      if (value != null) {
        value = null;
        valueChanged?.({ value: null });
      }
      containerEl.focus();
      return;
    }
    if (e.target !== containerEl) return;
    if (e.key === 'ArrowDown' || e.key === 'ArrowRight' || e.key === 'Enter') {
      logger.debug('Table', 'Enter grid', { key: e.key });
      e.preventDefault();
      const firstHeader = containerEl.querySelector('.ic-tbl__hcell:not(.ic-tbl__hcell--rownum)') as HTMLElement | null;
      firstHeader?.focus();
    }
  }

  // ── Methods ───────────────────────────────────────────

  $effect(() => {
    focus = (): Resolution => {
      containerEl?.focus();
      return { success: true, data: null };
    };
    clearSelection = (): Resolution => {
      value = null;
      activeColumns = [];
      activeCells = [];
      valueChanged?.({ value: null });
      return { success: true, data: null };
    };
    scrollToRow = (payload?: unknown): Resolution => {
      const key = (payload as { key?: number })?.key;
      if (key != null && containerEl) {
        const top = key * rowH;
        containerEl.scrollTop = top;
      }
      return { success: true, data: null };
    };
  });
</script>

<div
  bind:this={containerEl}
  class="ic-tbl"
  class:ic-tbl--sm={size === 'sm'}
  class:ic-tbl--md={size === 'md'}
  class:ic-tbl--lg={size === 'lg'}
  class:ic-tbl--disabled={disabled}
  style:height={heightStyle}
  onscroll={handleScroll}
  onkeydown={handleContainerKeydown}
  tabindex={0}
  role="grid"
>
  <div class="ic-tbl__inner" style:min-width="{totalWidth ? totalWidth + 'px' : '100%'}">
    <TableHeader
      {columns}
      bind:columnWidths
      {sortField}
      {sortDirection}
      {filters}
      showRowNumber={showRowNumbers}
      {rowNumWidth}
      {pinnedOffsets}
      {stickingFields}
      {selectable}
      {activeColumns}
      {disabled}
      onsort={handleSort}
      onfilterchange={handleFilterChange}
      oncolumnclick={handleColumnClick}
    />

    <div class="ic-tbl__body">
      {#each filteredRows as irow, i (irow.originalIndex)}
        <TableRowComp
          {columns}
          {columnWidths}
          rowData={irow.data}
          rowIndex={irow.originalIndex}
          selected={selectedSet.has(irow.originalIndex)}
          {disabled}
          {selectable}
          showRowNumber={showRowNumbers}
          {rowNumWidth}
          {pinnedOffsets}
          {stickingFields}
          {striped}
          even={i % 2 === 1}
          {activeColumns}
          {activeCells}
          onclick={handleRowClick}
          oncellclick={handleCellClick}
          onrownumclick={handleRowNumClick}
        />
      {:else}
        <div class="ic-tbl__empty">{rows.length > 0 ? 'No matching rows' : 'No data'}</div>
      {/each}
    </div>
  </div>
</div>

<style>
  .ic-tbl {
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: auto;
    background: var(--ic-background);
    width: 100%;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.02);
  }

  .ic-tbl__inner {
    display: flex;
    flex-direction: column;
  }

  .ic-tbl:focus {
    outline: none;
    border-color: var(--ic-primary);
  }

  .ic-tbl--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Size row heights — compact industrial density */
  .ic-tbl--sm :global(.ic-tbl__row),
  .ic-tbl--sm :global(.ic-tbl__header) {
    min-height: 24px;
    font-size: 0.7rem;
  }
  .ic-tbl--md :global(.ic-tbl__row),
  .ic-tbl--md :global(.ic-tbl__header) {
    min-height: 28px;
    font-size: 0.75rem;
  }
  .ic-tbl--lg :global(.ic-tbl__row),
  .ic-tbl--lg :global(.ic-tbl__header) {
    min-height: 36px;
    font-size: 0.8125rem;
  }

  .ic-tbl__empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    font-size: 0.75rem;
  }
</style>
