<script lang="ts">
  import type { Resolution } from '$lib/types';
  import Tag from '$lib/components/shared/Tag.svelte';
  import TreePanel from './TreePanel.svelte';
  import { resolveIconType, type IconTypeData } from '$lib/utils/icons';

  // --- Types ---
  interface TreeNode {
    key: string;
    name: string;
    icon?: string | IconTypeData;
    children: TreeNode[];
  }

  interface FlatNode {
    key: string;
    name: string;
    icon?: string | IconTypeData;
    path: string[];
  }

  const ICON_SIZES: Record<string, number> = { sm: 10, md: 12, lg: 14 };

  function resolveIcon(icon: string | IconTypeData | undefined, sz: string): string {
    return resolveIconType(icon, ICON_SIZES[sz] ?? 12);
  }

  // --- Props ---
  let {
    items = $bindable<TreeNode[] | TreeNode | null>([]),
    value = $bindable<string[] | string | null>(null),
    placeholder = $bindable('Select...'),
    disabled = $bindable(false),
    clearable = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    maxPopupHeight = $bindable(200),
    maxSelectedItems = $bindable<number | null>(null),
    maxPanelWidth = $bindable(240),
    openOnHover = $bindable(false),
    // Events
    valueChanged,
    opened,
    closed,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clear = $bindable((): Resolution => ({ success: true, data: null })),
    open = $bindable((): Resolution => ({ success: true, data: null })),
    close = $bindable((): Resolution => ({ success: true, data: null })),
    addNode = $bindable((_data: { parentKey: string; label: string; icon?: unknown }): Resolution => ({ success: true, data: null })),
    removeNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    updateNode = $bindable((_data: { key: string; label?: string; icon?: unknown }): Resolution => ({ success: true, data: null })),
  }: {
    items?: TreeNode[] | TreeNode | null;
    value?: string[] | string | null;
    placeholder?: string;
    disabled?: boolean;
    clearable?: boolean;
    size?: string;
    variant?: string;
    maxPopupHeight?: number;
    maxSelectedItems?: number | null;
    maxPanelWidth?: number;
    openOnHover?: boolean;
    valueChanged?: (data?: unknown) => void;
    opened?: (data?: unknown) => void;
    closed?: (data?: unknown) => void;
    focus?: () => Resolution;
    clear?: () => Resolution;
    open?: () => Resolution;
    close?: () => Resolution;
    addNode?: (data: { parentKey: string; label: string; icon?: unknown }) => Resolution;
    removeNode?: (data: { key: string }) => Resolution;
    updateNode?: (data: { key: string; label?: string; icon?: unknown }) => Resolution;
  } = $props();

  // --- Refs ---
  let rootEl: HTMLDivElement;
  let inputEl: HTMLInputElement;
  let searchOptionEls: HTMLDivElement[] = [];

  // --- State ---
  let isOpen = $state(false);
  let isFocused = $state(false);
  let searchQuery = $state('');
  let focusedTagIndex = $state(-1);
  let removingIndex = $state(-1);
  let searchFocusedIndex = $state(-1);

  // --- Normalize ic.tree.Node serialization (positional keys) ---
  function normalizeNodes(raw: unknown, prefix = ''): TreeNode[] {
    if (raw == null) return [];
    if (!Array.isArray(raw)) raw = [raw];
    return (raw as Record<string, unknown>[]).map((n, i) => {
      const key = prefix ? `${prefix}-${i + 1}` : `${i + 1}`;
      return {
        key,
        name: String(n.label ?? ''),
        icon: normalizeIcon(n.icon),
        children: normalizeNodes(n.children, key),
      };
    });
  }

  function normalizeIcon(raw: unknown): string | IconTypeData | undefined {
    if (raw == null) return undefined;
    if (typeof raw === 'string') return raw || undefined;
    if (typeof raw === 'object' && 'type' in (raw as object))
      return raw as IconTypeData;
    return undefined;
  }

  // --- Tree helpers ---
  function buildKeyMap(nodes: TreeNode[]): Map<string, { name: string; icon?: string | IconTypeData }> {
    const map = new Map<string, { name: string; icon?: string | IconTypeData }>();
    function walk(list: TreeNode[]) {
      for (const n of list) {
        map.set(n.key, { name: n.name, icon: n.icon });
        if (n.children.length > 0) walk(n.children);
      }
    }
    walk(nodes);
    return map;
  }

  /** Flatten tree to leaf nodes only (folders excluded from search) */
  function flattenLeaves(nodes: TreeNode[], path: string[] = []): FlatNode[] {
    const out: FlatNode[] = [];
    for (const n of nodes) {
      if (n.children.length > 0) {
        // Folder: recurse into children, adding this node's name to the path
        out.push(...flattenLeaves(n.children, [...path, n.name]));
      } else {
        // Leaf: include in results
        out.push({ key: n.key, name: n.name, icon: n.icon, path });
      }
    }
    return out;
  }

  // --- Mutable tree state (reset on full items change, mutated by ops) ---
  let treeState = $state<TreeNode[]>([]);
  $effect(() => { treeState = normalizeNodes(items); });

  const keyMap = $derived(buildKeyMap(treeState));

  const valueList = $derived.by((): string[] => {
    if (value == null) return [];
    if (Array.isArray(value)) return value.filter((v) => v !== '' && v != null);
    if (value === '') return [];
    return [value];
  });

  const hasValue = $derived(valueList.length > 0);
  const showClear = $derived(clearable && hasValue && !disabled);
  const atMaxSelections = $derived(
    maxSelectedItems != null && valueList.length >= maxSelectedItems
  );
  const isSearchMode = $derived(searchQuery.length > 0);

  const allLeaves = $derived(flattenLeaves(treeState));
  const filteredFlat = $derived.by(() => {
    if (!searchQuery) return [];
    const q = searchQuery.toLowerCase();
    return allLeaves.filter((n) => n.name.toLowerCase().includes(q));
  });

  function isSelected(key: string): boolean {
    return valueList.includes(key);
  }

  // --- Open / Close ---
  function openDropdown() {
    if (disabled || isOpen) return;
    isOpen = true;
    searchQuery = '';
    searchFocusedIndex = -1;
    opened?.();
    requestAnimationFrame(() => {
      document.addEventListener('pointerdown', onClickOutside);
      inputEl?.focus();
    });
  }

  function closeDropdown() {
    if (!isOpen) return;
    isOpen = false;
    searchQuery = '';
    searchFocusedIndex = -1;
    closed?.();
    document.removeEventListener('pointerdown', onClickOutside);
  }

  function onClickOutside(e: PointerEvent) {
    if (rootEl && !rootEl.contains(e.target as Node)) {
      closeDropdown();
    }
  }

  // --- Selection: single leaf toggle ---
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
    requestAnimationFrame(() => inputEl?.focus());
  }

  // --- Selection: folder toggle (all leaf descendants) ---
  function toggleLeaves(leafKeys: string[]) {
    const allSelected = leafKeys.every((k) => isSelected(k));
    let next: string[];
    if (allSelected) {
      // Deselect all leaves in this folder
      const removeSet = new Set(leafKeys);
      next = valueList.filter((v) => !removeSet.has(v));
    } else {
      // Select all not-yet-selected leaves (respect max)
      const toAdd = leafKeys.filter((k) => !isSelected(k));
      next = [...valueList, ...toAdd];
      if (maxSelectedItems != null && next.length > maxSelectedItems) {
        next = next.slice(0, maxSelectedItems);
      }
    }
    value = next.length > 0 ? next : null;
    valueChanged?.({ value });
    requestAnimationFrame(() => inputEl?.focus());
  }

  // --- Tag management ---
  function handleTagRemoved(key: string) {
    const next = valueList.filter((v) => v !== key);
    value = next.length > 0 ? next : null;
    valueChanged?.({ value });
    if (removingIndex >= 0) {
      removingIndex = -1;
      if (valueList.length === 0) {
        focusedTagIndex = -1;
        inputEl?.focus();
      } else if (focusedTagIndex >= valueList.length) {
        focusedTagIndex = valueList.length - 1;
      }
    }
  }

  function handleClearAll(e: Event) {
    e.stopPropagation();
    value = null;
    valueChanged?.({ value: null });
    searchQuery = '';
    inputEl?.focus();
  }

  function swapTags(from: number, to: number) {
    if (to < 0 || to >= valueList.length) return;
    const arr = valueList.slice();
    const tmp = arr[from];
    arr[from] = arr[to];
    arr[to] = tmp;
    value = arr;
    focusedTagIndex = to;
  }

  // --- Keyboard: search input ---
  function handleInputKeydown(e: KeyboardEvent) {
    if (focusedTagIndex >= 0) return;

    if (isSearchMode) {
      handleSearchKeydown(e);
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
      case 'ArrowUp':
        e.preventDefault();
        if (!isOpen) openDropdown();
        break;
      case 'Escape':
        if (isOpen) { e.preventDefault(); closeDropdown(); }
        break;
      case 'Backspace':
        if (searchQuery === '' && valueList.length > 0) {
          e.preventDefault();
          focusedTagIndex = valueList.length - 1;
        }
        break;
      case 'Tab':
        if (isOpen) closeDropdown();
        break;
    }
  }

  function handleSearchKeydown(e: KeyboardEvent) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        if (!isOpen) { openDropdown(); return; }
        if (filteredFlat.length > 0) {
          searchFocusedIndex = searchFocusedIndex < filteredFlat.length - 1
            ? searchFocusedIndex + 1 : 0;
          scrollSearchOption();
        }
        break;
      case 'ArrowUp':
        e.preventDefault();
        if (!isOpen) { openDropdown(); return; }
        if (filteredFlat.length > 0) {
          searchFocusedIndex = searchFocusedIndex > 0
            ? searchFocusedIndex - 1 : filteredFlat.length - 1;
          scrollSearchOption();
        }
        break;
      case 'Enter':
        if (isOpen && searchFocusedIndex >= 0 && searchFocusedIndex < filteredFlat.length) {
          e.preventDefault();
          toggleItem(filteredFlat[searchFocusedIndex].key);
        }
        break;
      case 'Escape':
        if (isOpen) { e.preventDefault(); closeDropdown(); }
        break;
      case 'Backspace':
        if (searchQuery === '' && valueList.length > 0) {
          e.preventDefault();
          focusedTagIndex = valueList.length - 1;
        }
        break;
      case 'Home':
        if (isOpen && filteredFlat.length > 0) {
          e.preventDefault();
          searchFocusedIndex = 0;
          scrollSearchOption();
        }
        break;
      case 'End':
        if (isOpen && filteredFlat.length > 0) {
          e.preventDefault();
          searchFocusedIndex = filteredFlat.length - 1;
          scrollSearchOption();
        }
        break;
      case 'Tab':
        if (isOpen) closeDropdown();
        break;
    }
  }

  function scrollSearchOption() {
    requestAnimationFrame(() => {
      searchOptionEls[searchFocusedIndex]?.scrollIntoView({ block: 'nearest' });
    });
  }

  function handleTagKeydown(e: KeyboardEvent) {
    if (focusedTagIndex < 0) return;

    switch (e.key) {
      case 'ArrowLeft':
        e.preventDefault();
        if (e.shiftKey) swapTags(focusedTagIndex, focusedTagIndex - 1);
        else if (focusedTagIndex > 0) focusedTagIndex--;
        break;
      case 'ArrowRight':
        e.preventDefault();
        if (e.shiftKey) swapTags(focusedTagIndex, focusedTagIndex + 1);
        else if (focusedTagIndex < valueList.length - 1) focusedTagIndex++;
        else { focusedTagIndex = -1; inputEl?.focus(); }
        break;
      case 'Delete':
      case 'Backspace':
        e.preventDefault();
        if (removingIndex < 0) removingIndex = focusedTagIndex;
        break;
      case 'Escape':
        e.preventDefault();
        focusedTagIndex = -1;
        inputEl?.focus();
        break;
      default:
        if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
          focusedTagIndex = -1;
          inputEl?.focus();
        }
    }
  }

  $effect(() => {
    const _ = filteredFlat;
    searchFocusedIndex = -1;
  });

  function handleFieldClick() {
    if (disabled) return;
    if (!isOpen) openDropdown();
    focusedTagIndex = -1;
    inputEl?.focus();
  }

  // --- Tree op helpers ---
  function findNodeByKey(nodes: TreeNode[], key: string): TreeNode | null {
    for (const n of nodes) {
      if (n.key === key) return n;
      const found = findNodeByKey(n.children, key);
      if (found) return found;
    }
    return null;
  }

  function collectAllKeys(node: TreeNode): string[] {
    const keys = [node.key];
    for (const c of node.children) keys.push(...collectAllKeys(c));
    return keys;
  }

  function reindexSubtree(node: TreeNode, newKey: string): TreeNode {
    return {
      ...node,
      key: newKey,
      children: node.children.map((c, i) =>
        reindexSubtree(c, `${newKey}-${i + 1}`)
      ),
    };
  }

  function removeAndReindex(
    nodes: TreeNode[],
    key: string
  ): { updated: TreeNode[]; removedKeys: Set<string>; keyMapping: Map<string, string> } {
    const parts = key.split('-');
    const removedKeys = new Set<string>();
    const keyMapping = new Map<string, string>();

    function recurse(list: TreeNode[], depth: number, prefix: string): TreeNode[] {
      const targetIdx = parseInt(parts[depth], 10) - 1;
      if (depth === parts.length - 1) {
        // This is the level where the node lives
        const removed = list[targetIdx];
        if (removed) {
          for (const k of collectAllKeys(removed)) removedKeys.add(k);
        }
        const after = [...list.slice(0, targetIdx), ...list.slice(targetIdx + 1)];
        // Reindex siblings after the removed index
        return after.map((n, i) => {
          const newKey = prefix ? `${prefix}-${i + 1}` : `${i + 1}`;
          if (n.key !== newKey) {
            const old = n.key;
            const reindexed = reindexSubtree(n, newKey);
            // Map old keys to new keys for the shifted siblings
            mapShiftedKeys(n, reindexed, keyMapping);
            return reindexed;
          }
          return n;
        });
      }
      // Recurse into the correct child
      return list.map((n, i) => {
        if (i === targetIdx) {
          return {
            ...n,
            children: recurse(n.children, depth + 1, n.key),
          };
        }
        return n;
      });
    }

    const updated = recurse(nodes, 0, '');
    return { updated, removedKeys, keyMapping };
  }

  function mapShiftedKeys(oldNode: TreeNode, newNode: TreeNode, mapping: Map<string, string>) {
    if (oldNode.key !== newNode.key) mapping.set(oldNode.key, newNode.key);
    for (let i = 0; i < oldNode.children.length; i++) {
      mapShiftedKeys(oldNode.children[i], newNode.children[i], mapping);
    }
  }

  function remapValues(
    vals: string[],
    removedKeys: Set<string>,
    keyMapping: Map<string, string>
  ): string[] {
    return vals
      .filter((v) => !removedKeys.has(v))
      .map((v) => keyMapping.get(v) ?? v);
  }

  // --- Methods ---
  $effect(() => {
    focus = (): Resolution => {
      inputEl?.focus();
      return { success: true, data: null };
    };
    clear = (): Resolution => {
      value = null;
      valueChanged?.({ value: null });
      searchQuery = '';
      return { success: true, data: null };
    };
    open = (): Resolution => {
      openDropdown();
      return { success: true, data: null };
    };
    close = (): Resolution => {
      closeDropdown();
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
        treeState = [...treeState]; // trigger reactivity
      }
      return { success: true, data: null };
    };
    removeNode = (data: { key: string }): Resolution => {
      const { updated, removedKeys, keyMapping } = removeAndReindex(treeState, data.key);
      treeState = updated;
      // Remap selected values
      const remapped = remapValues(valueList, removedKeys, keyMapping);
      value = remapped.length > 0 ? remapped : null;
      return { success: true, data: null };
    };
    updateNode = (data: { key: string; label?: string; icon?: unknown }): Resolution => {
      const node = findNodeByKey(treeState, data.key);
      if (!node) return { success: false, data: `Node "${data.key}" not found` };
      if (data.label != null) node.name = data.label;
      if (data.icon !== undefined) node.icon = normalizeIcon(data.icon);
      treeState = [...treeState]; // trigger reactivity
      return { success: true, data: null };
    };
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={rootEl}
  class="ic-ts"
  class:ic-ts--sm={size === 'sm'}
  class:ic-ts--md={size === 'md'}
  class:ic-ts--lg={size === 'lg'}
  class:ic-ts--disabled={disabled}
  class:ic-ts--open={isOpen}
  onkeydown={focusedTagIndex >= 0 ? handleTagKeydown : undefined}
>
  <!-- Field -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_role_has_required_aria_props -->
  <div
    class="ic-ts__field"
    class:ic-ts__field--primary={variant === 'primary'}
    class:ic-ts__field--secondary={variant === 'secondary'}
    class:ic-ts__field--focused={isFocused}
    role="combobox"
    tabindex={disabled ? -1 : 0}
    aria-expanded={isOpen}
    aria-haspopup="listbox"
    onclick={handleFieldClick}
  >
    <div class="ic-ts__tags-area">
      {#each valueList as tagKey, i (tagKey)}
        {@const info = keyMap.get(tagKey)}
        <Tag
          label={info?.name ?? tagKey}
          icon={info?.icon ?? ''}
          {size}
          {disabled}
          active={focusedTagIndex === i}
          removing={removingIndex === i}
          onremove={() => handleTagRemoved(tagKey)}
        />
      {/each}

      <input
        bind:this={inputEl}
        class="ic-ts__input"
        type="text"
        placeholder={hasValue ? '' : placeholder}
        autocomplete="off"
        {disabled}
        bind:value={searchQuery}
        oninput={() => { if (searchQuery && !isOpen) openDropdown(); }}
        onkeydown={handleInputKeydown}
        onfocus={() => { isFocused = true; }}
        onblur={() => { isFocused = false; }}
      />
    </div>

    <span class="ic-ts__actions">
      {#if showClear}
        <button
          class="ic-ts__clear-btn"
          tabindex={-1}
          aria-label="Clear all"
          onclick={handleClearAll}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M10.5 3.5L3.5 10.5M3.5 3.5L10.5 10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      {/if}

      <span class="ic-ts__arrow" class:ic-ts__arrow--open={isOpen}>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M3 4.5L6 7.5L9 4.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </span>
    </span>
  </div>

  <!-- Dropdown -->
  {#if isOpen}
    {#if isSearchMode}
      <!-- Flat search results (leaves only) -->
      <div class="ic-ts__dropdown">
        <div class="ic-ts__search-list" style="max-height: {maxPopupHeight}px;">
          {#each filteredFlat as node, i (node.key)}
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <div
              bind:this={searchOptionEls[i]}
              class="ic-ts__search-item"
              class:ic-ts__search-item--selected={isSelected(node.key)}
              class:ic-ts__search-item--focused={i === searchFocusedIndex}
              class:ic-ts__search-item--disabled={atMaxSelections && !isSelected(node.key)}
              role="option"
              tabindex={-1}
              aria-selected={isSelected(node.key)}
              onclick={() => toggleItem(node.key)}
              onpointerenter={() => { searchFocusedIndex = i; }}
            >
              <span class="ic-ts__check" class:ic-ts__check--on={isSelected(node.key)}>
                {#if isSelected(node.key)}
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                    <path d="M2 5L4 7L8 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                {/if}
              </span>

              {#if node.icon}
                {@const svg = resolveIcon(node.icon, size)}
                {#if svg}
                  <span class="ic-ts__search-icon">{@html svg}</span>
                {/if}
              {/if}

              <div class="ic-ts__search-content">
                <span class="ic-ts__search-label">{node.name}</span>
                {#if node.path.length > 0}
                  <span class="ic-ts__search-path">{node.path.join(' > ')}</span>
                {/if}
              </div>
            </div>
          {:else}
            <div class="ic-ts__empty">No results</div>
          {/each}
        </div>
      </div>
    {:else}
      <!-- Cascading tree panels (flex row, scrolls horizontally) -->
      <div class="ic-ts__cascade">
        <TreePanel
          nodes={treeState}
          {size}
          maxHeight={maxPopupHeight}
          {maxPanelWidth}
          {openOnHover}
          isItemSelected={isSelected}
          {atMaxSelections}
          ontoggle={toggleItem}
          ontogglefolder={toggleLeaves}
        />
      </div>
    {/if}
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-ts {
    display: inline-flex;
    flex-direction: column;
    width: 100%;
    position: relative;
    font-family: inherit;
  }

  /* ===== FIELD ===== */
  .ic-ts__field {
    display: flex;
    align-items: center;
    border-radius: 3px;
    border: 1px solid var(--ic-border);
    background: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    cursor: text;
    outline: none;
    gap: 0.25rem;
  }

  .ic-ts__field--primary { border-color: var(--ic-border); }

  .ic-ts__field--secondary {
    background: var(--ic-secondary);
    border-color: transparent;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  .ic-ts__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-ts__field--secondary.ic-ts__field--focused {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.18);
  }

  .ic-ts--disabled .ic-ts__field {
    opacity: 0.5;
    cursor: not-allowed;
    background: var(--ic-muted);
    pointer-events: none;
  }

  /* ===== TAGS + INPUT ===== */
  .ic-ts__tags-area {
    display: flex;
    align-items: center;
    overflow-x: auto;
    overflow-y: hidden;
    gap: 3px;
    flex: 1;
    min-width: 0;
  }

  .ic-ts__tags-area::-webkit-scrollbar { height: 3px; }
  .ic-ts__tags-area::-webkit-scrollbar-track { background: transparent; }
  .ic-ts__tags-area::-webkit-scrollbar-thumb { background: var(--ic-border); border-radius: 3px; }

  .ic-ts__input {
    flex: 1;
    min-width: 60px;
    border: none;
    outline: none;
    background: transparent;
    color: var(--ic-foreground);
    font-family: inherit;
    font-size: inherit;
    line-height: 1;
    padding: 0;
  }

  .ic-ts__input::placeholder {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
  }

  .ic-ts__input:disabled { cursor: not-allowed; }

  /* ===== ACTIONS ===== */
  .ic-ts__actions {
    display: flex;
    align-items: center;
    gap: 2px;
    flex-shrink: 0;
    align-self: flex-start;
  }

  .ic-ts__clear-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, color 0.15s ease;
  }

  .ic-ts__clear-btn:hover { opacity: 1; color: var(--ic-foreground); }

  .ic-ts__arrow {
    display: flex;
    align-items: center;
    color: var(--ic-muted-foreground);
    transition: transform 0.15s ease;
  }

  .ic-ts__arrow--open { transform: rotate(180deg); }

  /* ===== SIZES ===== */
  .ic-ts--sm { font-size: 0.75rem; }
  .ic-ts--md { font-size: 0.8125rem; }
  .ic-ts--lg { font-size: 0.9375rem; }

  .ic-ts--sm .ic-ts__field { padding: 0.25rem 0.375rem; min-height: 1.75rem; }
  .ic-ts--md .ic-ts__field { padding: 0.375rem 0.5rem; min-height: 2.25rem; }
  .ic-ts--lg .ic-ts__field { padding: 0.5rem 0.625rem; min-height: 2.75rem; }

  .ic-ts--sm .ic-ts__tags-area { min-height: 18px; }
  .ic-ts--md .ic-ts__tags-area { min-height: 22px; }
  .ic-ts--lg .ic-ts__tags-area { min-height: 24px; }

  .ic-ts--sm .ic-ts__actions { padding-top: 0.2rem; }
  .ic-ts--md .ic-ts__actions { padding-top: 0.3rem; }
  .ic-ts--lg .ic-ts__actions { padding-top: 0.4rem; }

  /* ===== DROPDOWN (search mode) ===== */
  .ic-ts__dropdown {
    position: absolute;
    z-index: 50;
    top: calc(100% + 4px);
    left: 0;
    width: 100%;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    overflow: hidden;
  }

  .ic-ts__search-list {
    overflow-y: auto;
    padding: 4px 0;
  }

  .ic-ts__search-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.375rem 0.5rem;
    cursor: pointer;
    color: var(--ic-foreground);
    user-select: none;
    transition: background-color 0.1s ease;
  }

  .ic-ts__search-item--focused { background: var(--ic-secondary); }
  .ic-ts__search-item--selected { font-weight: 500; }
  .ic-ts__search-item--disabled { opacity: 0.4; cursor: not-allowed; }

  .ic-ts__search-content {
    display: flex;
    flex-direction: column;
    min-width: 0;
    flex: 1;
  }

  .ic-ts__search-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ic-ts__search-path {
    font-size: 0.7em;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ic-ts__search-icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  .ic-ts__check {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
    flex-shrink: 0;
    transition: background-color 0.12s ease, border-color 0.12s ease;
  }

  .ic-ts__check--on {
    background: var(--ic-primary);
    border-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
  }

  .ic-ts__empty {
    padding: 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }

  /* ===== CASCADE (tree panel mode, horizontal scroll) ===== */
  .ic-ts__cascade {
    position: absolute;
    z-index: 50;
    top: calc(100% + 4px);
    left: 0;
    max-width: 100%;
    overflow-x: auto;
    padding: 0 12px 16px 0;
  }
</style>
