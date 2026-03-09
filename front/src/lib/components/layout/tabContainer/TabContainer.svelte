<!--
  TabContainer.svelte — Tabbed container with closable, draggable tabs.

  Both Tab and TabPanel are direct children inserted into separate targets.
  Tab bar renders wrapper divs for each "tab-*" target with snippet inside.
  Content area renders show/hide divs for each "panel-*" target.

  Selection is target-based (e.g. "tab-0") and stable across deletes.
  Configs are keyed by target string for order-independent lookup.

  TabOverflow modes:
    - "scroll": horizontal scrollbar when tabs overflow
    - "wrap": tabs wrap to multiple rows
    - "menu": hidden tabs accessible via >> chevron popup

  DnD: svelte-dnd-action on the tab bar for reordering.
-->
<script lang="ts">
  import { setContext, tick } from 'svelte';
  import { flip } from 'svelte/animate';
  import { dndzone, SHADOW_ITEM_MARKER_PROPERTY_NAME, SHADOW_PLACEHOLDER_ITEM_ID } from 'svelte-dnd-action';
  import type { Snippets } from '$lib/types';
  import type { TabConfig, TabContainerContext } from './tab-types';
  import { resolveIcon } from '$lib/utils/icons';
  import logger from '$lib/core/logger';

  let {
    selectedTab = $bindable(''),
    tabOverflow = $bindable<'scroll' | 'wrap' | 'menu'>('scroll'),
    disabled = $bindable(false),
    size = $bindable<'sm' | 'md' | 'lg'>('md'),
    targets = $bindable<string[]>([]),
    valueChanged,
    tabClosed,
    tabReordered,
    snippets = {} as Snippets
  }: {
    selectedTab?: string;
    tabOverflow?: 'scroll' | 'wrap' | 'menu';
    disabled?: boolean;
    size?: 'sm' | 'md' | 'lg';
    targets?: string[];
    valueChanged?: (data: { value: string }) => void;
    tabClosed?: (data: { value: string }) => void;
    tabReordered?: (data: { value: string[] }) => void;
    snippets?: Snippets;
  } = $props();

  // --- Tab registration via context (target-keyed) ---

  let tabConfigMap = $state<Record<string, TabConfig>>({});

  // Derived: split targets into tab targets and panel targets
  const tabTargets = $derived(targets.filter((t) => t.startsWith('tab-')));
  const panelTargets = $derived(targets.filter((t) => t.startsWith('panel-')));

  // Context for Tab children — all methods are target-based
  const context: TabContainerContext = {
    registerTab(): string {
      // Tab.svelte mounts in {#each} order = tabTargets order.
      // Find the first target not yet in the config map.
      for (const t of tabTargets) {
        if (!(t in tabConfigMap)) {
          tabConfigMap[t] = { label: '', closable: false, disabled: false, icon: null };
          return t;
        }
      }
      return '';
    },

    updateTab(target: string, config: TabConfig) {
      // Pure write — no reactive reads! Reading `target in tabConfigMap`
      // inside an $effect creates a has→set cycle (effect_update_depth_exceeded).
      tabConfigMap[target] = { ...config };
    },

    deregisterTab(target: string) {
      if (target in tabConfigMap) {
        const copy = { ...tabConfigMap };
        delete copy[target];
        tabConfigMap = copy;
      }
    },

    get selectedTarget() {
      return selectedTab;
    },

    get containerDisabled() {
      return disabled;
    },

    get containerSize() {
      return size;
    },

    closeTab(target: string) {
      if (target) tabClosed?.({ value: target });
    }
  };

  setContext('ic-tab-container', context);

  // --- DnD state ---

  interface DndTabItem {
    id: string;
    [SHADOW_ITEM_MARKER_PROPERTY_NAME]?: boolean;
  }

  let dndItems = $state<DndTabItem[]>([]);
  let isDragging = false;
  const FLIP_MS = 150;

  // Sync dndItems from tabTargets when not dragging
  $effect(() => {
    if (!isDragging) {
      dndItems = tabTargets.map(t => ({ id: t }));
    }
  });

  function handleConsider(e: CustomEvent<{ items: DndTabItem[] }>) {
    isDragging = true;
    dndItems = e.detail.items;
    // svelte-dnd-action's preventShrinking() locks min-height/min-width on the
    // zone via inline styles. Undo it — our shadow element preserves bar height.
    if (barEl) {
      barEl.style.minHeight = '';
      barEl.style.minWidth = '';
    }
  }

  function handleFinalize(e: CustomEvent<{ items: DndTabItem[] }>) {
    isDragging = false;
    dndItems = e.detail.items;
    logger.debug('TabContainer', 'handleFinalize', {
      clientWidth: barEl?.clientWidth,
      scrollWidth: barEl?.scrollWidth,
      parentWidth: barEl?.parentElement?.clientWidth,
      inlineMinWidth: barEl?.style.minWidth,
      inlineMinHeight: barEl?.style.minHeight,
    });

    // Rebuild full targets array (interleave tab + panel pairs)
    const newTargets: string[] = [];
    for (const item of dndItems) {
      if (item.id === SHADOW_PLACEHOLDER_ITEM_ID) continue;
      const suffix = item.id.replace('tab-', '');
      newTargets.push(`tab-${suffix}`, `panel-${suffix}`);
    }

    targets = newTargets;
    tabReordered?.({
      value: dndItems
        .filter(it => it.id !== SHADOW_PLACEHOLDER_ITEM_ID)
        .map(it => it.id)
    });

    // Re-measure after reorder in menu mode
    if (tabOverflow === 'menu') {
      measureAndCompute();
    }
  }

  // --- Tab click ---

  function handleTabClick(target: string) {
    const config = tabConfigMap[target];
    if (disabled || config?.disabled) return;
    selectedTab = target;
    valueChanged?.({ value: target });
    closeMenu();
  }

  // --- Keyboard navigation ---

  function handleKeyDown(e: KeyboardEvent) {
    if (disabled) return;

    if (e.key === 'Escape' && menuOpen) {
      closeMenu();
      return;
    }

    const n = tabTargets.length;
    if (n === 0) return;

    const currentIdx = tabTargets.indexOf(selectedTab);
    let current = currentIdx >= 0 ? currentIdx : 0;

    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      let next = (current + 1) % n;
      for (let tries = 0; tries < n; tries++) {
        if (!tabConfigMap[tabTargets[next]]?.disabled) break;
        next = (next + 1) % n;
      }
      selectedTab = tabTargets[next];
      valueChanged?.({ value: selectedTab });
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      let prev = (current - 1 + n) % n;
      for (let tries = 0; tries < n; tries++) {
        if (!tabConfigMap[tabTargets[prev]]?.disabled) break;
        prev = (prev - 1 + n) % n;
      }
      selectedTab = tabTargets[prev];
      valueChanged?.({ value: selectedTab });
    } else if (e.key === 'Home') {
      e.preventDefault();
      for (let i = 0; i < n; i++) {
        if (!tabConfigMap[tabTargets[i]]?.disabled) {
          selectedTab = tabTargets[i];
          valueChanged?.({ value: selectedTab });
          break;
        }
      }
    } else if (e.key === 'End') {
      e.preventDefault();
      for (let i = n - 1; i >= 0; i--) {
        if (!tabConfigMap[tabTargets[i]]?.disabled) {
          selectedTab = tabTargets[i];
          valueChanged?.({ value: selectedTab });
          break;
        }
      }
    }
  }

  // --- Menu overflow mode ---

  const CHEVRON_WIDTH = 32;

  let barEl: HTMLDivElement;
  let barWrapEl: HTMLDivElement;
  let tabElMap = $state<Record<string, HTMLDivElement>>({});
  let menuOpen = $state(false);
  let hiddenTargets = $state<Set<string>>(new Set());
  let cachedWidths: Record<string, number> = {};

  const hasHidden = $derived(hiddenTargets.size > 0);

  /** Full re-measure: show all tabs, measure widths, then recompute hidden set. */
  function measureAndCompute() {
    if (tabOverflow !== 'menu' || !barEl) {
      hiddenTargets = new Set();
      return;
    }
    // Clear hidden so all tabs are in the DOM for measurement.
    // overflow:clip on the bar prevents visual flash.
    hiddenTargets = new Set();

    tick().then(() => {
      requestAnimationFrame(() => {
        const cs = window.getComputedStyle(barEl);
        logger.debug('TabContainer', 'measureAndCompute rAF', {
          clientWidth: barEl.clientWidth,
          scrollWidth: barEl.scrollWidth,
          offsetWidth: barEl.offsetWidth,
          parentClientWidth: barEl.parentElement?.clientWidth,
          computedOverflow: cs.overflow,
          computedMinWidth: cs.minWidth,
          computedWidth: cs.width,
          inlineMinWidth: barEl.style.minWidth,
          childCount: barEl.children.length,
        });
        cachedWidths = {};
        for (const t of tabTargets) {
          cachedWidths[t] = tabElMap[t]?.offsetWidth ?? 0;
        }
        recomputeHidden();
      });
    });
  }

  /** Recompute which tabs are hidden using cached widths. */
  function recomputeHidden() {
    if (!barEl || Object.keys(cachedWidths).length === 0) return;

    const barWidth = barEl.clientWidth;
    logger.debug('TabContainer', 'recomputeHidden', {
      barWidth,
      scrollWidth: barEl.scrollWidth,
      parentWidth: barEl.parentElement?.clientWidth,
      totalTabWidth: tabTargets.reduce((s, t) => s + (cachedWidths[t] ?? 0), 0),
    });
    const totalWidth = tabTargets.reduce((sum, t) => sum + (cachedWidths[t] ?? 0), 0);

    // Everything fits — no chevron needed
    if (totalWidth <= barWidth) {
      hiddenTargets = new Set();
      return;
    }

    // Budget = bar width minus chevron button
    const available = barWidth - CHEVRON_WIDTH;
    const hidden = new Set<string>();

    // Pass 1: greedily fit tabs left-to-right
    let used = 0;
    for (const t of tabTargets) {
      const w = cachedWidths[t] ?? 0;
      if (used + w <= available) {
        used += w;
      } else {
        hidden.add(t);
      }
    }

    // Pass 2: ensure selected tab is visible
    if (selectedTab && hidden.has(selectedTab)) {
      hidden.delete(selectedTab);
      used += cachedWidths[selectedTab] ?? 0;
      // Hide rightmost visible tabs until budget fits
      for (let i = tabTargets.length - 1; i >= 0 && used > available; i--) {
        const t = tabTargets[i];
        if (t === selectedTab || hidden.has(t)) continue;
        hidden.add(t);
        used -= cachedWidths[t] ?? 0;
      }
    }

    hiddenTargets = hidden;
  }

  // Re-measure when tab set, configs, or size changes
  $effect(() => {
    void tabTargets;
    void tabConfigMap;
    void size;
    void tabOverflow;

    if (tabOverflow === 'menu') {
      measureAndCompute();
    } else {
      hiddenTargets = new Set();
    }
  });

  // Re-allocate (no re-measure) when selection changes
  $effect(() => {
    void selectedTab;
    if (tabOverflow === 'menu' && Object.keys(cachedWidths).length > 0) {
      recomputeHidden();
    }
  });

  // ResizeObserver on bar — catches parent sizing, window resize, and layout shifts.
  // The initial tick+rAF measurement can miss the final size when the uihtml panel
  // hasn't finished sizing yet. The observer re-measures when the bar's width changes.
  $effect(() => {
    if (tabOverflow !== 'menu' || !barEl) return;
    let lastWidth = 0;
    const ro = new ResizeObserver((entries) => {
      const w = barEl.clientWidth;
      const entry = entries[0];
      logger.debug('TabContainer', 'ResizeObserver fired', {
        clientWidth: w,
        scrollWidth: barEl.scrollWidth,
        parentWidth: barEl.parentElement?.clientWidth,
        borderBoxWidth: entry?.borderBoxSize?.[0]?.inlineSize,
        contentBoxWidth: entry?.contentBoxSize?.[0]?.inlineSize,
        lastWidth,
        changed: w !== lastWidth,
      });
      if (w !== lastWidth && w > 0) {
        lastWidth = w;
        if (Object.keys(cachedWidths).length > 0) {
          recomputeHidden();
        } else {
          measureAndCompute();
        }
      }
    });
    ro.observe(barEl);
    return () => ro.disconnect();
  });

  // --- Menu popup open/close ---

  function openMenu() {
    if (menuOpen) return;
    menuOpen = true;
    requestAnimationFrame(() => {
      document.addEventListener('pointerdown', handleMenuClickOutside);
    });
  }

  function closeMenu() {
    if (!menuOpen) return;
    menuOpen = false;
    document.removeEventListener('pointerdown', handleMenuClickOutside);
  }

  function toggleMenu() {
    if (menuOpen) closeMenu();
    else openMenu();
  }

  function handleMenuClickOutside(e: PointerEvent) {
    const target = e.target as Node;
    if (barWrapEl && !barWrapEl.contains(target)) {
      closeMenu();
    }
  }

  function handleMenuTabClick(target: string) {
    const config = tabConfigMap[target];
    if (disabled || config?.disabled) return;
    selectedTab = target;
    valueChanged?.({ value: target });
    closeMenu();
  }

  // Ordered list of hidden targets for the menu dropdown (preserves tab order)
  const hiddenTargetsList = $derived(
    tabTargets.filter(t => hiddenTargets.has(t))
  );
