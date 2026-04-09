<script lang="ts">
  import type { PublishFn, Resolution, RequestFn } from '$lib/types';
  import type { TableColumn, TableRow as TRow, FilterState, CellActionPayload } from '$lib/utils/table-utils';
  import type { PinnedInfo, CellSelection, SelectionState, EditingCell } from '$lib/utils/table-utils';
  import {
    computeColumnWidths,
    computePinnedOffsets,
    ROW_HEIGHTS,
    isColumnEditable,
  } from '$lib/utils/table-utils';
  import { normalizeGetRowsResponse, type CachedRow } from '$lib/utils/virtual-table';
  import logger from '$lib/core/logger';
  import TableHeader from '../table/shared/TableHeader.svelte';
  import TableRowComp from '../table/shared/TableRow.svelte';

  const NONE_SEL: SelectionState = { type: 'none', value: null };
  const CHUNK_SIZE = 100;
  const BUFFER = 5; // rows above/below viewport to pre-render

  let {
    id = '',
    // Reactive props (from TableBase — same as Table, minus `data`)
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

    // VirtualTable-specific reactive props
    rowCount = $bindable(0),
    viewVersion = $bindable(0),

    // IC pub/sub + request
    publish,
    request,

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
    focusCell = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
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
    rowCount?: number;
    viewVersion?: number;
    publish?: PublishFn;
    request?: RequestFn;
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
    focusCell?: (data?: unknown) => Resolution;
  } = $props();

  let containerEl: HTMLDivElement;

  // ── Column visibility ──────────────────────────────
  const visibleColumns = $derived(columns.filter(c => c.visible !== false));

  // ── Virtual scroll state ───────────────────────────
  const rowH = $derived(ROW_HEIGHTS[size as keyof typeof ROW_HEIGHTS] ?? ROW_HEIGHTS.md);
  const totalHeight = $derived(rowCount * rowH);

  let scrollTop = $state(0);
  let maxScroll = $state(0);

  const containerPx = $derived.by((): number => {
    if (typeof height === 'number') return height;
    const parsed = parseInt(String(height));
    return isNaN(parsed) ? 400 : parsed;
  });

  const viewportRows = $derived(Math.ceil(containerPx / rowH));
  const startIdx = $derived(Math.max(0, Math.floor(scrollTop / rowH) - BUFFER));
  const endIdx = $derived(Math.min(rowCount, Math.floor(scrollTop / rowH) + viewportRows + BUFFER));

  // ── Row cache ──────────────────────────────────────
  let rowCache = $state(new Map<number, CachedRow>());
  let cacheVersion = 0; // NOT $state — only used for stale response detection
  let pendingRanges = new Set<string>();

  // When viewVersion changes, MATLAB has recomputed the view (sort/filter changed).
  // Clear the cache and re-fetch visible rows.
  $effect(() => {
    void viewVersion; // track
    rowCache = new Map();
    cacheVersion++;
    pendingRanges = new Set();
    // Re-fetch after state settles
    requestAnimationFrame(() => fetchVisibleRows());
  });

  // ── Row fetching ───────────────────────────────────
  async function fetchRows(offset: number, count: number) {
    const rangeKey = `${offset}:${count}`;
    if (pendingRanges.has(rangeKey)) return;
    pendingRanges.add(rangeKey);

    const capturedVersion = cacheVersion;
    logger.debug('VirtualTable', 'Fetching rows', { offset, count });

    try {
      const res = await request?.('getRows', { offset, count });
      if (!res?.success) return;
      // Stale response — viewVersion changed while in flight
      if (capturedVersion !== cacheVersion) return;

      const { rows, indices } = normalizeGetRowsResponse(res.data);
      const next = new Map(rowCache);
      for (let i = 0; i < rows.length; i++) {
        next.set(offset + i, { data: rows[i], originalIndex: indices[i] });
      }
      rowCache = next;
    } finally {
      pendingRanges.delete(rangeKey);
    }
  }

  function fetchVisibleRows() {
    if (rowCount === 0) return;
    // Clear stale pending ranges — only current viewport matters
    pendingRanges = new Set();
    // Find missing rows in the visible window
    let missStart = -1;
    for (let i = startIdx; i < endIdx; i++) {
      if (!rowCache.has(i)) {
        if (missStart === -1) missStart = i;
      } else if (missStart !== -1) {
        fetchRows(missStart, i - missStart);
        missStart = -1;
      }
    }
    if (missStart !== -1) {
      fetchRows(missStart, endIdx - missStart);
    }
  }

  // Prefetch ahead when scrolling
  function prefetchAhead() {
    if (rowCount === 0) return;
    const prefetchEnd = Math.min(rowCount, endIdx + CHUNK_SIZE);
    let missStart = -1;
    for (let i = endIdx; i < prefetchEnd; i++) {
      if (!rowCache.has(i)) {
        if (missStart === -1) missStart = i;
      } else if (missStart !== -1) {
        fetchRows(missStart, i - missStart);
        missStart = -1;
      }
    }
    if (missStart !== -1) {
      fetchRows(missStart, prefetchEnd - missStart);
    }
  }

  // ── Visible rows (derived from cache) ──────────────
  const visibleRows = $derived.by(() => {
    const result: { viewIndex: number; cached: CachedRow | null }[] = [];
    for (let i = startIdx; i < endIdx; i++) {
      result.push({ viewIndex: i, cached: rowCache.get(i) ?? null });
    }
    return result;
  });

  // ── Selection derived state ────────────────────────
  const selectedRowSet = $derived(
    selection.type === 'row'
      ? new Set((selection.value as number[]).map(i => i - 1))
      : new Set<number>()
  );

  const activeCellsList = $derived(
    selection.type === 'cell'
      ? (selection.value as CellSelection[]).map(c => ({ field: c.field, rowIndex: c.row - 1 }))
      : []
  );

  const activeColumnsList = $derived(
    selection.type === 'column' ? (selection.value as string[]) : []
  );

  // ── Dynamic row number width ───────────────────────
  const rowNumWidth = $derived.by(() => {
    if (rowCount === 0) return 24;
    const digits = Math.floor(Math.log10(rowCount)) + 1;
    return digits * 8 + 10;
  });

  // ── Column widths + pinned offsets ─────────────────
  let columnWidths = $state<number[]>([]);
  $effect(() => {
    if (visibleColumns.length > 0 && containerEl) {
      const w = containerEl.clientWidth;
      let reserved = 0;
      if (showRowNumbers) reserved += rowNumWidth;
      columnWidths = computeColumnWidths(visibleColumns, w - reserved);
    }
  });

  const pinnedOffsets = $derived(
    computePinnedOffsets(visibleColumns, columnWidths, showRowNumbers ? rowNumWidth : 0)
  );

  // ── Scroll handling ─────────────────────────────────
  let scrollLeft = $state(0);
  let fetchTimer: ReturnType<typeof setTimeout>;
  let prefetchTimer: ReturnType<typeof setTimeout>;

  function handleScroll() {
    // Immediate: update scroll positions (drives row positioning + pinned columns)
    scrollTop = containerEl.scrollTop;
    scrollLeft = containerEl.scrollLeft;
    maxScroll = containerEl.scrollWidth - containerEl.clientWidth;

    // Debounced: fetch visible rows after scroll settles (avoids flooding MATLAB)
    clearTimeout(fetchTimer);
    fetchTimer = setTimeout(fetchVisibleRows, 80);

    // Longer debounce: prefetch ahead for smooth future scrolling
    clearTimeout(prefetchTimer);
    prefetchTimer = setTimeout(prefetchAhead, 250);
  }

  $effect(() => {
    if (containerEl && visibleColumns.length > 0 && columnWidths.length > 0) {
      maxScroll = containerEl.scrollWidth - containerEl.clientWidth;
    }
  });

  const stickingFields = $derived.by(() => {
    const result = new Set<string>();
    if (maxScroll <= 0) return result;
    if (showRowNumbers && scrollLeft > 0) result.add('__rownum__');

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

  // ── Height / width styles ──────────────────────────
  const heightStyle = $derived(
    height === 'auto' ? 'auto' : typeof height === 'number' ? `${height}px` : height
  );

  const hasAutoColumns = $derived(columnWidths.some(w => w === 0));
  const totalWidth = $derived.by(() => {
    if (hasAutoColumns) return 0;
    let w = columnWidths.reduce((s, v) => s + v, 0);
    if (showRowNumbers) w += rowNumWidth;
    return w;
  });

  // ── Sort / Filter handlers ─────────────────────────
  function handleSort(field: string, direction: 'none' | 'asc' | 'desc') {
    logger.debug('VirtualTable', 'Sort', { field, direction });
    sortField = field;
    sortDirection = direction;
    sortChanged?.({ field, direction });
  }

  function handleColumnResized(field: string, width: number) {
    logger.debug('VirtualTable', 'Column resized', { field, width: Math.round(width) });
    publish?.('columnResized', { field, width: Math.round(width) });
  }

  function handleFilterChange(field: string, val: unknown) {
    logger.debug('VirtualTable', 'Filter change', { field, value: val });
    if (val == null) {
      const { [field]: _, ...rest } = filters;
      filters = rest;
    } else {
      filters = { ...filters, [field]: val };
    }
    filterChanged?.({ field, value: val, filters });
  }

  // ── Row / Cell / Column click handlers ─────────────
  function handleRowClick(rowIndex: number, rowData: TRow) {
    logger.debug('VirtualTable', 'Row click', { rowIndex });
    if (selectable && selection.type !== 'none') {
      selection = NONE_SEL;
      selectionChanged?.({ selection });
    }
    rowClicked?.({ rowIndex: rowIndex + 1, rowData });
  }

  function handleCellClick(field: string, rowIndex: number, val: unknown, rowData: TRow, shiftKey: boolean) {
    logger.debug('VirtualTable', 'Cell click', { field, rowIndex, shiftKey });

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
    }
    cellClicked?.({ field, rowIndex: rowIndex + 1, value: val, rowData });
  }

  function handleCellAction(field: string, rowIndex: number, data: unknown) {
    publish?.('cellAction', { field, rowIndex, data } satisfies CellActionPayload);
  }

  function handleContextMenuAction(field: string, rowIndex: number, itemKey: string) {
    contextMenuAction?.({ item: itemKey, field, rowIndex: rowIndex + 1 });
  }

  function handleColumnClick(field: string, shiftKey: boolean) {
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
    }
    const col = columns.find(c => c.field === field);
    columnClicked?.({ field, column: col });
  }

  function handleRowNumClick(rowIndex: number, shiftKey: boolean) {
    if (!selectable) return;

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
  }

  // ── Inline editing ─────────────────────────────────
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
    // Update local cache
    const cached = findCachedByOriginalIndex(rowIndex);
    if (cached) {
      const next = new Map(rowCache);
      next.set(cached.viewIndex, {
        data: { ...cached.row.data, [field]: newValue },
        originalIndex: cached.row.originalIndex,
      });
      rowCache = next;
    }
    // Notify MATLAB — rowIndex is 0-based here, MATLAB handler expects it
    publish?.('cellEdited', { field, rowIndex, oldValue, newValue });
  }

  function cancelEdit() {
    editingCell = null;
  }

  /** Find a cached row by its 0-based original index. */
  function findCachedByOriginalIndex(originalIndex0: number): { viewIndex: number; row: CachedRow } | null {
    const originalIndex1 = originalIndex0 + 1;
    for (const [viewIdx, cached] of rowCache) {
      if (cached.originalIndex === originalIndex1) {
        return { viewIndex: viewIdx, row: cached };
      }
    }
    return null;
  }

  // Cancel editing on sort/filter change
  $effect(() => {
    void sortField;
    void sortDirection;
    void Object.keys(filters).length;
    editingCell = null;
  });

  // ── Container keydown ──────────────────────────────
  function handleContainerKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && editingCell) {
      cancelEdit();
      e.preventDefault();
      return;
    }
    if (e.key === 'Escape' && e.target !== containerEl) {
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
      e.preventDefault();
      const firstHeader = containerEl.querySelector('.ic-tbl__hcell:not(.ic-tbl__hcell--rownum)') as HTMLElement | null;
      firstHeader?.focus();
    }
  }

  // ── Methods ────────────────────────────────────────
  $effect(() => {
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
        containerEl.scrollTop = key * rowH;
      }
      return { success: true, data: null };
    };
    focusCell = (payload?: unknown): Resolution => {
      const { rowIndex, field } = payload as { rowIndex: number; field: string };
      if (containerEl) {
        containerEl.scrollTop = rowIndex * rowH;
      }
      requestAnimationFrame(() => {
        const rowEl = containerEl?.querySelector(`.ic-vtbl__row[data-row-index="${rowIndex}"]`) as HTMLElement | null;
        if (!rowEl) return;
        const cell = rowEl.querySelector(`[data-field="${field}"]`) as HTMLElement | null;
        cell?.focus();
      });
      return { success: true, data: null };
    };
  });
