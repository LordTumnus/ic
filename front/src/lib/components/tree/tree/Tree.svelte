<script lang="ts">
  import type { Resolution } from '$lib/types';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import { toSize } from '$lib/utils/css';
  import TreeNode from './TreeNode.svelte';
  import {
    type TreeNode as TreeNodeData,
    normalizeNodes,
    normalizeIcon,
    buildKeyMap,
    findNodeByKey,
    collectAllFolderKeys,
    removeAndReindex,
    remapValues,
  } from '$lib/utils/tree-utils';

  // --- Props ---
  let {
    id = '',
    items = $bindable<TreeNodeData[] | TreeNodeData | null>([]),
    value = $bindable<string[] | string | null>(null),
    disabled = $bindable(false),
    selectable = $bindable(true),
    size = $bindable('md'),
    maxSelectedItems = $bindable<number | null>(null),
    height = $bindable<number | string>(400),
    showLine = $bindable(true),
    lazyLoad = $bindable(true),
    // Context menus
    leafContextMenu = $bindable<ContextMenuEntry[]>([]),
    folderContextMenu = $bindable<ContextMenuEntry[]>([]),
    // Events
    valueChanged,
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
  }: {
    id?: string;
    items?: TreeNodeData[] | TreeNodeData | null;
    value?: string[] | string | null;
    disabled?: boolean;
    selectable?: boolean;
    size?: string;
    maxSelectedItems?: number | null;
    height?: number | string;
    showLine?: boolean;
    lazyLoad?: boolean;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    valueChanged?: (data?: unknown) => void;
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
  } = $props();

  // --- Refs ---
  let containerEl: HTMLDivElement;

  // --- State ---
  let expandedKeys = $state(new Set<string>());

  // --- Tree state ---
  let treeState = $state<TreeNodeData[]>([]);
  $effect(() => { treeState = normalizeNodes(items); });

  const keyMap = $derived(buildKeyMap(treeState));

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
      if (atMaxSelections) return;
      next = [...valueList, key];
    }
    value = next.length > 0 ? next : null;
    valueChanged?.({ value });
  }

  // --- Expand / Collapse ---
  function handleContextMenuAction(nodeKey: string, nodeType: 'leaf' | 'folder', itemKey: string) {
    contextMenuAction?.({ item: itemKey, nodeKey, nodeType });
  }

  function handleExpandChange(key: string, expanded: boolean) {
    const next = new Set(expandedKeys);
    if (expanded) {
      next.add(key);
    } else {
      // Remove key and all descendant keys
      for (const k of next) {
        if (k === key || k.startsWith(key + '-')) next.delete(k);
      }
    }
    expandedKeys = next;
  }

  /** Compute all ancestor keys leading to `key` (exclusive). */
  function ancestorKeys(key: string): string[] {
    const parts = key.split('-');
    const ancestors: string[] = [];
    for (let i = 1; i < parts.length; i++) {
      ancestors.push(parts.slice(0, i).join('-'));
    }
    return ancestors;
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
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div {id}
  bind:this={containerEl}
  class="ic-tree"
  class:ic-tree--sm={size === 'sm'}
  class:ic-tree--md={size === 'md'}
  class:ic-tree--lg={size === 'lg'}
  class:ic-tree--disabled={disabled}
  role="tree"
  tabindex={disabled ? -1 : 0}
>
  <div class="ic-tree__list" style="height: {toSize(height)}">
    {#each treeState as node, i (node.key)}
      <TreeNode
        {node}
        depth={0}
        {size}
        {selectable}
        {disabled}
        {showLine}
        {lazyLoad}
        isLast={i === treeState.length - 1}
        parentLines={[]}
        {expandedKeys}
        isItemSelected={isSelected}
        {atMaxSelections}
        {leafContextMenu}
        {folderContextMenu}
        ontoggle={toggleItem}
        onexpandchange={handleExpandChange}
        oncontextmenuaction={handleContextMenuAction}
      />
    {/each}

    {#if treeState.length === 0}
      <div class="ic-tree__empty">No items</div>
    {/if}
  </div>
</div>

<style>
  /* ===== ROOT ===== */
  .ic-tree {
    display: inline-flex;
    flex-direction: column;
    width: 100%;
    font-family: inherit;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    outline: none;
  }

  .ic-tree:focus {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-tree--disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background: var(--ic-muted);
    pointer-events: none;
  }

  /* ===== SIZES ===== */
  .ic-tree--sm { font-size: 0.75rem; }
  .ic-tree--md { font-size: 0.8125rem; }
  .ic-tree--lg { font-size: 0.9375rem; }

  /* ===== LIST ===== */
  .ic-tree__list {
    overflow-y: auto;
    padding: 2px 0;
  }

  .ic-tree__list::-webkit-scrollbar { width: 4px; }
  .ic-tree__list::-webkit-scrollbar-track { background: transparent; }
  .ic-tree__list::-webkit-scrollbar-thumb { background: var(--ic-border); border-radius: 2px; }

  /* ===== EMPTY ===== */
  .ic-tree__empty {
    padding: 0.75rem 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }
</style>