</script>

<div class="ic-tc" class:ic-tc--disabled={disabled}>
  <!-- Bar wrapper (positioning context for menu popup) -->
  <div class="ic-tc__bar-wrap" bind:this={barWrapEl}>
    <div
      bind:this={barEl}
      class="ic-tc__bar"
      class:ic-tc__bar--scroll={tabOverflow === 'scroll'}
      class:ic-tc__bar--wrap={tabOverflow === 'wrap'}
      class:ic-tc__bar--menu={tabOverflow === 'menu'}
      class:ic-tc__bar--sm={size === 'sm'}
      class:ic-tc__bar--md={size === 'md'}
      class:ic-tc__bar--lg={size === 'lg'}
      role="tablist"
      tabindex="0"
      aria-orientation="horizontal"
      onkeydown={handleKeyDown}
      use:dndzone={{
        items: dndItems,
        flipDurationMs: FLIP_MS,
        type: 'ic-tab-reorder',
        dragDisabled: disabled,
        dropTargetStyle: {},
        zoneTabIndex: -1,
        centreDraggedOnCursor: true,
      }}
      onconsider={handleConsider}
      onfinalize={handleFinalize}
    >
      {#each dndItems as item (item.id)}
        {@const target = item.id}
        {@const isShadow = item[SHADOW_ITEM_MARKER_PROPERTY_NAME]}
        {@const config = tabConfigMap[target]}
        {@const active = target === selectedTab}
        {@const isHidden = tabOverflow === 'menu' && hiddenTargets.has(target)}
        {@const tabSnippet = snippets[target]?.[0]}
        <div
          bind:this={tabElMap[target]}
          class="ic-tc__tab"
          class:ic-tc__tab--active={active}
          class:ic-tc__tab--disabled={config?.disabled}
          class:ic-tc__tab--menu-hidden={isHidden}
          class:ic-tc__tab--shadow={isShadow}
          role="tab"
          aria-selected={active}
          aria-disabled={config?.disabled}
          tabindex={active ? 0 : -1}
          onclick={() => handleTabClick(target)}
          onkeydown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              handleTabClick(target);
            }
          }}
          animate:flip={{ duration: FLIP_MS }}
        >
          <span class="ic-tc__indicator" class:ic-tc__indicator--active={active}></span>
          {#if tabSnippet}
            {@render tabSnippet()}
          {/if}
        </div>
      {/each}
    </div>

    <!-- Chevron overflow button (absolutely positioned over bar) -->
    {#if tabOverflow === 'menu' && hasHidden}
      <button
        class="ic-tc__chevron"
        class:ic-tc__chevron--open={menuOpen}
        tabindex={-1}
        aria-label="Show hidden tabs"
        aria-expanded={menuOpen}
        onclick={toggleMenu}
      >
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M2 4L5 7L2 10" stroke="currentColor" stroke-width="1.5"
                stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M6.5 4L9.5 7L6.5 10" stroke="currentColor" stroke-width="1.5"
                stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
    {/if}

    <!-- Hidden tabs popup (positioned relative to bar-wrap) -->
    {#if tabOverflow === 'menu' && menuOpen}
      <div class="ic-tc__menu" role="menu">
        {#each hiddenTargetsList as target (target)}
          {@const config = tabConfigMap[target]}
          {@const active = target === selectedTab}
          <div
            class="ic-tc__menu-item"
            class:ic-tc__menu-item--active={active}
            class:ic-tc__menu-item--disabled={config?.disabled}
            role="menuitem"
            tabindex={-1}
            onclick={() => handleMenuTabClick(target)}
            onkeydown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                handleMenuTabClick(target);
              }
            }}
          >
            {#if config?.icon}
              {@const iconSvg = resolveIcon(config.icon, 14)}
              {#if iconSvg}
                <span class="ic-tc__menu-icon">{@html iconSvg}</span>
              {/if}
            {/if}
            <span class="ic-tc__menu-label">{config?.label ?? ''}</span>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Content panels -->
  <div class="ic-tc__content">
    {#each panelTargets as target (target)}
      {@const tabTarget = 'tab-' + target.replace('panel-', '')}
      {@const active = tabTarget === selectedTab}
      {@const panelSnippet = snippets[target]?.[0]}
      <div
        class="ic-tc__panel"
        class:ic-tc__panel--active={active}
        role="tabpanel"
        aria-hidden={!active}
      >
        {#if panelSnippet}
          {@render panelSnippet()}
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  /* ── Container ── */
  .ic-tc {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    overflow: clip;
    font-family: var(--ic-font-family);
    font-size: var(--ic-font-size);
  }

  .ic-tc--disabled {
    opacity: 0.65;
    pointer-events: none;
  }

  /* ── Bar wrapper ── */
  .ic-tc__bar-wrap {
    position: relative;
    flex-shrink: 0;
    min-width: 0;
  }

  /* ── Tab bar ── */
  .ic-tc__bar {
    display: flex;
    align-items: stretch;
    background-color: var(--ic-secondary);
    border-bottom: 1px solid var(--ic-border);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    flex-shrink: 0;
    min-height: 0;
  }

  .ic-tc__bar--scroll {
    overflow-x: auto;
    overflow-y: hidden;
  }
  .ic-tc__bar--scroll::-webkit-scrollbar {
    height: 3px;
  }
  .ic-tc__bar--scroll::-webkit-scrollbar-thumb {
    background: var(--ic-muted-foreground);
    border-radius: 1px;
  }
  .ic-tc__bar--scroll::-webkit-scrollbar-track {
    background: transparent;
  }

  .ic-tc__bar--wrap {
    flex-wrap: wrap;
  }

  .ic-tc__bar--menu {
    flex-wrap: nowrap;
    overflow: clip;
  }

  /* ── Tab button ── */
  .ic-tc__tab {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border: none;
    border-radius: 0;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: grab;
    white-space: nowrap;
    user-select: none;
    flex-shrink: 0;
    transition: background-color 0.12s ease, color 0.12s ease;
    font-family: inherit;
  }

  /* Sizes */
  .ic-tc__bar--sm .ic-tc__tab { padding: 4px 10px; font-size: 0.75rem; }
  .ic-tc__bar--md .ic-tc__tab { padding: 6px 14px; font-size: 0.8125rem; }
  .ic-tc__bar--lg .ic-tc__tab { padding: 8px 18px; font-size: 0.875rem; }

  /* Hover */
  .ic-tc__tab:hover:not(.ic-tc__tab--disabled):not(.ic-tc__tab--active) {
    background-color: rgba(255, 255, 255, 0.04);
    color: var(--ic-foreground);
  }

  /* Active */
  .ic-tc__tab--active {
    background-color: var(--ic-background);
    color: var(--ic-foreground);
    cursor: grab;
  }

  /* Focus */
  .ic-tc__tab:focus-visible {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
  }

  /* Disabled */
  .ic-tc__tab--disabled {
    opacity: 0.4;
    cursor: default;
  }

  /* Hidden in menu mode */
  .ic-tc__tab--menu-hidden {
    display: none;
  }

  /* Shadow placeholder during drag */
  .ic-tc__tab--shadow {
    opacity: 0.4;
    border-style: dashed;
    background: var(--ic-secondary);
  }

  /* ── Left indicator ── */
  .ic-tc__indicator {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    border-radius: 0;
    background: transparent;
    transition: background-color 0.15s ease;
  }

  .ic-tc__indicator--active {
    background-color: var(--ic-primary);
  }

  /* ── Icon (rendered by Tab.svelte) ── */
  .ic-tc__tab :global(.ic-tc__icon) {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: inherit;
    line-height: 0;
  }

  /* ── Label (rendered by Tab.svelte) ── */
  .ic-tc__tab :global(.ic-tc__label) {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    line-height: 1.2;
  }

  /* ── Close button (rendered by Tab.svelte) ── */
  .ic-tc__tab :global(.ic-tc__close) {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    border-radius: 50%;
    width: 14px;
    height: 14px;
    opacity: 0;
    transition: opacity 0.12s ease, color 0.12s ease, background-color 0.12s ease;
    line-height: 0;
  }
  .ic-tc__tab :global(.ic-tc__close svg) { width: 8px; height: 8px; }

  /* Show close button on tab hover */
  .ic-tc__tab:hover :global(.ic-tc__close),
  .ic-tc__tab--active :global(.ic-tc__close) {
    opacity: 0.7;
  }

  .ic-tc__tab :global(.ic-tc__close:hover) {
    opacity: 1;
    background-color: rgba(220, 50, 50, 0.15);
    color: var(--ic-destructive);
  }

  /* ── Chevron >> button ── */
  .ic-tc__chevron {
    position: absolute;
    right: 0;
    top: 0;
    bottom: 0;
    z-index: 2;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    cursor: pointer;
    width: 32px;
    padding: 0;
    border-left: 1px solid var(--ic-border);
    transition: background-color 0.12s ease, color 0.12s ease;
  }

  .ic-tc__chevron:hover {
    background-color: rgba(255, 255, 255, 0.06);
    color: var(--ic-foreground);
  }

  .ic-tc__chevron--open {
    background-color: var(--ic-background);
    color: var(--ic-foreground);
  }

  /* ── Menu popup ── */
  .ic-tc__menu {
    position: absolute;
    z-index: 50;
    top: 100%;
    right: 0;
    min-width: 140px;
    max-width: 240px;
    max-height: 200px;
    overflow-y: auto;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.18);
    padding: 2px 0;
  }

  .ic-tc__menu-item {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    cursor: pointer;
    color: var(--ic-foreground);
    font-size: inherit;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    transition: background-color 0.1s ease;
    user-select: none;
  }

  .ic-tc__menu-item:hover:not(.ic-tc__menu-item--disabled) {
    background-color: var(--ic-secondary);
  }

  .ic-tc__menu-item--active {
    color: var(--ic-primary);
  }

  .ic-tc__menu-item--disabled {
    opacity: 0.4;
    cursor: default;
  }

  .ic-tc__menu-icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    line-height: 0;
  }

  .ic-tc__menu-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  /* ── Content area ── */
  .ic-tc__content {
    flex: 1;
    overflow: auto;
    min-height: 0;
    min-width: 0;
  }

  .ic-tc__panel {
    display: none;
    width: 100%;
    height: 100%;
  }

  .ic-tc__panel--active {
    display: block;
  }
</style>
