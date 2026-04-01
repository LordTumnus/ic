<script lang="ts">
  import type { Resolution } from '$lib/types';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import { toSize } from '$lib/utils/css';
  import {
    type TreeTableNode,
    normalizeTreeTableNodes,
    flattenVisible,
    sortTreeRecursive,
    filterTree,
  } from '$lib/utils/tree-table-utils';
  import type { FlatTreeRow } from '$lib/utils/tree-table-utils';
  import type { TableColumn, FilterState } from '$lib/utils/table-utils';
  import { computeColumnWidths } from '$lib/utils/table-utils';
  import {
    normalizeIcon,
    findNodeByKey,
    collectAllFolderKeys,
    removeAndReindex,
    remapValues,
  } from '$lib/utils/tree-utils';
  import { filterMatchers } from '../../table/table/cells/filter-matchers';
  import { sortComparators } from '../../table/table/cells/sort-comparators';
  import TableHeader from '../../table/table/shared/TableHeader.svelte';
  import TreeTableRow from './TreeTableRow.svelte';

  // --- Props ---
  let {
    items = $bindable<unknown>(null),
    value = $bindable<string[] | string | null>(null),
    columns = $bindable<TableColumn[]>([]),
    expanderColumn = $bindable(''),
    disabled = $bindable(false),
    selectable = $bindable(true),
    size = $bindable('md'),
    maxSelectedItems = $bindable<number | null>(null),
    height = $bindable<number | string>(400),
    showLine = $bindable(true),
    striped = $bindable(false),
    lazyLoad = $bindable(true),
    sortField = $bindable(''),
    sortDirection = $bindable<'none' | 'asc' | 'desc'>('none'),
    filters = $bindable<FilterState>({}),
    // Publish function
    publish,
    // Context menus
    leafContextMenu = $bindable<ContextMenuEntry[]>([]),
    folderContextMenu = $bindable<ContextMenuEntry[]>([]),
    // Events
    valueChanged,
    sortChanged,
    filterChanged,
    cellClicked,
    contextMenuAction,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    addNode = $bindable((_data: { parentKey: string; label: string; icon?: unknown }): Resolution => ({ success: true, data: null })),
    removeNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    updateNode = $bindable((_data: { key: string; label?: string; icon?: unknown }): Resolution => ({ success: true, data: null })),
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    expandNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    collapseNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    expandAll = $bindable((): Resolution => ({ success: true, data: null })),
    collapseAll = $bindable((): Resolution => ({ success: true, data: null })),
    editCell = $bindable((_data: { key: string; field: string; value: unknown }): Resolution => ({ success: true, data: null })),
  }: {
    items?: unknown;
    value?: string[] | string | null;
    columns?: TableColumn[];
    expanderColumn?: string;
    disabled?: boolean;
    selectable?: boolean;
    size?: string;
    maxSelectedItems?: number | null;
    height?: number | string;
    showLine?: boolean;
    striped?: boolean;
    lazyLoad?: boolean;
    sortField?: string;
    sortDirection?: 'none' | 'asc' | 'desc';
    filters?: FilterState;
    publish?: (event: string, data: unknown) => void;
    valueChanged?: (data?: unknown) => void;
    sortChanged?: (data?: unknown) => void;
    filterChanged?: (data?: unknown) => void;
    cellClicked?: (data?: unknown) => void;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    contextMenuAction?: (data?: unknown) => void;
    focus?: () => Resolution;
    addNode?: (data: { parentKey: string; label: string; icon?: unknown }) => Resolution;
    removeNode?: (data: { key: string }) => Resolution;
    updateNode?: (data: { key: string; label?: string; icon?: unknown }) => Resolution;
    clearSelection?: () => Resolution;
    expandNode?: (data: { key: string }) => Resolution;
    collapseNode?: (data: { key: string }) => Resolution;
    expandAll?: () => Resolution;
    collapseAll?: () => Resolution;
    editCell?: (data: { key: string; field: string; value: unknown }) => Resolution;
  } = $props();

  // --- Refs ---
  let containerEl: HTMLDivElement;
  let bodyEl: HTMLDivElement;

  // --- State ---
  let expandedKeys = $state(new Set<string>());
  let expandedInitialized = false;
  let editingCell = $state<{ key: string; field: string } | null>(null);
  let containerWidth = $state(0);

  // --- Tree normalization ---
  let treeState = $state<TreeTableNode[]>([]);
  $effect(() => {
    treeState = normalizeTreeTableNodes(items);
    // Expand all folders only on first load — not on every re-publish
    if (!expandedInitialized && treeState.length > 0) {
      expandedKeys = new Set(collectAllFolderKeys(treeState));
      expandedInitialized = true;
    }
  });

  // --- Columns ---
  // Reorder so the expander column is always first
  const visibleColumns = $derived.by(() => {
    const cols = columns.filter((c) => c.visible !== false);
    if (!expanderColumn || cols.length === 0) return cols;
    const idx = cols.findIndex((c) => c.field === expanderColumn);
    if (idx <= 0) return cols; // already first or not found
    const reordered = [...cols];
    const [expCol] = reordered.splice(idx, 1);
    reordered.unshift(expCol);
    return reordered;
  });

  // Resolve expander field: explicit or first column
  const expanderField = $derived(
    expanderColumn || (visibleColumns.length > 0 ? visibleColumns[0].field : ''),
  );

  // The "name field" is the first column in the user-defined order (before reordering).
  // It always maps to node.name, regardless of which column is the expander.
  const nameField = $derived(
    columns.filter((c) => c.visible !== false)[0]?.field || '',
  );

  // Column widths
  let columnWidths = $state<number[]>([]);
  $effect(() => {
    columnWidths = computeColumnWidths(visibleColumns, containerWidth);
  });

  // Total column width — used to ensure all rows span the full table width on horizontal scroll
  const totalColumnWidth = $derived(
    columnWidths.reduce((sum, w) => sum + (w || 0), 0),
  );

  // --- Value (selection) ---
  const valueList = $derived.by((): string[] => {
    if (value == null) return [];
    if (Array.isArray(value)) return value.filter((v) => v !== '' && v != null);
    if (value === '') return [];
    return [value];
  });

  const selectedSet = $derived(new Set(valueList));

  const atMaxSelections = $derived(
    maxSelectedItems != null && valueList.length >= maxSelectedItems,
  );

  // --- Sort ---
  const sortedTree = $derived.by(() => {
    if (!sortField || sortDirection === 'none') return treeState;
    return sortTreeRecursive(
      treeState,
      sortField,
      sortDirection as 'asc' | 'desc',
      expanderField,
      visibleColumns,
      sortComparators,
    );
  });

  // --- Filter ---
  const filterResult = $derived.by(() => {
    return filterTree(
      sortedTree,
      filters,
      visibleColumns,
      filterMatchers,
      expanderField,
    );
  });

  const filteredTree = $derived(filterResult.filtered);
  const filterMatchCounts = $derived(filterResult.matchCounts);
  const filterExpandKeys = $derived(filterResult.expandKeys);

  // Auto-expand filtered folders
  $effect(() => {
    if (filterExpandKeys.length > 0) {
      const next = new Set(expandedKeys);
      for (const k of filterExpandKeys) next.add(k);
      expandedKeys = next;
    }
  });

  // --- Flatten to visible rows ---
  const flatRows = $derived(
    flattenVisible(filteredTree, expandedKeys),
  );

  // Total leaf count for filter match display
  const totalLeafCount = $derived.by(() => {
    let count = 0;
    function walk(nodes: TreeTableNode[]) {
      for (const n of nodes) {
        if (n.children.length > 0) walk(n.children);
        else count++;
      }
    }
    walk(treeState);
    return count;
  });

  // --- Selection ---
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

  // --- Context Menu ---
  function handleContextMenuAction(nodeKey: string, nodeType: 'leaf' | 'folder', itemKey: string, field?: string) {
    const payload: Record<string, unknown> = { item: itemKey, nodeKey, nodeType };
    if (field) payload.field = field;
    contextMenuAction?.(payload);
  }

  // --- Expand / Collapse ---
  function handleExpandChange(key: string, expanded: boolean) {
    const next = new Set(expandedKeys);
    if (expanded) {
      next.add(key);
    } else {
      for (const k of next) {
        if (k === key || k.startsWith(key + '-')) next.delete(k);
      }
    }
    expandedKeys = next;
  }

  function ancestorKeys(key: string): string[] {
    const parts = key.split('-');
    const ancestors: string[] = [];
    for (let i = 1; i < parts.length; i++) {
      ancestors.push(parts.slice(0, i).join('-'));
    }
    return ancestors;
  }

  // --- Sort handling ---
  function handleSort(field: string, direction: 'none' | 'asc' | 'desc') {
    sortField = field;
    sortDirection = direction;
    editingCell = null;
    sortChanged?.({ field, direction });
  }

  // --- Filter handling ---
  function handleFilterChange(field: string, filterValue: unknown) {
    if (filterValue == null || filterValue === '') {
      const next = { ...filters };
      delete next[field];
      filters = next;
    } else {
      filters = { ...filters, [field]: filterValue };
    }
    editingCell = null;
    filterChanged?.({ field, value: filterValue });
  }

  // --- Cell interaction ---
  function handleCellClick(key: string, field: string) {
    cellClicked?.({ key, field });
  }

  function handleCellDblClick(key: string, field: string) {
    // Start inline editing if column is editable
    const col = visibleColumns.find((c) => c.field === field);
    if (!col) return;
    // For expander column, check if editable
    const isExpander = field === expanderField;
    if (isExpander) {
      // Expander column editable only if column has editable=true
      if (!col.editable) return;
    } else {
      if (!col.editable) return;
      // Check type supports editing
      const editableTypes = new Set(['text', 'number', 'boolean', 'enum', 'rating', 'date', 'progressbar', 'color']);
      if (!editableTypes.has(col.type)) return;
    }
    editingCell = { key, field };
  }

  function handleCommitEdit(key: string, field: string, oldValue: unknown, newValue: unknown) {
    editingCell = null;
    publish?.('cellEdited', { key, field, oldValue, newValue });
  }

  function handleCancelEdit() {
    editingCell = null;
  }

  function handleCellAction(key: string, field: string, data: unknown) {
    publish?.('cellAction', { key, field, data });
  }

  function handleColumnResized(field: string, width: number) {
    publish?.('columnResized', { field, width });
  }

  // --- Container resize observer ---
  function observeWidth(el: HTMLDivElement) {
    containerWidth = el.clientWidth;
    const ro = new ResizeObserver((entries) => {
      for (const entry of entries) {
        containerWidth = entry.contentRect.width;
      }
    });
    ro.observe(el);
    return { destroy: () => ro.disconnect() };
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
    addNode = (data: { parentKey: string; label: string; icon?: unknown }): Resolution => {
      const parentKey = data.parentKey || '';
      const icon = normalizeIcon(data.icon);
      if (parentKey === '') {
        const key = `${treeState.length + 1}`;
        treeState = [...treeState, { key, name: data.label, icon, children: [] }];
      } else {
        const parent = findNodeByKey(treeState, parentKey);
        if (!parent) return { success: false, data: `Parent "${parentKey}" not found` };
        const key = `${parentKey}-${parent.children.length + 1}`;
        parent.children = [...parent.children, { key, name: data.label, icon, children: [] }];
        treeState = [...treeState];
      }
      return { success: true, data: null };
    };
    removeNode = (data: { key: string }): Resolution => {
      const { updated, removedKeys, keyMapping } = removeAndReindex(treeState, data.key);
      treeState = updated;
      const remapped = remapValues(valueList, removedKeys, keyMapping);
      value = remapped.length > 0 ? remapped : null;
      return { success: true, data: null };
    };
    updateNode = (data: { key: string; label?: string; icon?: unknown }): Resolution => {
      const node = findNodeByKey(treeState, data.key);
      if (!node) return { success: false, data: `Node "${data.key}" not found` };
      if (data.label != null) node.name = data.label;
      if (data.icon !== undefined) node.icon = normalizeIcon(data.icon);
      treeState = [...treeState];
      return { success: true, data: null };
    };
    expandNode = (data: { key: string }): Resolution => {
      const node = findNodeByKey(treeState, data.key);
      if (!node) return { success: false, data: `Node "${data.key}" not found` };
      const next = new Set(expandedKeys);
      for (const ak of ancestorKeys(data.key)) next.add(ak);
      if (node.children.length > 0) next.add(data.key);
      expandedKeys = next;
      return { success: true, data: null };
    };
    collapseNode = (data: { key: string }): Resolution => {
      const next = new Set(expandedKeys);
      for (const k of next) {
        if (k === data.key || k.startsWith(data.key + '-')) next.delete(k);
      }
      expandedKeys = next;
      return { success: true, data: null };
    };
    expandAll = (): Resolution => {
      expandedKeys = new Set(collectAllFolderKeys(treeState));
      return { success: true, data: null };
    };
    collapseAll = (): Resolution => {
      expandedKeys = new Set();
      return { success: true, data: null };
    };
    editCell = (data: { key: string; field: string; value: unknown }): Resolution => {
      const node = findNodeByKey(treeState, data.key) as TreeTableNode | null;
      if (!node) return { success: false, data: `Node "${data.key}" not found` };
      if (data.field === expanderField) {
        node.name = String(data.value);
      } else {
        if (!node.data) node.data = {};
        node.data[data.field] = data.value;
      }
      treeState = [...treeState];
      return { success: true, data: null };
    };
  });

  // Track leaf striped index
  function getStripedIndex(rows: FlatTreeRow[], idx: number): number {
    let leafIdx = 0;
    for (let i = 0; i < idx; i++) {
      if (!rows[i].isFolder) leafIdx++;
    }
    return leafIdx;
  }
