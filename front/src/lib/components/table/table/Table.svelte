<script lang="ts">
  import { onMount } from 'svelte';
  import type { PublishFn, Resolution } from '$lib/types';
  import type { TableColumn, TableRow as TRow, FilterState, IndexedRow, CellActionPayload } from '$lib/utils/table-utils';
  import type { PinnedInfo, CellSelection, SelectionState, EditingCell } from '$lib/utils/table-utils';
  import {
    normalizeTableData,
    computeColumnWidths,
    computePinnedOffsets,
    sortRows,
    filterRows,
    ROW_HEIGHTS,
    isColumnEditable,
  } from '$lib/utils/table-utils';
  import logger from '$lib/core/logger';
  import { filterMatchers } from './cells/filter-matchers';
  import { sortComparators } from './cells/sort-comparators';
  import TableHeader from './shared/TableHeader.svelte';
  import TableRowComp from './shared/TableRow.svelte';

  const NONE_SEL: SelectionState = { type: 'none', value: null };

  let {
    id = '',
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
    selection = $bindable(NONE_SEL as SelectionState),
    filters = $bindable({} as FilterState),

    // IC pub/sub
    publish,

    // Events
    selectionChanged,
    sortChanged,
    filterChanged,
    cellClicked,
    rowClicked,
    columnClicked,
    contextMenuAction,

    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    scrollToRow = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
    removeRow = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
    removeColumn = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
    editCell = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
    focusCell = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
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
    selection?: SelectionState;
    filters?: FilterState;
    publish?: PublishFn;
    selectionChanged?: (data?: unknown) => void;
    sortChanged?: (data?: unknown) => void;
    filterChanged?: (data?: unknown) => void;
    cellClicked?: (data?: unknown) => void;
    rowClicked?: (data?: unknown) => void;
    columnClicked?: (data?: unknown) => void;
    contextMenuAction?: (data?: unknown) => void;
    focus?: () => Resolution;
    clearSelection?: () => Resolution;
    scrollToRow?: (data?: unknown) => Resolution;
    removeRow?: (data?: unknown) => Resolution;
    removeColumn?: (data?: unknown) => Resolution;
    editCell?: (data?: unknown) => Resolution;
    focusCell?: (data?: unknown) => Resolution;
  } = $props();

  let containerEl: HTMLDivElement;

  // Filter out hidden columns — visible !== false (default true when omitted)
  const visibleColumns = $derived(columns.filter(c => c.visible !== false));

  // Normalize MATLAB data — local state so incremental methods can mutate directly
  let rows = $state<TRow[]>([]);
  $effect(() => {
    const r = normalizeTableData(data);
    logger.info('Table', 'Data received', { format: Array.isArray(data) ? 'row' : 'column', rows: r.length });
    rows = r;
  });

  // ── Derived visual state from unified selection ─────

  /** 0-based row indices for row-highlight (row selection mode only). */
  const selectedRowSet = $derived(
    selection.type === 'row'
      ? new Set((selection.value as number[]).map(i => i - 1))
      : new Set<number>()
  );

  /** Active cells for cell-highlight (cell selection mode only). 0-based rowIndex. */
  const activeCellsList = $derived(
    selection.type === 'cell'
      ? (selection.value as CellSelection[]).map(c => ({ field: c.field, rowIndex: c.row - 1 }))
      : []
  );

  /** Active column fields for column-highlight (column selection mode only). */
  const activeColumnsList = $derived(
    selection.type === 'column' ? (selection.value as string[]) : []
  );

  // Wrap rows with original indices so selection survives sort/filter
  const indexedRows: IndexedRow[] = $derived(
    rows.map((data, i) => ({ data, originalIndex: i }))
  );

  // Client-side sort (preserves original indices)
  const sortedRows = $derived(sortRows(indexedRows, sortField, sortDirection, columns, sortComparators));

  // Client-side filter + per-column match counts (single pass)
  const filterResult = $derived(filterRows(sortedRows, filters, columns, filterMatchers));
  const filteredRows = $derived(filterResult.rows);
  const filterMatchCounts = $derived(filterResult.matchCounts);

  // Dynamic row number width based on total rows (not filtered — avoids layout shift)
  const rowNumWidth = $derived.by(() => {
    const count = rows.length;
    if (count === 0) return 24;
    const digits = Math.floor(Math.log10(count)) + 1;
    return digits * 8 + 10;
  });

  // Compute column widths (visible columns only)
  let columnWidths = $state<number[]>([]);
  $effect(() => {
    if (visibleColumns.length > 0 && containerEl) {
      const w = containerEl.clientWidth;
      let reserved = 0;
      if (showRowNumbers) reserved += rowNumWidth;
      columnWidths = computeColumnWidths(visibleColumns, w - reserved);
    }
  });

  // Pinned column offsets (row number gutter is always pinned-left when visible)
  const pinnedOffsets = $derived(
    computePinnedOffsets(visibleColumns, columnWidths, showRowNumbers ? rowNumWidth : 0)
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
    if (containerEl && visibleColumns.length > 0 && columnWidths.length > 0) {
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
    for (let i = 0; i < visibleColumns.length; i++) {
      const col = visibleColumns[i];
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
      for (let i = visibleColumns.length - 1; i >= 0; i--) {
        const col = visibleColumns[i];
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

  function handleColumnResized(field: string, width: number) {
    logger.debug('Table', 'Column resized', { field, width: Math.round(width) });
    publish?.('columnResized', { field, width: Math.round(width) });
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
    if (selectable && selection.type !== 'none') {
      selection = NONE_SEL;
      selectionChanged?.({ selection });
    }
    rowClicked?.({ rowIndex: rowIndex + 1, rowData });
  }

  function handleCellClick(field: string, rowIndex: number, val: unknown, rowData: TRow, shiftKey: boolean) {
    logger.debug('Table', 'Cell click', { field, rowIndex, shiftKey });

    // Editable boolean: toggle on single click (no double-click needed)
    const clickedCol = columns.find(c => c.field === field);
    if (clickedCol && isColumnEditable(clickedCol) && clickedCol.type === 'boolean' && !disabled) {
      commitEdit(field, rowIndex, val, !Boolean(val));
      return;
    }

    if (selectable) {
      const oneBasedRow = rowIndex + 1;
      const currentCells = selection.type === 'cell' ? (selection.value as CellSelection[]) : [];
      const exists = currentCells.some(c => c.field === field && c.row === oneBasedRow);

      let nextCells: CellSelection[];
      if (shiftKey) {
        nextCells = exists
          ? currentCells.filter(c => !(c.field === field && c.row === oneBasedRow))
          : [...currentCells, { row: oneBasedRow, field }];
      } else {
        nextCells = exists ? [] : [{ row: oneBasedRow, field }];
      }

      selection = nextCells.length > 0
        ? { type: 'cell', value: nextCells }
        : NONE_SEL;
      selectionChanged?.({ selection });
      logger.debug('Table', 'Selection', { selection });
    }
    cellClicked?.({ field, rowIndex: rowIndex + 1, value: val, rowData });
  }

  function handleCellAction(field: string, rowIndex: number, data: unknown) {
    logger.debug('Table', 'Cell action', { field, rowIndex });
    publish?.('cellAction', { field, rowIndex, data } satisfies CellActionPayload);
  }

  function handleContextMenuAction(field: string, rowIndex: number, itemKey: string) {
    logger.debug('Table', 'Context menu action', { field, rowIndex, itemKey });
    contextMenuAction?.({ item: itemKey, field, rowIndex: rowIndex + 1 });
  }

  function handleColumnClick(field: string, shiftKey: boolean) {
    logger.debug('Table', 'Column click', { field, shiftKey });
    if (selectable) {
      const currentCols = selection.type === 'column' ? (selection.value as string[]) : [];
      const exists = currentCols.includes(field);

      let nextCols: string[];
      if (shiftKey) {
        nextCols = exists
          ? currentCols.filter(f => f !== field)
          : [...currentCols, field];
      } else {
        nextCols = exists ? [] : [field];
      }

      selection = nextCols.length > 0
        ? { type: 'column', value: nextCols }
        : NONE_SEL;
      selectionChanged?.({ selection });
      logger.debug('Table', 'Selection', { selection });
    }
    const col = columns.find(c => c.field === field);
    columnClicked?.({ field, column: col });
  }

  function handleRowNumClick(rowIndex: number, shiftKey: boolean) {
    if (!selectable) return;
    logger.debug('Table', 'Row num click', { rowIndex, shiftKey });

    const oneBasedIdx = rowIndex + 1;
    const currentRows = selection.type === 'row' ? (selection.value as number[]) : [];

    let next: number[];
    if (shiftKey) {
      next = currentRows.includes(oneBasedIdx)
        ? currentRows.filter(i => i !== oneBasedIdx)
        : [...currentRows, oneBasedIdx];
    } else {
      next = currentRows.includes(oneBasedIdx) ? [] : [oneBasedIdx];
    }

    selection = next.length > 0
      ? { type: 'row', value: next }
      : NONE_SEL;
    selectionChanged?.({ selection });
    logger.debug('Table', 'Selection', { selection });
  }

  // ── Inline editing ──────────────────────────────────

  let editingCell = $state<EditingCell | null>(null);

  function startEditing(field: string, rowIndex: number) {
    if (disabled) return;
    const col = columns.find(c => c.field === field);
    if (!col || !isColumnEditable(col)) return;
    editingCell = { rowIndex, field };
  }

  function commitEdit(field: string, rowIndex: number, oldValue: unknown, newValue: unknown) {
    editingCell = null;
    if (oldValue === newValue) return;
    // Update local rows directly (no round-trip)
    rows = rows.map((row, i) => i === rowIndex ? { ...row, [field]: newValue } : row);
    // Notify MATLAB
    publish?.('cellEdited', { field, rowIndex, oldValue, newValue });
  }

  function cancelEdit() {
    editingCell = null;
  }

  // Cancel editing when sort/filter changes
  $effect(() => {
    void sortField;
    void sortDirection;
    void Object.keys(filters).length;
    editingCell = null;
  });

  // ── Container keydown — entry/exit the grid ──────────
  function handleContainerKeydown(e: KeyboardEvent) {
    // If editing, let the cell editor handle Escape (its stopPropagation prevents this)
    if (e.key === 'Escape' && editingCell) {
      cancelEdit();
      e.preventDefault();
      return;
    }
    if (e.key === 'Escape' && e.target !== containerEl) {
      logger.debug('Table', 'Escape → exit grid, clear selection');
      e.preventDefault();
      if (selection.type !== 'none') {
        selection = NONE_SEL;
        selectionChanged?.({ selection });
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
  onMount(() => {
  focus = (): Resolution => {
    containerEl?.focus();
    return { success: true, data: null };
  };
  clearSelection = (): Resolution => {
    selection = NONE_SEL;
    selectionChanged?.({ selection });
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
  removeRow = (payload?: unknown): Resolution => {
    const items = Array.isArray(payload)
      ? payload as { index: number }[]
      : [payload as { index: number }];

    // Collect indices, sort descending so removals don't shift later indices
    const indices = items.map(r => r.index).sort((a, b) => b - a);

    for (const index of indices) {
      if (index < 0 || index >= rows.length) {
        return { success: false, data: `Row ${index} out of range` };
      }
      rows = rows.filter((_, i) => i !== index);

      const oneBasedIdx = index + 1;
      if (selection.type === 'row') {
        const adjusted = (selection.value as number[])
          .filter(v => v !== oneBasedIdx)
          .map(v => v > oneBasedIdx ? v - 1 : v);
        selection = adjusted.length > 0
          ? { type: 'row', value: adjusted }
          : NONE_SEL;
      } else if (selection.type === 'cell') {
        const adjusted = (selection.value as CellSelection[])
          .filter(c => c.row !== oneBasedIdx)
          .map(c => c.row > oneBasedIdx ? { ...c, row: c.row - 1 } : c);
        selection = adjusted.length > 0
          ? { type: 'cell', value: adjusted }
          : NONE_SEL;
      }
    }
    return { success: true, data: null };
  };
  removeColumn = (payload?: unknown): Resolution => {
    const items = Array.isArray(payload)
      ? payload as { field: string }[]
      : [payload as { field: string }];

    const fieldsToRemove = new Set(items.map(r => r.field));

    // Remove all fields in a single pass over rows
    rows = rows.map(row => {
      const next = { ...row };
      for (const f of fieldsToRemove) delete next[f];
      return next;
    });

    // Adjust selection
    for (const { field } of items) {
      if (selection.type === 'column') {
        const adjusted = (selection.value as string[]).filter(f => f !== field);
        selection = adjusted.length > 0
          ? { type: 'column', value: adjusted }
          : NONE_SEL;
      } else if (selection.type === 'cell') {
        const adjusted = (selection.value as CellSelection[]).filter(c => c.field !== field);
        selection = adjusted.length > 0
          ? { type: 'cell', value: adjusted }
          : NONE_SEL;
      }
    }
    return { success: true, data: null };
  };
  editCell = (payload?: unknown): Resolution => {
    // Accept a single edit object or an array of edits
    const edits = Array.isArray(payload)
      ? payload as { rowIndex: number; field: string; value: unknown }[]
      : [payload as { rowIndex: number; field: string; value: unknown }];

    // Apply all edits in a single pass over the rows array
    const touched = new Map<number, Record<string, unknown>>();
    for (const { rowIndex, field, value } of edits) {
      if (rowIndex < 0 || rowIndex >= rows.length) {
        return { success: false, data: `Row ${rowIndex} out of range` };
      }
      if (!touched.has(rowIndex)) touched.set(rowIndex, {});
      touched.get(rowIndex)![field] = value;
    }
    rows = rows.map((row, i) => {
      const patch = touched.get(i);
      return patch ? { ...row, ...patch } : row;
    });
    return { success: true, data: null };
  };
  focusCell = (payload?: unknown): Resolution => {
    const { rowIndex, field } = payload as { rowIndex: number; field: string };
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return { success: false, data: `Row ${rowIndex} out of range` };
    }
    const rowEl = containerEl?.querySelector(`.ic-tbl__row[data-row-index="${rowIndex}"]`) as HTMLElement | null;
    if (!rowEl) return { success: false, data: `Row ${rowIndex} not visible` };
    rowEl.scrollIntoView({ block: 'nearest' });
    const cell = rowEl.querySelector(`[data-field="${field}"]`) as HTMLElement | null;
    cell?.focus();
    return { success: true, data: null };
  };
  });
</script>

<div {id}
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
      columns={visibleColumns}
      bind:columnWidths
      {sortField}
      {sortDirection}
      {filters}
      showRowNumber={showRowNumbers}
      {rowNumWidth}
      {pinnedOffsets}
      {stickingFields}
      {selectable}
      activeColumns={activeColumnsList}
      {disabled}
      totalRowCount={sortedRows.length}
      {filterMatchCounts}
      onsort={handleSort}
      onfilterchange={handleFilterChange}
      oncolumnclick={handleColumnClick}
      oncolumnresized={handleColumnResized}
    />

    <div class="ic-tbl__body">
      {#each filteredRows as irow, i (irow.originalIndex)}
        <TableRowComp
          columns={visibleColumns}
          {columnWidths}
          rowData={irow.data}
          rowIndex={irow.originalIndex}
          selected={selectedRowSet.has(irow.originalIndex)}
          {disabled}
          {selectable}
          showRowNumber={showRowNumbers}
          {rowNumWidth}
          {pinnedOffsets}
          {stickingFields}
          {striped}
          even={i % 2 === 1}
          activeColumns={activeColumnsList}
          activeCells={activeCellsList}
          editingField={editingCell?.rowIndex === irow.originalIndex ? editingCell.field : null}
          onclick={handleRowClick}
          oncellclick={handleCellClick}
          oncellaction={handleCellAction}
          oncontextmenuaction={handleContextMenuAction}
          onrownumclick={handleRowNumClick}
          onstartedit={startEditing}
          oncommitedit={commitEdit}
          oncanceledit={cancelEdit}
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
