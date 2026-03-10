<!--
  TileLayout.svelte — Tiling tab layout with draggable split areas.

  Manages a binary split tree where:
    - Leaf nodes are tab groups (TileGroup)
    - Internal nodes are splits (horizontal/vertical) with resizable gutters
    - Users drag tabs to edges to create new splits (VSCode-style)

  IMPORTANT: Uses flat rendering (absolute positioning) instead of recursive
  snippets. This preserves TileGroup instances across tree mutations, which
  is required for IC framework snippet mounts to survive splits/merges.
-->
<script lang="ts">
  import { untrack } from 'svelte';
  import type { ChildEntries } from '$lib/types';
  import type { TileNode, TileLeaf, DragState, DropZone } from './tile-types';
  import {
    genId,
    findLeafByTab,
    findLeafById,
    collectAllTabs,
    addTabToLeaf,
    removeTabFromLeaf,
    splitLeaf,
    resizeSplit,
    prune
  } from './tile-tree';
  import { SHADOW_PLACEHOLDER_ITEM_ID } from 'svelte-dnd-action';
  import TileGroup from './TileGroup.svelte';

  let {
    gutterSize = $bindable(3),
    size = $bindable<'sm' | 'md' | 'lg'>('sm'),
    disabled = $bindable(false),
    dragEnabled = $bindable(true),
    targets = $bindable<string[]>([]),
    tabClosed,
    tabMoved,
    layoutChanged,
    childEntries = {} as ChildEntries,
  }: {
    gutterSize?: number;
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
    dragEnabled?: boolean;
    targets?: string[];
    tabClosed?: (data: { value: string }) => void;
    tabMoved?: (data: { value: { tab: string; fromGroup: string; toGroup: string } }) => void;
    layoutChanged?: (data: { value: string }) => void;
    childEntries?: ChildEntries;
  } = $props();

  // ─── Tab bar height estimates (padding + font + border) per size ──
  const BAR_HEIGHTS: Record<string, number> = { sm: 21, md: 24, lg: 29 };

  // ─── Flat layout computation ───────────────────────────────────────

  interface LeafRect {
    id: string;
    leaf: TileLeaf;
    x: number;
    y: number;
    w: number;
    h: number;
  }

  interface GutterRect {
    splitId: string;
    direction: 'horizontal' | 'vertical';
    ratio: number;
    x: number;
    y: number;
    w: number;
    h: number;
    /** Total pixel space along the split axis (minus gutter) */
    availableSize: number;
  }

  interface FlatLayout {
    leaves: LeafRect[];
    gutters: GutterRect[];
  }

  /**
   * Walk the tree recursively, producing pixel rectangles for every
   * leaf and gutter. No DOM measurement needed — pure computation.
   */
  function computeFlatLayout(
    node: TileNode,
    x: number,
    y: number,
    w: number,
    h: number,
    gs: number
  ): FlatLayout {
    if (node.type === 'leaf') {
      return {
        leaves: [{ id: node.id, leaf: node, x, y, w: Math.max(0, w), h: Math.max(0, h) }],
        gutters: []
      };
    }

    const split = node;
    const isH = split.direction === 'horizontal';
    const total = isH ? w : h;
    const available = Math.max(0, total - gs);
    const firstSize = available * split.ratio;
    const secondSize = available - firstSize;

    let first: FlatLayout;
    let gutter: GutterRect;
    let second: FlatLayout;

    if (isH) {
      first = computeFlatLayout(split.children[0], x, y, firstSize, h, gs);
      gutter = {
        splitId: split.id,
        direction: 'horizontal',
        ratio: split.ratio,
        x: x + firstSize,
        y,
        w: gs,
        h,
        availableSize: available
      };
      second = computeFlatLayout(split.children[1], x + firstSize + gs, y, secondSize, h, gs);
    } else {
      first = computeFlatLayout(split.children[0], x, y, w, firstSize, gs);
      gutter = {
        splitId: split.id,
        direction: 'vertical',
        ratio: split.ratio,
        x,
        y: y + firstSize,
        w,
        h: gs,
        availableSize: available
      };
      second = computeFlatLayout(split.children[1], x, y + firstSize + gs, w, secondSize, gs);
    }

    return {
      leaves: [...first.leaves, ...second.leaves],
      gutters: [gutter, ...first.gutters, ...second.gutters]
    };
  }

  // ─── Container measurement ─────────────────────────────────────────

  let containerEl: HTMLDivElement | undefined = $state();
  let containerW = $state(0);
  let containerH = $state(0);

  $effect(() => {
    if (!containerEl) return;
    const ro = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (entry) {
        containerW = entry.contentRect.width;
        containerH = entry.contentRect.height;
      }
    });
    ro.observe(containerEl);
    return () => ro.disconnect();
  });

  // ─── Split tree state ──────────────────────────────────────────────

  let tree = $state<TileNode>({ type: 'leaf', id: genId('leaf'), tabs: [], selectedTab: '' });

  /**
   * Sync tabs from MATLAB's `targets` into the tree.
   *
   * Uses untrack() when reading `tree` so this effect ONLY re-runs when
   * `targets` changes — not when the tree is mutated by drag operations.
   * This prevents the fragile read/write loop that caused spurious
   * re-adds and tab misplacement.
   */
  $effect(() => {
    // Reactive dependency: only `targets`
    const allTabTargets = targets.filter((t) => t.startsWith('tab-'));

    // Read tree WITHOUT subscribing — we just need its current value
    const currentTree = untrack(() => tree);
    const treeTabs = new Set(collectAllTabs(currentTree));

    // Add new tabs (present in targets but missing from tree)
    const newTabs = allTabTargets.filter((t) => !treeTabs.has(t));
    if (newTabs.length > 0) {
      let updated = currentTree;
      const firstLeafId = findFirstLeaf(updated)?.id;
      if (firstLeafId) {
        for (const tab of newTabs) {
          updated = addTabToLeaf(updated, firstLeafId, tab);
        }
        tree = updated;
      }
    }

    // Remove stale tabs (present in tree but missing from targets)
    const currentSet = new Set(allTabTargets);
    const treeTabs2 = collectAllTabs(untrack(() => tree));
    const removed = treeTabs2.filter((t) => !currentSet.has(t));
    if (removed.length > 0) {
      let updated = untrack(() => tree);
      for (const tab of removed) {
        const leaf = findLeafByTab(updated, tab);
        if (leaf) {
          updated = removeTabFromLeaf(updated, leaf.id, tab);
        }
      }
      updated = prune(updated);
      tree = updated;
    }
  });

  function findFirstLeaf(node: TileNode): TileLeaf | null {
    if (node.type === 'leaf') return node;
    if (!node.children?.[0]) return null;
    return findFirstLeaf(node.children[0]);
  }

  // ─── Derived flat layout ───────────────────────────────────────────

  let layout = $derived(computeFlatLayout(tree, 0, 0, containerW, containerH, gutterSize));

  // ─── Panel rects (keyed by panel target — never destroyed on tab move) ──

  interface PanelRect {
    target: string;
    x: number;
    y: number;
    w: number;
    h: number;
    active: boolean;
  }

  let panelRects = $derived.by(() => {
    const bh = BAR_HEIGHTS[size] ?? 21;
    const result: PanelRect[] = [];
    for (const rect of layout.leaves) {
      for (const tabTgt of rect.leaf.tabs) {
        result.push({
          target: tabTgt.replace('tab-', 'panel-'),
          x: rect.x,
          y: rect.y + bh,
          w: rect.w,
          h: Math.max(0, rect.h - bh),
          active: tabTgt === rect.leaf.selectedTab
        });
      }
    }
    return result;
  });

  // ─── Drag state ────────────────────────────────────────────────────

  let dragState = $state<DragState>({
    active: false,
    tabTarget: '',
    sourceGroupId: '',
    mouseX: 0,
    mouseY: 0,
    hoveredGroupId: null,
    targetZone: null,
  });

  // Prevent double-finalize (dndzone may fire on both source and target zones)
  let finalizeProcessed = false;

  // Track group DOM elements for hit-testing (imperative, not reactive)
  let groupElements = new Map<string, HTMLElement>();

  function registerGroup(groupId: string, el: HTMLElement) {
    groupElements.set(groupId, el);
  }

  function unregisterGroup(groupId: string) {
    groupElements.delete(groupId);
  }

  // ─── Global pointer tracking during drag ───────────────────────────

  function handleGlobalMouseMove(e: MouseEvent) {
    if (!dragState.active) return;

    dragState.mouseX = e.clientX;
    dragState.mouseY = e.clientY;

    // Hit-test: which group is the mouse over?
    let foundGroupId: string | null = null;
    let foundZone: DropZone | null = null;

    for (const [gId, el] of groupElements) {
      if (!el.isConnected) continue;
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;
      if (
        e.clientX >= rect.left &&
        e.clientX <= rect.right &&
        e.clientY >= rect.top &&
        e.clientY <= rect.bottom
      ) {
        foundGroupId = gId;
        foundZone = computeDropZone(e.clientX, e.clientY, rect);
        break;
      }
    }

    dragState.hoveredGroupId = foundGroupId;
    dragState.targetZone = foundZone;
  }

  function computeDropZone(x: number, y: number, rect: DOMRect): DropZone {
    if (rect.width <= 0 || rect.height <= 0) return 'center';
    const relX = (x - rect.left) / rect.width;
    const relY = (y - rect.top) / rect.height;

    // Edge zones: 20% on each edge; center is the remaining 60%
    const EDGE = 0.20;

    if (relY < EDGE) return 'top';
    if (relY > 1 - EDGE) return 'bottom';
    if (relX < EDGE) return 'left';
    if (relX > 1 - EDGE) return 'right';
    return 'center';
  }

  // ─── Cleanup listeners on component destroy ────────────────────────

  function cleanupDragListeners() {
    document.removeEventListener('mousemove', handleGlobalMouseMove);
    document.documentElement.style.removeProperty('--_tg-cursor');
  }

  function cleanupResizeListeners() {
    document.removeEventListener('mousemove', handleResizeMove);
    document.removeEventListener('mouseup', handleResizeUp);
  }

  $effect(() => {
    return () => {
      cleanupDragListeners();
      cleanupResizeListeners();
    };
  });

  // ─── DnD callbacks from TileGroup ──────────────────────────────────

  function handleDragStart(groupId: string, tabTarget: string) {
    dragState = {
      active: true,
      tabTarget,
      sourceGroupId: groupId,
      mouseX: 0,
      mouseY: 0,
      hoveredGroupId: null,
      targetZone: null,
    };
    finalizeProcessed = false;
    document.addEventListener('mousemove', handleGlobalMouseMove);
  }

  function handleGroupConsider(groupId: string, items: { id: string; [key: string]: unknown }[]) {
    const leaf = findLeafById(tree, groupId);
    if (!leaf) return;

    const itemIds = items
      .filter((it) => it.id !== SHADOW_PLACEHOLDER_ITEM_ID)
      .map((it) => it.id);

    // Check if a tab from this leaf is now missing (being dragged out)
    if (!dragState.active) {
      const missing = leaf.tabs.find((t) => !itemIds.includes(t));
      if (missing) {
        handleDragStart(groupId, missing);
      }
    }
  }

  function handleGroupFinalize(groupId: string, items: { id: string; [key: string]: unknown }[]) {
    // Guard: dndzone may fire finalize on both source and target zones
    // for cross-group center drops. Only process the first one.
    if (finalizeProcessed) return;
    finalizeProcessed = true;

    const finalTabs = items
      .filter((it) => it.id !== SHADOW_PLACEHOLDER_ITEM_ID)
      .map((it) => it.id);

    const zone = dragState.targetZone;
    const sourceGroupId = dragState.sourceGroupId;
    const tabTarget = dragState.tabTarget;
    const hoveredGroupId = dragState.hoveredGroupId;

    // End drag
    dragState = { ...dragState, active: false };
    cleanupDragListeners();

    // The true target is where the mouse is (hoveredGroupId), NOT the zone
    // where dndzone fired finalize (groupId). dndzone fires on the source
    // zone when the drop lands outside any tab bar element.
    const targetGroupId = hoveredGroupId || groupId;
    const isCrossGroup = sourceGroupId !== targetGroupId;
    const isEdge = zone != null && zone !== 'center';

    if (isEdge && tabTarget) {
      // Edge drop → split the target group
      let updated = tree;

      const sourceLeaf = findLeafByTab(updated, tabTarget);
      if (sourceLeaf) {
        updated = removeTabFromLeaf(updated, sourceLeaf.id, tabTarget);
      }

      updated = splitLeaf(updated, targetGroupId, zone, [tabTarget]);
      updated = prune(updated);

      // Safety: verify the tab ended up in the tree
      if (!findLeafByTab(updated, tabTarget)) {
        const fallback = findFirstLeaf(updated);
        if (fallback) {
          updated = addTabToLeaf(updated, fallback.id, tabTarget);
        }
      }

      tree = updated;
      tabMoved?.({ value: { tab: tabTarget, fromGroup: sourceGroupId, toGroup: targetGroupId + '-split' } });
      fireLayoutChanged();
    } else if (isCrossGroup && tabTarget) {
      // Center drop on different group → move tab there
      let updated = tree;

      const sourceLeaf = findLeafByTab(updated, tabTarget);
      if (sourceLeaf) {
        updated = removeTabFromLeaf(updated, sourceLeaf.id, tabTarget);
      }

      updated = addTabToLeaf(updated, targetGroupId, tabTarget);
      updated = prune(updated);

      // Safety: verify the tab ended up in the tree
      if (!findLeafByTab(updated, tabTarget)) {
        const fallback = findFirstLeaf(updated);
        if (fallback) {
          updated = addTabToLeaf(updated, fallback.id, tabTarget);
        }
      }

      tree = updated;
      tabMoved?.({ value: { tab: tabTarget, fromGroup: sourceGroupId, toGroup: targetGroupId } });
      fireLayoutChanged();
    } else {
      // Within-group reorder — but verify the dragged tab wasn't lost.
      // When dropped on a gutter or outside any group, dndzone returns
      // items WITHOUT the dragged tab. Ignore dndzone's items in that case.
      if (tabTarget && !finalTabs.includes(tabTarget)) {
        // Tab was dragged out but not dropped on a valid target — no-op,
        // the tree already has the correct state.
        return;
      }
      tree = mapLeafTabs(tree, groupId, finalTabs);
    }
  }

  /** Update a leaf's tabs array to match a new order. */
  function mapLeafTabs(node: TileNode, leafId: string, newTabs: string[]): TileNode {
    if (node.type === 'leaf') {
      if (node.id === leafId) {
        const selectedTab = newTabs.includes(node.selectedTab)
          ? node.selectedTab
          : (newTabs[0] ?? '');
        return { ...node, tabs: newTabs, selectedTab };
      }
      return node;
    }
    return {
      ...node,
      children: [
        mapLeafTabs(node.children[0], leafId, newTabs),
        mapLeafTabs(node.children[1], leafId, newTabs)
      ] as [TileNode, TileNode]
    };
  }

  // ─── Tab close ─────────────────────────────────────────────────────

  function handleTabClose(groupId: string, tabTarget: string) {
    tabClosed?.({ value: tabTarget });
  }

  // ─── Tab click ─────────────────────────────────────────────────────

  function handleTabClick(groupId: string, tabTarget: string) {
    tree = mapLeafSelected(tree, groupId, tabTarget);
  }

  function mapLeafSelected(node: TileNode, leafId: string, tab: string): TileNode {
    if (node.type === 'leaf') {
      return node.id === leafId ? { ...node, selectedTab: tab } : node;
    }
    return {
      ...node,
      children: [
        mapLeafSelected(node.children[0], leafId, tab),
        mapLeafSelected(node.children[1], leafId, tab)
      ] as [TileNode, TileNode]
    };
  }

  // ─── Gutter resize ────────────────────────────────────────────────

  let isResizing = $state(false);
  let resizeSplitId = '';
  let resizeDirection: 'horizontal' | 'vertical' = 'horizontal';
  let resizeStartPos = 0;
  let resizeStartRatio = 0;
  let resizeContainerSize = 0;

  function handleGutterDown(e: MouseEvent, gutter: GutterRect) {
    if (disabled) return;
    e.preventDefault();

    isResizing = true;
    resizeSplitId = gutter.splitId;
    resizeDirection = gutter.direction;
    resizeStartRatio = gutter.ratio;
    resizeStartPos = gutter.direction === 'horizontal' ? e.clientX : e.clientY;
    resizeContainerSize = gutter.availableSize;

    document.addEventListener('mousemove', handleResizeMove);
    document.addEventListener('mouseup', handleResizeUp);
  }

  function handleResizeMove(e: MouseEvent) {
    if (!isResizing || resizeContainerSize <= 0) return;
    if (e.buttons === 0) {
      handleResizeUp();
      return;
    }

    const currentPos = resizeDirection === 'horizontal' ? e.clientX : e.clientY;
    const delta = currentPos - resizeStartPos;
    const deltaPct = delta / resizeContainerSize;
    const newRatio = resizeStartRatio + deltaPct;

    tree = resizeSplit(tree, resizeSplitId, newRatio);
  }

  function handleResizeUp() {
    isResizing = false;
    resizeSplitId = '';
    cleanupResizeListeners();
    fireLayoutChanged();
  }

  // ─── Layout changed event ─────────────────────────────────────────

  function fireLayoutChanged() {
    layoutChanged?.({ value: JSON.stringify(tree) });
  }

  // ─── Svelte action for group element registration (hit-testing) ───

  function registerGroupAction(node: HTMLElement, params: { groupId: string }) {
    registerGroup(params.groupId, node);

    return {
      update(newParams: { groupId: string }) {
        unregisterGroup(params.groupId);
        params = newParams;
        registerGroup(params.groupId, node);
      },
      destroy() {
        unregisterGroup(params.groupId);
      }
    };
  }