</script>

<div {id}
  bind:this={containerEl}
  class="ic-vtbl"
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
  <div class="ic-vtbl__inner" style:min-width="{totalWidth ? totalWidth + 'px' : '100%'}">
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
      totalRowCount={rowCount}
      filterMatchCounts={{}}
      onsort={handleSort}
      onfilterchange={handleFilterChange}
      oncolumnclick={handleColumnClick}
      oncolumnresized={handleColumnResized}
    />
    <div class="ic-vtbl__body" style:height="{totalHeight}px">
      {#each visibleRows as vrow (vrow.viewIndex)}
        {#if vrow.cached}
          <div
            class="ic-vtbl__row-wrapper"
            style="position:absolute; top:{vrow.viewIndex * rowH}px; height:{rowH}px; width:100%"
          >
            <TableRowComp
              columns={visibleColumns}
              {columnWidths}
              rowData={vrow.cached.data}
              rowIndex={vrow.cached.originalIndex - 1}
              selected={selectedRowSet.has(vrow.cached.originalIndex - 1)}
              {disabled}
              {selectable}
              showRowNumber={showRowNumbers}
              {rowNumWidth}
              {pinnedOffsets}
              {stickingFields}
              {striped}
              even={vrow.viewIndex % 2 === 1}
              activeColumns={activeColumnsList}
              activeCells={activeCellsList}
              editingField={editingCell?.rowIndex === (vrow.cached.originalIndex - 1) ? editingCell.field : null}
              onclick={handleRowClick}
              oncellclick={handleCellClick}
              oncellaction={handleCellAction}
              oncontextmenuaction={handleContextMenuAction}
              onrownumclick={handleRowNumClick}
              onstartedit={startEditing}
              oncommitedit={commitEdit}
              oncanceledit={cancelEdit}
            />
          </div>
        {:else}
          <div
            class="ic-vtbl__row-wrapper ic-vtbl__row--placeholder"
            style="position:absolute; top:{vrow.viewIndex * rowH}px; height:{rowH}px; width:100%"
          >
            <div class="ic-vtbl__shimmer"></div>
          </div>
        {/if}
      {:else}
        {#if rowCount === 0}
          <div class="ic-vtbl__empty">No data</div>
        {/if}
      {/each}
    </div>
  </div>
</div>

<style>
  .ic-vtbl {
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: auto;
    background: var(--ic-background);
    width: 100%;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.02);
  }

  .ic-vtbl:focus {
    outline: none;
    border-color: var(--ic-primary);
  }

  /* Sticky header stays visible during vertical scroll */
  .ic-vtbl :global(.ic-tbl__header) {
    position: sticky;
    top: 0;
    z-index: 4;
  }

  /* Size row heights — match Table.svelte density.
     The .ic-tbl--* classes are on the root element (via class:). */
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

  .ic-vtbl__body {
    position: relative;
  }

  .ic-vtbl__row-wrapper {
    position: absolute;
    left: 0;
    right: 0;
  }

  /* Placeholder shimmer for loading rows */
  .ic-vtbl__row--placeholder {
    display: flex;
    align-items: center;
    padding: 0 8px;
  }

  .ic-vtbl__shimmer {
    width: 60%;
    height: 8px;
    border-radius: 2px;
    background: var(--ic-secondary);
    opacity: 0.5;
  }

  .ic-vtbl__empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    font-size: 0.75rem;
  }
</style>