</script>

<div
  bind:this={containerEl}
  class="ic-tt"
  class:ic-tt--sm={size === 'sm'}
  class:ic-tt--md={size === 'md'}
  class:ic-tt--lg={size === 'lg'}
  class:ic-tt--disabled={disabled}
  style:height={toSize(height)}
  role="treegrid"
  tabindex={disabled ? -1 : 0}
  use:observeWidth
>
  <div class="ic-tt__inner" style:min-width="{totalColumnWidth ? totalColumnWidth + 'px' : '100%'}">
    <!-- Column headers -->
    <TableHeader
      columns={visibleColumns}
      bind:columnWidths
      {sortField}
      {sortDirection}
      {filters}
      {disabled}
      totalRowCount={totalLeafCount}
      {filterMatchCounts}
      onsort={handleSort}
      onfilterchange={handleFilterChange}
      oncolumnresized={handleColumnResized}
    />

    <!-- Tree body -->
    <div bind:this={bodyEl} class="ic-tt__body">
      {#each flatRows as row, fi (row.key)}
        <TreeTableRow
          {row}
          columns={visibleColumns}
          {columnWidths}
          {expanderField}
          {nameField}
          {size}
          {showLine}
          {disabled}
          {selectable}
          selected={selectedSet.has(row.key)}
          {atMaxSelections}
          {striped}
          stripedIndex={getStripedIndex(flatRows, fi)}
          {editingCell}
          ontoggleselect={toggleItem}
          ontoggleexpand={handleExpandChange}
          oncelldblclick={handleCellDblClick}
          oncellclick={handleCellClick}
          oncommitedit={handleCommitEdit}
          oncanceledit={handleCancelEdit}
          oncellaction={handleCellAction}
          {leafContextMenu}
          {folderContextMenu}
          oncontextmenuaction={handleContextMenuAction}
        />
      {/each}

      {#if flatRows.length === 0}
        <div class="ic-tt__empty">No items</div>
      {/if}
    </div>
  </div>
</div>

<style>
  /* ═══════ ROOT — matches Table.svelte .ic-tbl ═══════ */
  .ic-tt {
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: auto;
    background: var(--ic-background);
    width: 100%;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.02);
  }
  .ic-tt:focus {
    outline: none;
    border-color: var(--ic-primary);
  }
  .ic-tt--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Inner wrapper — enforces total column width so all rows
     (including folder rows) span the full width on horizontal scroll */
  .ic-tt__inner {
    display: flex;
    flex-direction: column;
  }

  /* Body */
  .ic-tt__body {
    display: flex;
    flex-direction: column;
  }

  /* Size: row heights + font — match Table pattern */
  .ic-tt--sm :global(.ic-tt__row),
  .ic-tt--sm :global(.ic-tbl__header) {
    min-height: 24px;
    font-size: 0.7rem;
  }
  .ic-tt--md :global(.ic-tt__row),
  .ic-tt--md :global(.ic-tbl__header) {
    min-height: 28px;
    font-size: 0.75rem;
  }
  .ic-tt--lg :global(.ic-tt__row),
  .ic-tt--lg :global(.ic-tbl__header) {
    min-height: 36px;
    font-size: 0.8125rem;
  }

  /* Empty state */
  .ic-tt__empty {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    font-size: 0.75rem;
  }
</style>
