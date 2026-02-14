<script lang="ts">
  import type { Resolution, RequestFn } from '$lib/types';
  import logger from '$lib/core/logger';
  import { toSize } from '$lib/utils/css';
  import {
    type VirtualNode,
    type ChildCache,
    normalizeVirtualNodes,
    flattenVisible,
    computeTotalRows,
  } from '$lib/utils/virtual-tree';
  import VirtualRow from './VirtualRow.svelte';

  const ROW_HEIGHTS: Record<string, number> = { sm: 24, md: 28, lg: 32 };

  // --- Props ---
  let {
    value = $bindable<string[] | string | null>(null),
    disabled = $bindable(false),
    selectable = $bindable(true),
    size = $bindable('md'),
    height = $bindable<number | string>(400),
    showLine = $bindable(true),
    maxSelectedItems = $bindable<number | null>(null),
    placeholder = $bindable('Loading...'),
    // Filter support (passed through from VirtualFilterTree)
    highlightRegex = $bindable(null as RegExp | null),
    initialExpandedKeys = undefined as Set<string> | undefined,
    // Events
    valueChanged,
    // Methods
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    clearSelection = $bindable((): Resolution => ({ success: true, data: null })),
    expandNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    collapseNode = $bindable((_data: { key: string }): Resolution => ({ success: true, data: null })),
    expandAll = $bindable((): Resolution => ({ success: true, data: null })),
    collapseAll = $bindable((): Resolution => ({ success: true, data: null })),
    // Framework
    request,
  }: {
    value?: string[] | string | null;
    disabled?: boolean;
    selectable?: boolean;
    size?: string;
    height?: number | string;
    showLine?: boolean;
    maxSelectedItems?: number | null;
    placeholder?: string;
    highlightRegex?: RegExp | null;
    initialExpandedKeys?: Set<string>;
    valueChanged?: (data?: unknown) => void;
    focus?: () => Resolution;
    clearSelection?: () => Resolution;
    expandNode?: (data: { key: string }) => Resolution;
    collapseNode?: (data: { key: string }) => Resolution;
    expandAll?: () => Resolution;
    collapseAll?: () => Resolution;
    request?: RequestFn;
  } = $props();

  // --- Refs ---
  let scrollEl: HTMLDivElement;
  let containerEl: HTMLDivElement;

  // --- State ---
  let roots = $state<VirtualNode[]>([]);
  let expandedKeys = $state(new Set<string>());
  let childCaches = $state(new Map<string, ChildCache>());
  let loadingKeys = $state(new Set<string>());
  let pendingFetches = new Set<string>();
  let scrollTop = $state(0);
  let scrollTimer: ReturnType<typeof setTimeout>;
  let initialized = $state(false);

  // --- Derived ---
  const rowHeight = $derived(ROW_HEIGHTS[size] ?? 28);

  const containerPx = $derived.by((): number => {
    if (typeof height === 'number') return height;
    const parsed = parseInt(String(height));
    return isNaN(parsed) ? 400 : parsed;
  });

  const viewportRows = $derived(Math.ceil(containerPx / rowHeight));
  const visibleCount = $derived(viewportRows + 4);

  // Scroll prefetch: trigger & fetch size = 2× viewport rows, clamped [20, 200]
  const prefetchBuffer = $derived(Math.min(200, Math.max(20, viewportRows * 2)));

  const flatRows = $derived(flattenVisible(roots, expandedKeys, childCaches, showLine));
  const totalRows = $derived(computeTotalRows(roots, expandedKeys, childCaches));
  const totalHeight = $derived(totalRows * rowHeight);

  const startIdx = $derived(Math.max(0, Math.floor(scrollTop / rowHeight) - 1));
  const endIdx = $derived(Math.min(flatRows.length, startIdx + visibleCount));
  const visibleRows = $derived(flatRows.slice(startIdx, endIdx));

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
    logger.debug('VirtualTree', 'Toggle selection', { key });
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
  function expandKey(key: string) {
    const next = new Set(expandedKeys);
    next.add(key);
    expandedKeys = next;
    // Prefetch children of newly visible collapsed folders
    setTimeout(viewportPrefetch, 50);
  }

  function handleExpandChange(key: string, expanded: boolean) {
    logger.debug('VirtualTree', expanded ? 'Expanding' : 'Collapsing', { key });
    if (expanded) {
      if (childCaches.has(key)) {
        // Children already cached (e.g. from viewport prefetch) — expand instantly
        expandKey(key);
      } else {
        // No cache — show spinner, fetch, then expand
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
      // Collapsing shifts the viewport — new placeholders may now be visible
      setTimeout(viewportPrefetch, 50);
    }
  }

  // --- Request helpers ---
  async function ensureChildrenLoaded(parentKey: string, offset: number, count: number) {
    const fetchKey = `${parentKey}:${offset}`;
    if (pendingFetches.has(fetchKey)) return;
    pendingFetches.add(fetchKey);
    logger.debug('VirtualTree', 'Fetching children', { parentKey, offset, count });
    try {
      const res = await request?.('getChildren', { key: parentKey, offset, count });
      logger.debug('VirtualTree', 'getChildren response', { parentKey, success: res?.success, nodeCount: Array.isArray(res?.data) ? res.data.length : res?.data ? 1 : 0 });
      if (res?.success) {
        const nodes = normalizeVirtualNodes(res.data);
        const existing = childCaches.get(parentKey);
        const cache: ChildCache = existing
          ? { ...existing, nodes: [...existing.nodes] }
          : { nodes: [], loaded: 0, total: 0 };

        // Find the parent node to get total childCount
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

  /** Find a VirtualNode by key in roots + caches. */
  function findNode(key: string): VirtualNode | undefined {
    // Check roots
    for (const r of roots) {
      if (r.key === key) return r;
    }
    // Check all cache entries
    for (const [, cache] of childCaches) {
      for (const n of cache.nodes) {
        if (n && n.key === key) return n;
      }
    }
    return undefined;
  }

  // --- Scroll prefetch ---
  function checkScrollPrefetch() {
    // Derive parent keys from visible rows (works even when folder scrolled out of view)
    const checked = new Set<string>();
    for (const row of visibleRows) {
      const lastDash = row.node.key.lastIndexOf('-');
      if (lastDash === -1) continue; // root-level node
      const parentKey = row.node.key.substring(0, lastDash);
      if (checked.has(parentKey)) continue;
      checked.add(parentKey);
      if (!expandedKeys.has(parentKey)) continue;
      const cache = childCaches.get(parentKey);
      // No cache at all → expanded folder whose children were never fetched
      if (!cache) {
        if (row.isPlaceholder) {
          ensureChildrenLoaded(parentKey, 0, prefetchBuffer);
        }
        continue;
      }
      if (cache.loaded >= cache.total) continue;
      // Child index from key suffix
      const childIdx = parseInt(row.node.key.substring(lastDash + 1), 10);
      if (childIdx >= cache.loaded - prefetchBuffer) {
        logger.debug('VirtualTree', 'Scroll prefetch', { parentKey, offset: cache.loaded, childIdx, buffer: prefetchBuffer });
        ensureChildrenLoaded(parentKey, cache.loaded, prefetchBuffer);
      }
    }
  }

  // --- Viewport prefetch (scroll-stop debounce) ---
  function viewportPrefetch() {
    let prefetchCount = 0;
    const checkedParents = new Set<string>();

    for (const row of visibleRows) {
      // Placeholder rows → their parent folder is expanded but children
      // haven't been fetched yet. Load that parent's children.
      if (row.isPlaceholder) {
        const lastDash = row.node.key.lastIndexOf('-');
        if (lastDash === -1) continue;
        const parentKey = row.node.key.substring(0, lastDash);
        if (checkedParents.has(parentKey)) continue;
        checkedParents.add(parentKey);
        if (!childCaches.has(parentKey)) {
          prefetchCount++;
          ensureChildrenLoaded(parentKey, 0, prefetchBuffer).then(() => {
            // Cascade: newly loaded children may themselves be expanded
            // folders with placeholders now visible in the viewport.
            setTimeout(viewportPrefetch, 50);
          });
        }
        continue;
      }

      // Collapsed folders → pre-cache children for instant open on click
      if (!row.node.isFolder) continue;
      if (expandedKeys.has(row.node.key)) continue;
      if (childCaches.has(row.node.key)) continue;
      prefetchCount++;
      ensureChildrenLoaded(row.node.key, 0, prefetchBuffer);
    }
    if (prefetchCount > 0) {
      logger.debug('VirtualTree', 'Viewport prefetch', { folders: prefetchCount });
    }
  }

  // --- Scroll handler ---
  function onScroll(e: Event) {
    scrollTop = (e.target as HTMLDivElement).scrollTop;
    checkScrollPrefetch();
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(viewportPrefetch, 200);
  }

  // --- Lifecycle: load roots ---
  $effect(() => {
    if (!request || initialized) return;
    initialized = true;
    logger.info('VirtualTree', 'Requesting roots');
    request('getRoots', {}).then((res: Resolution) => {
      logger.info('VirtualTree', 'getRoots response', { success: res.success, data: res.data });
      if (res.success) {
        roots = normalizeVirtualNodes(res.data);
        if (initialExpandedKeys && initialExpandedKeys.size > 0) {
          expandedKeys = new Set(initialExpandedKeys);
        }
        logger.info('VirtualTree', 'Roots loaded', { count: roots.length, roots });
        setTimeout(viewportPrefetch, 100);
      } else {
        logger.warn('VirtualTree', 'getRoots failed', { res });
      }
    }).catch((err: Error) => {
      logger.error('VirtualTree', 'getRoots error', { error: String(err) });
    });
  });

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
      // Expand all known folders (roots + cached children)
      const next = new Set(expandedKeys);
      function addFolders(nodes: VirtualNode[]) {
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
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={containerEl}
  class="ic-vt"
  class:ic-vt--sm={size === 'sm'}
  class:ic-vt--md={size === 'md'}
  class:ic-vt--lg={size === 'lg'}
  class:ic-vt--disabled={disabled}
  role="tree"
  tabindex={disabled ? -1 : 0}
  style="height: {toSize(height)}"
>
  <div
    bind:this={scrollEl}
    class="ic-vt__scroll"
    onscroll={onScroll}
  >
    <div class="ic-vt__spacer" style="height: {totalHeight}px">
      {#each visibleRows as row, i (row.node.key + (row.isPlaceholder ? '-ph' : ''))}
        <div
          class="ic-vt__row-wrapper"
          style="position: absolute; top: {(startIdx + i) * rowHeight}px; height: {rowHeight}px; width: 100%"
        >
          <VirtualRow
            {row}
            {size}
            {selectable}
            {disabled}
            {showLine}
            {expandedKeys}
            {loadingKeys}
            isItemSelected={isSelected}
            {atMaxSelections}
            {highlightRegex}
            ontoggle={toggleItem}
            onexpandchange={handleExpandChange}
          />
        </div>
      {/each}
    </div>
  </div>

  {#if !initialized || roots.length === 0}
    <div class="ic-vt__empty">{placeholder}</div>
  {/if}
</div>

<style>
  /* ===== ROOT ===== */
  .ic-vt {
    display: inline-flex;
    flex-direction: column;
    width: 100%;
    font-family: inherit;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    outline: none;
    overflow: hidden;
  }

  .ic-vt:focus {
    border-color: var(--ic-primary);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
  }

  .ic-vt--disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background: var(--ic-muted);
    pointer-events: none;
  }

  /* ===== SIZES ===== */
  .ic-vt--sm { font-size: 0.75rem; }
  .ic-vt--md { font-size: 0.8125rem; }
  .ic-vt--lg { font-size: 0.9375rem; }

  /* ===== SCROLL CONTAINER ===== */
  .ic-vt__scroll {
    overflow-y: auto;
    height: 100%;
    position: relative;
  }

  .ic-vt__scroll::-webkit-scrollbar { width: 4px; }
  .ic-vt__scroll::-webkit-scrollbar-track { background: transparent; }
  .ic-vt__scroll::-webkit-scrollbar-thumb { background: var(--ic-border); border-radius: 2px; }

  /* ===== VIRTUAL SPACER ===== */
  .ic-vt__spacer {
    position: relative;
    width: 100%;
  }

  .ic-vt__row-wrapper {
    position: absolute;
    left: 0;
    right: 0;
    display: flex;
    align-items: center;
  }

  /* ===== EMPTY STATE ===== */
  .ic-vt__empty {
    padding: 0.75rem 0.5rem;
    text-align: center;
    color: var(--ic-muted-foreground);
    font-size: 0.8em;
    user-select: none;
  }

  /* ===== REUSED TREENODE ROW STYLES ===== */
  .ic-vt :global(.ic-tn__row) {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.25rem 0.5rem;
    cursor: pointer;
    color: var(--ic-foreground);
    user-select: none;
    transition: background-color 0.1s ease;
    width: 100%;
    height: 100%;
  }

  .ic-vt :global(.ic-tn__row:hover) {
    background: var(--ic-secondary);
  }

  .ic-vt :global(.ic-tn__row--disabled) {
    opacity: 0.4;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* Folder icon */
  .ic-vt :global(.ic-tn__folder) {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 16px;
    height: 16px;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    transition: color 0.1s ease;
  }

  .ic-vt :global(.ic-tn__folder svg) {
    fill: currentColor;
    fill-opacity: 0.15;
  }

  .ic-vt :global(.ic-tn__folder:hover) {
    color: var(--ic-foreground);
  }

  /* Tree line guides */
  .ic-vt :global(.ic-tn__guides) {
    display: flex;
    align-self: stretch;
    flex-shrink: 0;
    margin: -0.25rem 0;
  }

  .ic-vt :global(.ic-tn__guide) {
    position: relative;
    flex-shrink: 0;
    align-self: stretch;
  }

  .ic-vt :global(.ic-tn__guide--pipe::before) {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }

  .ic-vt :global(.ic-tn__guide--branch::before) {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 1px;
    background: var(--ic-border);
  }

  .ic-vt :global(.ic-tn__guide--branch.ic-tn__guide--last::before) {
    bottom: 50%;
  }

  .ic-vt :global(.ic-tn__guide--branch::after) {
    content: '';
    position: absolute;
    left: 50%;
    top: 50%;
    right: -0.125rem;
    height: 1px;
    background: var(--ic-border);
  }

  /* Content (icon + label + selection) */
  .ic-vt :global(.ic-tn__content) {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    max-width: 100%;
    min-width: 0;
    border-radius: 2px;
    padding: 1px 0.25rem;
    margin: -1px -0.25rem;
    transition: background-color 0.12s ease, color 0.12s ease;
  }

  .ic-vt :global(.ic-tn__content--selected) {
    position: relative;
    color: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  .ic-vt :global(.ic-tn__content--selected::before) {
    content: '';
    position: absolute;
    inset: 0;
    background: var(--ic-primary);
    opacity: 0.13;
    border-radius: inherit;
    pointer-events: none;
  }

  .ic-vt :global(.ic-tn__icon) {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  .ic-vt :global(.ic-tn__content--selected .ic-tn__icon) {
    color: var(--ic-primary);
  }

  .ic-vt :global(.ic-tn__label) {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* ===== HIGHLIGHT (filter match) ===== */
  .ic-vt :global(.ic-tn__highlight) {
    background: rgba(234, 179, 8, 0.25);
    color: inherit;
    border-radius: 1px;
    padding: 0 1px;
  }
</style>
