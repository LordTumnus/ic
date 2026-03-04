<script lang="ts">
  import type { Resolution, RequestFn, PublishFn } from '$lib/types';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import type { TableColumn, FilterState } from '$lib/utils/table-utils';
  import { computeColumnWidths } from '$lib/utils/table-utils';
  import { toSize } from '$lib/utils/css';
  import logger from '$lib/core/logger';
  import {
    type VirtualTreeTableNode,
    type VttChildCache,
    normalizeVttNodes,
    flattenVisible,
    computeTotalRows,
  } from '$lib/utils/virtual-tree-table';
  import TableHeader from '../../table/table/shared/TableHeader.svelte';
  import VirtualTreeTableRow from './VirtualTreeTableRow.svelte';

  const ROW_HEIGHTS: Record<string, number> = { sm: 24, md: 28, lg: 32 };

  // --- Props ---
  let {
    // Reactive props
    value = $bindable<string[] | string | null>(null),
    columns = $bindable([] as TableColumn[]),
    expanderColumn = $bindable(''),
    disabled = $bindable(false),
    selectable = $bindable(true),
    size = $bindable('md'),
    height = $bindable<number | string>(400),
    showLine = $bindable(true),
    striped = $bindable(false),
    maxSelectedItems = $bindable<number | null>(null),
    placeholder = $bindable('Loading...'),
    sortField = $bindable(''),
    sortDirection = $bindable('none' as 'none' | 'asc' | 'desc'),
    filters = $bindable({} as FilterState),
    rowCount = $bindable(0),
    viewVersion = $bindable(0),
    initialExpandedKeys = $bindable<string[] | null>(null),
    // Context menus
    leafContextMenu = $bindable<ContextMenuEntry[]>([]),
    folderContextMenu = $bindable<ContextMenuEntry[]>([]),
    // Framework
    publish,
    request,
    // Events
    valueChanged,
    sortChanged,
    filterChanged,
    cellClicked,
    contextMenuAction,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    expandNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    collapseNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    expandAll = $bindable((): Resolution => ({ success: true, data: null })),
    collapseAll = $bindable((): Resolution => ({ success: true, data: null })),
    editCell = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
  }: {
    value?: string[] | string | null;
    columns?: TableColumn[];
    expanderColumn?: string;
    disabled?: boolean;
    selectable?: boolean;
    size?: string;
    height?: number | string;
    showLine?: boolean;
    striped?: boolean;
    maxSelectedItems?: number | null;
    placeholder?: string;
    sortField?: string;
    sortDirection?: 'none' | 'asc' | 'desc';
    filters?: FilterState;
    rowCount?: number;
    viewVersion?: number;
    initialExpandedKeys?: string[] | null;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    publish?: PublishFn;
    request?: RequestFn;
    valueChanged?: (data?: unknown) => void;
    sortChanged?: (data?: unknown) => void;
    filterChanged?: (data?: unknown) => void;
    cellClicked?: (data?: unknown) => void;
    contextMenuAction?: (data?: unknown) => void;
    focus?: () => Resolution;
    clearSelection?: () => Resolution;
    expandNode?: (data: { key: string }) => Resolution;
    collapseNode?: (data: { key: string }) => Resolution;
    expandAll?: () => Resolution;
    collapseAll?: () => Resolution;
    editCell?: (data?: unknown) => Resolution;
  } = $props();

  // --- Refs ---
  let containerEl: HTMLDivElement;

  // --- Virtual tree state (from VirtualTree) ---
  let roots = $state<VirtualTreeTableNode[]>([]);
  let expandedKeys = $state(new Set<string>());
  let childCaches = $state(new Map<string, VttChildCache>());
  let loadingKeys = $state(new Set<string>());
  let pendingFetches = new Set<string>();
  let scrollTop = $state(0);
  let scrollTimer: ReturnType<typeof setTimeout>;
  let initialized = $state(false);

  // --- Table state ---
  let editingCell = $state<{ key: string; field: string } | null>(null);

  // --- Virtual scroll derived ---
  const rowHeight = $derived(ROW_HEIGHTS[size] ?? 28);

  const containerPx = $derived.by((): number => {
    if (typeof height === 'number') return height;
    const parsed = parseInt(String(height));
    return isNaN(parsed) ? 400 : parsed;
  });

  const viewportRows = $derived(Math.ceil(containerPx / rowHeight));
  const visibleCount = $derived(viewportRows + 4);
  const prefetchBuffer = $derived(Math.min(200, Math.max(20, viewportRows * 2)));

  // --- Column derived ---
  const visibleColumns = $derived(columns.filter((c) => c.visible !== false));
  const expanderField = $derived(expanderColumn || visibleColumns[0]?.field || '');

  let columnWidths = $state<number[]>([]);
  $effect(() => {
    if (visibleColumns.length > 0 && containerEl) {
      const w = containerEl.clientWidth;
      columnWidths = computeColumnWidths(visibleColumns, w);
    }
  });

  const totalColumnWidth = $derived(columnWidths.reduce((s, w) => s + (w || 0), 0));

  // --- Flattened rows ---
  const flatRows = $derived(flattenVisible(roots, expandedKeys, childCaches, showLine));
  const totalRows = $derived(computeTotalRows(roots, expandedKeys, childCaches));
  const totalHeight = $derived(totalRows * rowHeight);

  const startIdx = $derived(Math.max(0, Math.floor(scrollTop / rowHeight) - 1));
  const endIdx = $derived(Math.min(flatRows.length, startIdx + visibleCount));
  const visibleRows = $derived(flatRows.slice(startIdx, endIdx));

  // --- Selection ---
  const valueList = $derived.by((): string[] => {
    if (value == null) return [];
    if (Array.isArray(value)) return value.filter((v) => v !== '' && v != null);
    if (value === '') return [];
    return [value];
  });

  const selectedSet = $derived(new Set(valueList));
  const atMaxSelections = $derived(
    maxSelectedItems != null && valueList.length >= maxSelectedItems
  );

  function toggleItem(key: string) {
    let next: string[];
    if (selectedSet.has(key)) {
      next = valueList.filter((v) => v !== key);
    } else {
      if (atMaxSelections) return;
      next = [...valueList, key];
    }
    value = next.length > 0 ? next : null;
    valueChanged?.({ value });
  }

  // --- ViewVersion cache invalidation ---
  let prevViewVersion = viewVersion;
  $effect(() => {
    if (viewVersion === prevViewVersion) return;
    prevViewVersion = viewVersion;
    if (!initialized) return;
    logger.debug('VirtualTreeTable', 'ViewVersion changed, clearing caches', { viewVersion });
    roots = [];
    expandedKeys = new Set();
    childCaches = new Map();
    loadingKeys = new Set();
    pendingFetches = new Set();
    editingCell = null;
    // Re-request roots
    request?.('getRoots', {}).then((res: Resolution) => {
      if (res.success) {
        roots = normalizeVttNodes(res.data);
        if (initialExpandedKeys && initialExpandedKeys.length > 0) {
          expandedKeys = new Set(initialExpandedKeys);
        }
        setTimeout(viewportPrefetch, 100);
      }
    });
  });

  // --- Lifecycle: load roots ---
  $effect(() => {
    if (!request || initialized) return;
    initialized = true;
    logger.info('VirtualTreeTable', 'Requesting roots');
    request('getRoots', {})
      .then((res: Resolution) => {
        if (res.success) {
          roots = normalizeVttNodes(res.data);
          // Apply initial expanded keys (default: all folders expanded)
          if (initialExpandedKeys && initialExpandedKeys.length > 0) {
            expandedKeys = new Set(initialExpandedKeys);
          }
          logger.info('VirtualTreeTable', 'Roots loaded', {
            count: roots.length,
            expandedCount: expandedKeys.size,
          });
          setTimeout(viewportPrefetch, 100);
        }
      })
      .catch((err: Error) => {
        logger.error('VirtualTreeTable', 'getRoots error', { error: String(err) });
      });
  });

  // --- Expand / Collapse ---
  function expandKey(key: string) {
    const next = new Set(expandedKeys);
    next.add(key);
    expandedKeys = next;
    setTimeout(viewportPrefetch, 50);
  }

  function handleExpandChange(key: string, expanded: boolean) {
    if (expanded) {
      if (childCaches.has(key)) {
        expandKey(key);
      } else {
        const nextLoading = new Set(loadingKeys);
        nextLoading.add(key);
        loadingKeys = nextLoading;
        ensureChildrenLoaded(key, 0, prefetchBuffer).then(() => {
          const nl = new Set(loadingKeys);
          nl.delete(key);
          loadingKeys = nl;
          expandKey(key);
        });
      }
    } else {
      const next = new Set(expandedKeys);
      for (const k of next) {
        if (k === key || k.startsWith(key + '-')) next.delete(k);
      }
      expandedKeys = next;
      setTimeout(viewportPrefetch, 50);
    }
  }

  // --- Request helpers ---
  async function ensureChildrenLoaded(parentKey: string, offset: number, count: number) {
    const fetchKey = `${parentKey}:${offset}`;
    if (pendingFetches.has(fetchKey)) return;
    pendingFetches.add(fetchKey);
    try {
      const res = await request?.('getChildren', { key: parentKey, offset, count });
      if (res?.success) {
        const nodes = normalizeVttNodes(res.data);
        const existing = childCaches.get(parentKey);
        const cache: VttChildCache = existing
          ? { ...existing, nodes: [...existing.nodes] }
          : { nodes: [], loaded: 0, total: 0 };

        const parentNode = findNode(parentKey);
        if (parentNode) cache.total = parentNode.childCount;

        for (let i = 0; i < nodes.length; i++) {
          cache.nodes[offset + i] = nodes[i];
        }
        cache.loaded = Math.max(cache.loaded, offset + nodes.length);

        const next = new Map(childCaches);
        next.set(parentKey, cache);
        childCaches = next;
      }
    } finally {
      pendingFetches.delete(fetchKey);
    }
  }

  function findNode(key: string): VirtualTreeTableNode | undefined {
    for (const r of roots) {
      if (r.key === key) return r;
    }
    for (const [, cache] of childCaches) {
      for (const n of cache.nodes) {
        if (n && n.key === key) return n;
      }
    }
    return undefined;
  }

  // --- Scroll prefetch ---
  function checkScrollPrefetch() {
    const checked = new Set<string>();
    for (const row of visibleRows) {
      const lastDash = row.node.key.lastIndexOf('-');
      if (lastDash === -1) continue;
      const parentKey = row.node.key.substring(0, lastDash);
      if (checked.has(parentKey)) continue;
      checked.add(parentKey);
      if (!expandedKeys.has(parentKey)) continue;
      const cache = childCaches.get(parentKey);
      if (!cache) {
        if (row.isPlaceholder) {
          ensureChildrenLoaded(parentKey, 0, prefetchBuffer);
        }
        continue;
      }
      if (cache.loaded >= cache.total) continue;
      const childIdx = parseInt(row.node.key.substring(lastDash + 1), 10);
      if (childIdx >= cache.loaded - prefetchBuffer) {
        ensureChildrenLoaded(parentKey, cache.loaded, prefetchBuffer);
      }
    }
  }

  function viewportPrefetch() {
    const checkedParents = new Set<string>();
    for (const row of visibleRows) {
      if (row.isPlaceholder) {
        const lastDash = row.node.key.lastIndexOf('-');
        if (lastDash === -1) continue;
        const parentKey = row.node.key.substring(0, lastDash);
        if (checkedParents.has(parentKey)) continue;
        checkedParents.add(parentKey);
        if (!childCaches.has(parentKey)) {
          ensureChildrenLoaded(parentKey, 0, prefetchBuffer).then(() => {
            setTimeout(viewportPrefetch, 50);
          });
        }
        continue;
      }
      if (!row.node.isFolder) continue;
      if (expandedKeys.has(row.node.key)) continue;
      if (childCaches.has(row.node.key)) continue;
      ensureChildrenLoaded(row.node.key, 0, prefetchBuffer);
    }
  }

  // --- Scroll handler ---
  function handleScroll() {
    scrollTop = containerEl.scrollTop;
    checkScrollPrefetch();
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(viewportPrefetch, 200);
  }

  // --- Sort / Filter handlers ---
  function handleSort(field: string, direction: 'none' | 'asc' | 'desc') {
    sortField = field;
    sortDirection = direction;
    editingCell = null;
    sortChanged?.({ field, direction });
  }

  function handleFilterChange(field: string, val: unknown) {
    if (val == null) {
      const { [field]: _, ...rest } = filters;
      filters = rest;
    } else {
      filters = { ...filters, [field]: val };
    }
    editingCell = null;
    filterChanged?.({ field, value: val, filters });
  }

  function handleColumnResized(field: string, width: number) {
    publish?.('columnResized', { field, width: Math.round(width) });
  }

  // --- Cell interaction handlers ---
  function handleCellClick(key: string, field: string) {
    cellClicked?.({ key, field });
  }

  function handleCellDblClick(key: string, field: string) {
    const col = visibleColumns.find((c) => c.field === field);
    if (!col?.editable) return;
    editingCell = { key, field };
  }

  function handleCommitEdit(key: string, field: string, oldValue: unknown, newValue: unknown) {
    editingCell = null;
    if (oldValue === newValue) return;
    publish?.('cellEdited', { key, field, oldValue, newValue });
  }

  function handleCancelEdit() {
    editingCell = null;
  }

  function handleCellAction(key: string, field: string, data: unknown) {
    publish?.('cellAction', { key, field, data });
  }

  function handleContextMenuAction(
    nodeKey: string,
    nodeType: 'leaf' | 'folder',
    itemKey: string,
    field?: string
  ) {
    contextMenuAction?.({ item: itemKey, nodeKey, nodeType, field });
  }

  // --- Keydown ---
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && editingCell) {
      handleCancelEdit();
      e.preventDefault();
    }
  }

  // --- Methods ---
  $effect(() => {
    focus = (): Resolution => {
      containerEl?.focus();
      return { success: true, data: null };
    };
    clearSelection = (): Resolution => {
      value = null;
      valueChanged?.({ value: null });
      return { success: true, data: null };
    };
    expandNode = (data: { key: string }): Resolution => {
      handleExpandChange(data.key, true);
      return { success: true, data: null };
    };
    collapseNode = (data: { key: string }): Resolution => {
      handleExpandChange(data.key, false);
      return { success: true, data: null };
    };
    expandAll = (): Resolution => {
      const next = new Set(expandedKeys);
      function addFolders(nodes: VirtualTreeTableNode[]) {
        for (const n of nodes) {
          if (n.isFolder) {
            next.add(n.key);
            ensureChildrenLoaded(n.key, 0, prefetchBuffer);
            const cache = childCaches.get(n.key);
            if (cache) addFolders(cache.nodes.filter(Boolean));
          }
        }
      }
      addFolders(roots);
      expandedKeys = next;
      return { success: true, data: null };
    };
    collapseAll = (): Resolution => {
      expandedKeys = new Set();
      return { success: true, data: null };
    };
    editCell = (payload?: unknown): Resolution => {
      const { key, field, value: cellValue } = payload as { key: string; field: string; value: unknown };
      // Find the node in cache and update its local data for immediate display
      const node = findNode(key);
      if (node && node.data) {
        const expField = expanderColumn || visibleColumns[0]?.field || '';
        if (field === expField) {
          node.name = String(cellValue);
        } else {
          node.data[field] = cellValue;
        }
        // Trigger reactivity by replacing the cache entry
        const lastDash = key.lastIndexOf('-');
        const parentKey = lastDash === -1 ? '' : key.substring(0, lastDash);
        if (parentKey && childCaches.has(parentKey)) {
          childCaches = new Map(childCaches);
        } else {
          roots = [...roots];
        }
      }
      return { success: true, data: null };
    };
  });

  // Height style for the overall container
  const heightStyle = $derived(toSize(height));
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={containerEl}
  class="ic-vtt"
  class:ic-tbl--sm={size === 'sm'}
  class:ic-tbl--md={size === 'md'}
  class:ic-tbl--lg={size === 'lg'}
  class:ic-vtt--disabled={disabled}
  style:height={heightStyle}
  role="treegrid"
  tabindex={disabled ? -1 : 0}
  onscroll={handleScroll}
  onkeydown={handleKeydown}
