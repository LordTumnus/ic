<script lang="ts">
  import type { Resolution, RequestFn } from '$lib/types';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import logger from '$lib/core/logger';
  import SearchBar from '$lib/components/form/searchBar/SearchBar.svelte';
  import VirtualTree from '$lib/components/tree/virtualTree/VirtualTree.svelte';
  import {
    FILTER_TRIGGERS,
    parseFilters,
    isEmptyFilter,
    buildHighlightRegex,
  } from '$lib/utils/filter-tree-utils';

  // --- Props ---
  let {
    value = $bindable<string[] | string | null>(null),
    searchValue = $bindable<string[] | string | null>(null),
    disabled = $bindable(false),
    selectable = $bindable(true),
    size = $bindable('md'),
    height = $bindable<number | string>(400),
    showLine = $bindable(true),
    maxSelectedItems = $bindable<number | null>(null),
    placeholder = $bindable('Loading...'),
    searchPlaceholder = $bindable('Search...'),
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
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    clearSearch = $bindable((): Resolution => ({ success: true, data: null })),
    expandNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    collapseNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    expandAll = $bindable((): Resolution => ({ success: true, data: null })),
    collapseAll = $bindable((): Resolution => ({ success: true, data: null })),
    // Framework
    request,
  }: {
    value?: string[] | string | null;
    searchValue?: string[] | string | null;
    disabled?: boolean;
    selectable?: boolean;
    size?: string;
    height?: number | string;
    showLine?: boolean;
    maxSelectedItems?: number | null;
    placeholder?: string;
    searchPlaceholder?: string;
    clearable?: boolean;
    caseSensitive?: boolean;
    autoExpand?: boolean;
    leafContextMenu?: ContextMenuEntry[];
    folderContextMenu?: ContextMenuEntry[];
    valueChanged?: (data?: unknown) => void;
    searchChanged?: (data?: unknown) => void;
    contextMenuAction?: (data?: unknown) => void;
    focus?: () => Resolution;
    clearSelection?: () => Resolution;
    clearSearch?: () => Resolution;
    expandNode?: (data: { key: string }) => Resolution;
    collapseNode?: (data: { key: string }) => Resolution;
    expandAll?: () => Resolution;
    collapseAll?: () => Resolution;
    request?: RequestFn;
  } = $props();

  // --- Refs ---
  let containerEl: HTMLDivElement;
  const noop = (): Resolution => ({ success: true, data: null });
  let searchBarFocus = $state<() => Resolution>(noop);
  let searchBarClear = $state<() => Resolution>(noop);
  // VirtualTree method bindings
  let vtFocus = $state<() => Resolution>(noop);
  let vtClearSelection = $state<() => Resolution>(noop);
  let vtExpandNode = $state<(data: { key: string }) => Resolution>(noop as (data: { key: string }) => Resolution);
  let vtCollapseNode = $state<(data: { key: string }) => Resolution>(noop as (data: { key: string }) => Resolution);
  let vtExpandAll = $state<() => Resolution>(noop);
  let vtCollapseAll = $state<() => Resolution>(noop);

  // --- State ---
  /** Incremented after each filter/clearFilter response to re-key VirtualTree. */
  let filterVersion = $state(0);
  /** Folder keys to auto-expand when VirtualTree remounts after filtering. */
  let filterExpandKeys = $state<string[]>([]);
  let filterDebounceTimer: ReturnType<typeof setTimeout>;
  /** True while waiting for MATLAB to cache the filter results. */
  let filterPending = $state(false);
  /** True if the last filterVersion bump was from an active filter (vs clear). */
  let filterWasActive = $state(false);

  // --- Search tags ---
  const searchTags = $derived.by((): string[] => {
    if (searchValue == null) return [];
    if (Array.isArray(searchValue)) return searchValue.filter((v) => v !== '' && v != null);
    if (searchValue === '') return [];
    return [searchValue];
  });

  const filterGroups = $derived(parseFilters(searchTags));
  const hasActiveFilter = $derived(!isEmptyFilter(filterGroups));
  const highlightRegex = $derived(hasActiveFilter ? buildHighlightRegex(filterGroups, caseSensitive) : null);
  const initialExpandedKeys = $derived(
    filterWasActive && autoExpand && filterExpandKeys.length > 0
      ? new Set(filterExpandKeys)
      : undefined
  );

  // --- Trigger filter request when tags change ---
  $effect(() => {
    const groups = filterGroups;
    const cs = caseSensitive;

    if (isEmptyFilter(groups)) {
      clearTimeout(filterDebounceTimer);
      filterPending = false;
      // If there was a previous filter, clear it and re-key
      if (filterWasActive) {
        filterExpandKeys = [];
        filterWasActive = false;
        request?.('clearFilter', {}).then(() => {
          filterVersion++;
          logger.debug('VirtualFilterTree', 'Filter cleared, re-keying VirtualTree');
        }).catch((err) => {
          logger.error('VirtualFilterTree', 'clearFilter error', { error: String(err) });
          filterVersion++;
        });
      }
      return;
    }

    // Debounce: wait 200ms after last tag change
    clearTimeout(filterDebounceTimer);
    filterPending = true;
    logger.debug('VirtualFilterTree', 'Filter debounce started', { groups });
    filterDebounceTimer = setTimeout(() => {
      logger.info('VirtualFilterTree', 'Sending filter request', { groups, caseSensitive: cs });
      request?.('filter', { groups, caseSensitive: cs }).then((res: unknown) => {
        const r = res as { success?: boolean; data?: { count?: number; expandKeys?: string[] } } | null;
        if (r?.success && r.data) {
          const keys = r.data.expandKeys ?? [];
          filterExpandKeys = keys;
          filterWasActive = true;
          filterVersion++;
          logger.info('VirtualFilterTree', 'Filter cached', { count: r.data.count, folders: keys.length });
        } else {
          logger.warn('VirtualFilterTree', 'Filter request failed', { res: r });
        }
        filterPending = false;
      }).catch((err) => {
        logger.error('VirtualFilterTree', 'Filter request error', { error: String(err) });
        filterPending = false;
      });
    }, 200);
  });

  // --- Search event handler ---
  function handleSearchValueChanged() {
    logger.debug('VirtualFilterTree', 'Search changed', { searchValue });
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
      vtClearSelection?.();
      return { success: true, data: null };
    };
    expandNode = (data: { key: string }): Resolution => {
      vtExpandNode?.(data);
      return { success: true, data: null };
    };
    collapseNode = (data: { key: string }): Resolution => {
      vtCollapseNode?.(data);
      return { success: true, data: null };
    };
    expandAll = (): Resolution => {
      vtExpandAll?.();
      return { success: true, data: null };
    };
    collapseAll = (): Resolution => {
      vtCollapseAll?.();
      return { success: true, data: null };
    };
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={containerEl}
  class="ic-vft"
  class:ic-vft--sm={size === 'sm'}
  class:ic-vft--md={size === 'md'}
  class:ic-vft--lg={size === 'lg'}
  class:ic-vft--disabled={disabled}
