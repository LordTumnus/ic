<script lang="ts">
  import type { Resolution } from '$lib/types';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import logger from '$lib/core/logger';
  import { toSize } from '$lib/utils/css';
  import SearchBar from '$lib/components/form/searchBar/SearchBar.svelte';
  import TreeNode from '$lib/components/display/tree/TreeNode.svelte';
  import {
    type TreeNode as TreeNodeData,
    normalizeNodes,
    normalizeIcon,
    findNodeByKey,
    collectAllFolderKeys,
    removeAndReindex,
    remapValues,
  } from '$lib/utils/tree-utils';
  import {
    FILTER_TRIGGERS,
    parseFilters,
    isEmptyFilter,
    filterTree,
    getMatchingAncestorKeys,
    buildHighlightRegex,
  } from '$lib/utils/filter-tree-utils';

  // --- Props ---
  let {
    items = $bindable<TreeNodeData[] | TreeNodeData | null>([]),
    value = $bindable<string[] | string | null>(null),
    searchValue = $bindable<string[] | string | null>(null),
    disabled = $bindable(false),
    selectable = $bindable(true),
    size = $bindable('md'),
    maxSelectedItems = $bindable<number | null>(null),
    height = $bindable<number | string>(400),
    showLine = $bindable(true),
    lazyLoad = $bindable(true),
    placeholder = $bindable('Search...'),
    clearable = $bindable(true),
    caseSensitive = $bindable(false),
    autoExpand = $bindable(true),
    // Context menus
    leafContextMenu = $bindable<ContextMenuEntry[]>([]),
    folderContextMenu = $bindable<ContextMenuEntry[]>([]),
    // Events
    valueChanged,
    searchChanged,
    contextMenuAction,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clearSearch = $bindable((): Resolution => ({ success: true, data: null })),
    addNode = $bindable((_data: { parentKey: string; label: string; icon?: unknown }): Resolution => ({ success: true, data: null })),
    removeNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    updateNode = $bindable((_data: { key: string; label?: string; icon?: unknown }): Resolution => ({ success: true, data: null })),
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    expandNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    collapseNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    expandAll = $bindable((): Resolution => ({ success: true, data: null })),
    collapseAll = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    items?: TreeNodeData[] | TreeNodeData | null;
    value?: string[] | string | null;
    searchValue?: string[] | string | null;
    disabled?: boolean;
    selectable?: boolean;
    size?: string;
    maxSelectedItems?: number | null;
    height?: number | string;
    showLine?: boolean;
    lazyLoad?: boolean;
    placeholder?: string;
    clearable?: boolean;
    caseSensitive?: boolean;
    autoExpand?: boolean;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    valueChanged?: (data?: unknown) => void;
    searchChanged?: (data?: unknown) => void;
    contextMenuAction?: (data?: unknown) => void;
    focus?: () => Resolution;
    clearSearch?: () => Resolution;
    addNode?: (data: { parentKey: string; label: string; icon?: unknown }) => Resolution;
    removeNode?: (data: { key: string }) => Resolution;
    updateNode?: (data: { key: string; label?: string; icon?: unknown }) => Resolution;
    clearSelection?: () => Resolution;
    expandNode?: (data: { key: string }) => Resolution;
    collapseNode?: (data: { key: string }) => Resolution;
    expandAll?: () => Resolution;
    collapseAll?: () => Resolution;
  } = $props();

  // --- Refs ---
  let containerEl: HTMLDivElement;
  let searchBarFocus = $state<() => Resolution>(() => ({ success: true, data: null }));
  let searchBarClear = $state<() => Resolution>(() => ({ success: true, data: null }));

  // --- State ---
  let expandedKeys = $state(new Set<string>());

  // --- Full tree state (from MATLAB items) ---
  let treeState = $state<TreeNodeData[]>([]);
  $effect(() => {
    const nodes = normalizeNodes(items);
    logger.info('FilterTree', 'Items normalized', { count: nodes.length });
    treeState = nodes;
  });

  // --- Search tags ---
  const searchTags = $derived.by((): string[] => {
    if (searchValue == null) return [];
    if (Array.isArray(searchValue)) return searchValue.filter((v) => v !== '' && v != null);
    if (searchValue === '') return [];
    return [searchValue];
  });

  // --- Parsed filters ---
  const filterGroups = $derived(parseFilters(searchTags));
  const hasActiveFilter = $derived(!isEmptyFilter(filterGroups));
  const highlightRegex = $derived(hasActiveFilter ? buildHighlightRegex(filterGroups, caseSensitive) : null);

  // --- Filtered tree (only when filter is active) ---
  const displayTree = $derived.by(() => {
    if (!hasActiveFilter) return treeState;
    const filtered = filterTree(treeState, filterGroups, caseSensitive);
    logger.debug('FilterTree', 'Filter applied', { tags: searchTags, matchCount: filtered.length });
    return filtered;
  });

  // --- Auto-expand matching ancestors ---
  $effect(() => {
    if (hasActiveFilter && autoExpand) {
      const ancestorKeys = getMatchingAncestorKeys(
        treeState,
        filterGroups,
        caseSensitive
      );
      // Also expand all folders in the filtered tree (they survived because descendants matched)
      const folderKeys = collectAllFolderKeys(displayTree);
      expandedKeys = new Set([...ancestorKeys, ...folderKeys]);
    }
  });

  // --- Value helpers ---
  const valueList = $derived.by((): string[] => {
    if (value == null) return [];
    if (Array.isArray(value)) return value.filter((v) => v !== '' && v != null);
    if (value === '') return [];
    return [value];
  });

  const atMaxSelections = $derived(
    maxSelectedItems != null && valueList.length >= maxSelectedItems
  );

  function isSelected(key: string): boolean {
    return valueList.includes(key);
  }

  // --- Selection ---
  function toggleItem(key: string) {
    let next: string[];
    if (isSelected(key)) {
      next = valueList.filter((v) => v !== key);
    } else {
      if (atMaxSelections) {
        logger.debug('FilterTree', 'Toggle blocked — max selections reached', { key, max: maxSelectedItems });
        return;
      }
      next = [...valueList, key];
    }
    value = next.length > 0 ? next : null;
    logger.debug('FilterTree', 'Toggle selection', { key, value });
    valueChanged?.({ value });
  }

  // --- Context Menu ---
  function handleContextMenuAction(nodeKey: string, nodeType: 'leaf' | 'folder', itemKey: string) {
    contextMenuAction?.({ item: itemKey, nodeKey, nodeType });
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

  function ancestorKeysOf(key: string): string[] {
    const parts = key.split('-');
    const ancestors: string[] = [];
    for (let i = 1; i < parts.length; i++) {
      ancestors.push(parts.slice(0, i).join('-'));
    }
    return ancestors;
  }

  // --- Search event handler ---
  function handleSearchValueChanged() {
    logger.debug('FilterTree', 'Search changed', { searchValue });
    searchChanged?.({ value: searchValue });
  }

  // --- Methods ---
  $effect(() => {
    focus = (): Resolution => {
      searchBarFocus?.();
      return { success: true, data: null };
    };
    clearSearch = (): Resolution => {
      searchValue = null;
      searchBarClear?.();
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
      for (const ak of ancestorKeysOf(data.key)) next.add(ak);
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
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={containerEl}
  class="ic-ft"
  class:ic-ft--sm={size === 'sm'}
  class:ic-ft--md={size === 'md'}
  class:ic-ft--lg={size === 'lg'}
  class:ic-ft--disabled={disabled}
  role="tree"
  tabindex={disabled ? -1 : 0}
>
  <!-- Search bar (internal, not exposed to MATLAB as a child) -->
  <div class="ic-ft__search">
    <SearchBar
      bind:value={searchValue}
      {placeholder}
      {disabled}
      clearable={clearable}
      {size}
      variant="secondary"
      separator=","
      iconTriggers={FILTER_TRIGGERS}
      valueChanged={handleSearchValueChanged}
      bind:focus={searchBarFocus}
      bind:clear={searchBarClear}
    />
  </div>

  <!-- Tree panel -->
  <div class="ic-ft__tree" style="height: {toSize(height)}">
    {#each displayTree as node, i (node.key)}
      <TreeNode
        {node}
        depth={0}
        {size}
        {selectable}
        {disabled}
        {showLine}
        {lazyLoad}
        isLast={i === displayTree.length - 1}
        parentLines={[]}
        {expandedKeys}
        isItemSelected={isSelected}
        {atMaxSelections}
        {highlightRegex}
        {leafContextMenu}
        {folderContextMenu}
        ontoggle={toggleItem}
        onexpandchange={handleExpandChange}
        oncontextmenuaction={handleContextMenuAction}
      />
    {/each}

    {#if displayTree.length === 0}
      <div class="ic-ft__empty">
        {hasActiveFilter ? 'No matches' : 'No items'}
      </div>
    {/if}
  </div>
</div>

<style>
  /* ===== ROOT ===== */
  .ic-ft {
    display: inline-flex;
    flex-direction: column;
    gap: 6px;
    width: 100%;
    font-family: inherit;
    outline: none;
  }

  .ic-ft--disabled {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* ===== SIZES ===== */
  .ic-ft--sm { font-size: 0.75rem; }
  .ic-ft--md { font-size: 0.8125rem; }
  .ic-ft--lg { font-size: 0.9375rem; }

  /* ===== SHARED PANEL FRAME ===== */
  .ic-ft__search,
  .ic-ft__tree {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
  }

  /* ===== SEARCH BAR AREA ===== */
  .ic-ft__search {
    flex-shrink: 0;
  }

  .ic-ft__search :global(.ic-sb) {
    width: 100%;
  }
  .ic-ft__search :global(.ic-sb__field) {
    border: none;
    border-radius: 0;
    box-shadow: none;
    background: transparent;
  }
  .ic-ft__search :global(.ic-sb__field--focused) {
    border: none;
    box-shadow: none;
  }

  /* ===== TREE PANEL ===== */
  .ic-ft__tree {
    overflow-y: auto;
    padding: 2px 0;
  }

  .ic-ft__tree::-webkit-scrollbar { width: 4px; }
  .ic-ft__tree::-webkit-scrollbar-track { background: transparent; }
  .ic-ft__tree::-webkit-scrollbar-thumb { background: var(--ic-border); border-radius: 2px; }

  /* ===== EMPTY STATE ===== */
  .ic-ft__empty {
    padding: 0.75rem 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }
</style>