>
  <div class="ic-vtt__inner" style:min-width="{totalColumnWidth ? totalColumnWidth + 'px' : '100%'}">
    <!-- Sticky column header -->
    <TableHeader
      columns={visibleColumns}
      bind:columnWidths
      {sortField}
      {sortDirection}
      {filters}
      {disabled}
      totalRowCount={rowCount}
      filterMatchCounts={{}}
      onsort={handleSort}
      onfilterchange={handleFilterChange}
      oncolumnresized={handleColumnResized}
    />

    <!-- Virtual scroll body -->
    <div class="ic-vtt__body" style:height="{totalHeight}px">
      {#each visibleRows as row, i (row.node.key + (row.isPlaceholder ? '-ph' : ''))}
        <div
          class="ic-vtt__row-wrapper"
          style="position: absolute; top: {(startIdx + i) * rowHeight}px; height: {rowHeight}px; width: 100%"
        >
          <VirtualTreeTableRow
            {row}
            columns={visibleColumns}
            {columnWidths}
            {expanderField}
            {size}
            {showLine}
            {disabled}
            {selectable}
            {striped}
            stripedIndex={startIdx + i}
            selected={selectedSet.has(row.node.key)}
            {atMaxSelections}
            {expandedKeys}
            {loadingKeys}
            {editingCell}
            {leafContextMenu}
            {folderContextMenu}
            ontoggleselect={toggleItem}
            ontoggleexpand={handleExpandChange}
            oncellclick={handleCellClick}
            oncelldblclick={handleCellDblClick}
            oncommitedit={handleCommitEdit}
            oncanceledit={handleCancelEdit}
            oncellaction={handleCellAction}
            oncontextmenuaction={handleContextMenuAction}
          />
        </div>
      {/each}

      {#if !initialized || (initialized && roots.length === 0)}
        <div class="ic-vtt__empty">{placeholder}</div>
      {/if}
    </div>
  </div>
</div>

<style>
  /* ═══════ ROOT CONTAINER ═══════ */
  .ic-vtt {
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: auto;
    background: var(--ic-background);
    width: 100%;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.02);
  }
  .ic-vtt:focus {
    outline: none;
    border-color: var(--ic-primary);
  }
  .ic-vtt--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* ═══════ STICKY HEADER ═══════ */
  .ic-vtt :global(.ic-tbl__header) {
    position: sticky;
    top: 0;
    z-index: 4;
  }

  /* ═══════ SIZE (match Table density for TableHeader) ═══════ */
  .ic-tbl--sm :global(.ic-tbl__header) {
    min-height: 24px;
    font-size: 0.7rem;
  }
  .ic-tbl--md :global(.ic-tbl__header) {
    min-height: 28px;
    font-size: 0.75rem;
  }
  .ic-tbl--lg :global(.ic-tbl__header) {
    min-height: 36px;
    font-size: 0.8125rem;
  }

  /* Row font sizes for tree content */
  .ic-tbl--sm .ic-vtt__body { font-size: 0.7rem; }
  .ic-tbl--md .ic-vtt__body { font-size: 0.75rem; }
  .ic-tbl--lg .ic-vtt__body { font-size: 0.8125rem; }

  /* ═══════ BODY (virtual scroll area) ═══════ */
  .ic-vtt__body {
    position: relative;
  }

  .ic-vtt__row-wrapper {
    position: absolute;
    left: 0;
    right: 0;
  }

  /* ═══════ EMPTY STATE ═══════ */
  .ic-vtt__empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    font-size: 0.75rem;
  }
</style>