>
  <!-- Search bar -->
  <div class="ic-vft__search">
    <SearchBar
      bind:value={searchValue}
      placeholder={searchPlaceholder}
      {disabled}
      {clearable}
      {size}
      variant="secondary"
      separator=","
      iconTriggers={FILTER_TRIGGERS}
      valueChanged={handleSearchValueChanged}
      bind:focus={searchBarFocus}
      bind:clear={searchBarClear}
    />
  </div>

  <!-- Content area: always VirtualTree -->
  <div class="ic-vft__content">
    {#if filterPending}
      <div class="ic-vft__loading">Filtering...</div>
    {/if}
    <div class="ic-vft__tree-wrap" class:ic-vft__tree-wrap--hidden={filterPending}>
      {#key filterVersion}
        <VirtualTree
          bind:value
          {disabled}
          {selectable}
          {size}
          {height}
          {showLine}
          {maxSelectedItems}
          {placeholder}
          {valueChanged}
          {contextMenuAction}
          {leafContextMenu}
          {folderContextMenu}
          {highlightRegex}
          {initialExpandedKeys}
          bind:focus={vtFocus}
          bind:clearSelection={vtClearSelection}
          bind:expandNode={vtExpandNode}
          bind:collapseNode={vtCollapseNode}
          bind:expandAll={vtExpandAll}
          bind:collapseAll={vtCollapseAll}
          {request}
        />
      {/key}
    </div>
  </div>
</div>

<style>
  /* ===== ROOT ===== */
  .ic-vft {
    display: inline-flex;
    flex-direction: column;
    gap: 6px;
    width: 100%;
    font-family: inherit;
    outline: none;
  }

  .ic-vft--disabled {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* ===== SIZES ===== */
  .ic-vft--sm { font-size: 0.75rem; }
  .ic-vft--md { font-size: 0.8125rem; }
  .ic-vft--lg { font-size: 0.9375rem; }

  /* ===== SHARED PANEL FRAME ===== */
  .ic-vft__search,
  .ic-vft__content {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
  }

  /* ===== SEARCH BAR ===== */
  .ic-vft__search {
    flex-shrink: 0;
  }

  .ic-vft__search :global(.ic-sb) { width: 100%; }
  .ic-vft__search :global(.ic-sb__field) {
    border: none;
    border-radius: 0;
    box-shadow: none;
    background: transparent;
  }
  .ic-vft__search :global(.ic-sb__field--focused) {
    border: none;
    box-shadow: none;
  }

  /* ===== CONTENT ===== */
  .ic-vft__content {
    flex: 1;
    min-height: 0;
    overflow: hidden;
    position: relative;
  }

  /* Remove VirtualTree's own border/shadow when nested */
  .ic-vft__content :global(.ic-vt) {
    border: none;
    border-radius: 0;
    box-shadow: none;
  }

  .ic-vft__tree-wrap {
    width: 100%;
    height: 100%;
  }

  .ic-vft__tree-wrap--hidden {
    visibility: hidden;
    position: absolute;
  }

  /* ===== LOADING ===== */
  .ic-vft__loading {
    padding: 0.75rem 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }
</style>