</script>

<!--
  Flat rendering: all leaves + gutters are siblings with absolute positioning.
  Keyed {#each} preserves existing TileGroup instances when the tree mutates,
  which is critical for IC snippet mounts surviving splits/merges.
-->
<div class="ic-tl" class:ic-tl--resizing={isResizing} bind:this={containerEl}>
  <!-- Panels: rendered ONCE per target, keyed so they persist across tab moves -->
  {#each panelRects as panel (panel.target)}
    {@const panelEntry = childEntries[panel.target]?.[0]}
    <div
      class="ic-tl__panel"
      class:ic-tl__panel--active={panel.active}
      style="left:{panel.x}px;top:{panel.y}px;width:{panel.w}px;height:{panel.h}px;"
    >
      {#if panelEntry}
        {@render panelEntry.snippet()}
      {/if}
    </div>
  {/each}
  <!-- Tab bars + overlays (TileGroups) -->
  {#each layout.leaves as rect (rect.id)}
    <div
      class="ic-tl__leaf"
      style="left:{rect.x}px;top:{rect.y}px;width:{rect.w}px;height:{rect.h}px;"
      use:registerGroupAction={{ groupId: rect.id }}
    >
      <TileGroup
        groupId={rect.id}
        tabs={rect.leaf.tabs}
        selectedTab={rect.leaf.selectedTab}
        {size}
        {disabled}
        {dragEnabled}
        {childEntries}
        overlayZone={dragState.active && dragState.hoveredGroupId === rect.id
          ? dragState.targetZone : null}
        onTabClick={handleTabClick}
        onTabClose={handleTabClose}
        onDragStart={handleDragStart}
        onConsider={handleGroupConsider}
        onFinalize={handleGroupFinalize}
      />
    </div>
  {/each}
  {#each layout.gutters as gutter (gutter.splitId)}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div
      class="ic-tl__gutter"
      class:ic-tl__gutter--horizontal={gutter.direction === 'horizontal'}
      class:ic-tl__gutter--vertical={gutter.direction === 'vertical'}
      style="left:{gutter.x}px;top:{gutter.y}px;width:{gutter.w}px;height:{gutter.h}px;"
      onmousedown={(e) => handleGutterDown(e, gutter)}
      role="separator"
      aria-orientation={gutter.direction}
    ></div>
  {/each}
</div>

<style>
  /* -- Root (position context for absolute children) -- */
  .ic-tl {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: clip;
    font-family: var(--ic-font-family);
  }

  .ic-tl--resizing {
    user-select: none;
  }

  /* -- Panel (absolute, rendered at TileLayout level for snippet persistence) -- */
  .ic-tl__panel {
    position: absolute;
    overflow: auto;
    display: none;
  }

  .ic-tl__panel--active {
    display: block;
  }

  /* -- Leaf wrapper (absolute, hosts TileGroup tab bar + overlay) -- */
  .ic-tl__leaf {
    position: absolute;
    overflow: clip;
    min-width: 0;
    min-height: 0;
    z-index: 1;
    pointer-events: none;
  }

  /* Tab bar inside the leaf must receive pointer events */
  .ic-tl__leaf :global(.ic-tg__bar) {
    pointer-events: auto;
  }

  /* -- Gutter (absolute, between split children) -- */
  .ic-tl__gutter {
    position: absolute;
    background-color: var(--ic-border);
    transition: background-color 0.15s ease;
    z-index: 2;
  }

  .ic-tl__gutter--horizontal {
    cursor: col-resize;
  }

  .ic-tl__gutter--vertical {
    cursor: row-resize;
  }

  .ic-tl__gutter:hover {
    background-color: var(--ic-primary);
    opacity: 0.5;
  }
</style>
