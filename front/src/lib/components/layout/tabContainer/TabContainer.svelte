<!--
  TabContainer.svelte — Tabbed container with closable, draggable tabs.

  Tab config is derived from the ChildEntry system:
  - IC framework: Tab components are inserted as children, their reactive props
    (label, closable, disabled, editable, icon) are accessed via childEntries proxy.
  - Standalone Svelte: tabConfigs prop provides static config directly.

  Selection is target-based (e.g. "tab-0") and stable across deletes.

  TabOverflow modes:
    - "scroll": horizontal scrollbar when tabs overflow
    - "wrap": tabs wrap to multiple rows
    - "menu": hidden tabs accessible via >> chevron popup

  DnD: svelte-dnd-action on the tab bar for reordering.
-->
<script lang="ts">
  import { tick } from 'svelte';
  import { flip } from 'svelte/animate';
  import { dndzone, SHADOW_ITEM_MARKER_PROPERTY_NAME, SHADOW_PLACEHOLDER_ITEM_ID } from 'svelte-dnd-action';
  import type { ChildEntries, ChildEntry } from '$lib/types';
  import type { TabConfig } from './tab-types';
  import { resolveIcon, type IconSource } from '$lib/utils/icons';

  const ICON_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };

  interface AttachTabParams {
    entry: ChildEntry | undefined;
    target: string;
  }

  /**
   * Svelte action: attach an IC Tab component into the tab header element.
   * Runs synchronously on element creation so there's no flash of empty content.
   * Also listens for the bubbling "ic-tab-close" CustomEvent from Tab.svelte.
   */
  function attachTab(node: HTMLElement, params: AttachTabParams) {
    let { entry, target } = params;

    if (entry?.attach) entry.attach(node);

    const onClose = () => tabClosed?.({ value: target });
    node.addEventListener('ic-tab-close', onClose);

    return {
      update(newParams: AttachTabParams) {
        if (entry?.detach) entry.detach();
        ({ entry, target } = newParams);
        if (entry?.attach) entry.attach(node);
      },
      destroy() {
        node.removeEventListener('ic-tab-close', onClose);
        if (entry?.detach) entry.detach();
      }
    };
  }

  let {
    selectedTab = $bindable(''),
    tabOverflow = $bindable<'scroll' | 'wrap' | 'menu'>('scroll'),
    disabled = $bindable(false),
    dragEnabled = $bindable(true),
    size = $bindable<'sm' | 'md' | 'lg'>('md'),
    targets = $bindable<string[]>([]),
    valueChanged,
    tabClosed,
    tabReordered,
    tabRenamed,
    childEntries = {} as ChildEntries,
    tabConfigs,
  }: {
    selectedTab?: string;
    tabOverflow?: 'scroll' | 'wrap' | 'menu';
    disabled?: boolean;
    dragEnabled?: boolean;
    size?: 'sm' | 'md' | 'lg';
    targets?: string[];
    valueChanged?: (data: { value: string }) => void;
    tabClosed?: (data: { value: string }) => void;
    tabReordered?: (data: { value: string[] }) => void;
    tabRenamed?: (data: { value: { target: string; label: string } }) => void;
    childEntries?: ChildEntries;
    tabConfigs?: Record<string, TabConfig>;
  } = $props();

  // --- Tab config resolution ---

  /**
   * Get tab config from IC ChildEntry proxy or standalone tabConfigs.
   * IC-backed entries have reactive props (label, icon, etc.) via proxy.
   * Standalone usage provides static config via tabConfigs prop.
   */
  function getConfig(target: string): TabConfig | undefined {
    const entry = childEntries[target]?.[0];
    if (entry && entry.props.label !== undefined) {
      return {
        label: (entry.props.label as string) ?? '',
        closable: tabTargets.length > 1 && ((entry.props.closable as boolean) ?? false),
        disabled: (entry.props.disabled as boolean) ?? false,
        editable: (entry.props.editable as boolean) ?? false,
        icon: (entry.props.icon as IconSource) ?? null,
      };
    }
    return tabConfigs?.[target];
  }

  const tabTargets = $derived(targets.filter((t) => t.startsWith('tab-')));
  const panelTargets = $derived(targets.filter((t) => t.startsWith('panel-')));

  // --- DnD ---

  interface DndTabItem {
    id: string;
    [SHADOW_ITEM_MARKER_PROPERTY_NAME]?: boolean;
  }

  let dndItems = $state<DndTabItem[]>([]);
  let isDragging = $state(false);
  const FLIP_MS = 150;

  $effect(() => {
    if (!isDragging) {
      dndItems = tabTargets.map(t => ({ id: t }));
    }
  });

  function handleConsider(e: CustomEvent<{ items: DndTabItem[] }>) {
    isDragging = true;
    dndItems = e.detail.items;
    // Undo preventShrinking() inline styles set by svelte-dnd-action
    if (barEl) {
      barEl.style.minHeight = '';
      barEl.style.minWidth = '';
    }
    // Set on :root so the cloned drag ghost (outside barEl) also inherits it
    document.documentElement.style.setProperty('--_tc-cursor', 'grabbing');
  }

  function handleFinalize(e: CustomEvent<{ items: DndTabItem[] }>) {
    isDragging = false;
    document.documentElement.style.removeProperty('--_tc-cursor');
    dndItems = e.detail.items;
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

    if (tabOverflow === 'menu') {
      measureAndCompute();
    }
  }

  // --- Tab interaction ---

  function handleTabClick(target: string) {
    const config = getConfig(target);
    if (disabled || config?.disabled) return;
    selectedTab = target;
    valueChanged?.({ value: target });
    closeMenu();
  }

  function handleClose(e: PointerEvent, target: string) {
    e.stopPropagation();
    e.preventDefault();
    tabClosed?.({ value: target });
  }

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
        if (!getConfig(tabTargets[next])?.disabled) break;
        next = (next + 1) % n;
      }
      selectedTab = tabTargets[next];
      valueChanged?.({ value: selectedTab });
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      let prev = (current - 1 + n) % n;
      for (let tries = 0; tries < n; tries++) {
        if (!getConfig(tabTargets[prev])?.disabled) break;
        prev = (prev - 1 + n) % n;
      }
      selectedTab = tabTargets[prev];
      valueChanged?.({ value: selectedTab });
    } else if (e.key === 'Home') {
      e.preventDefault();
      for (let i = 0; i < n; i++) {
        if (!getConfig(tabTargets[i])?.disabled) {
          selectedTab = tabTargets[i];
          valueChanged?.({ value: selectedTab });
          break;
        }
      }
    } else if (e.key === 'End') {
      e.preventDefault();
      for (let i = n - 1; i >= 0; i--) {
        if (!getConfig(tabTargets[i])?.disabled) {
          selectedTab = tabTargets[i];
          valueChanged?.({ value: selectedTab });
          break;
        }
      }
    }
  }

  // --- Overflow menu ---

  const CHEVRON_WIDTH = 32;

  let barEl: HTMLDivElement;
  let barWrapEl: HTMLDivElement;
  let tabElMap = $state<Record<string, HTMLDivElement>>({});
  let menuOpen = $state(false);
  let hiddenTargets = $state<Set<string>>(new Set());
  let cachedWidths: Record<string, number> = {};

  const hasHidden = $derived(hiddenTargets.size > 0);

  let isMeasuring = false;

  /** Show all tabs, measure widths, then recompute hidden set. */
  function measureAndCompute() {
    if (tabOverflow !== 'menu' || !barEl || isMeasuring) {
      if (!isMeasuring && tabOverflow !== 'menu') hiddenTargets = new Set();
      return;
    }
    isMeasuring = true;

    // Force hidden tabs visible via inline style (don't clear hiddenTargets
    // or the chevron flashes away during measurement)
    for (const t of tabTargets) {
      const el = tabElMap[t];
      if (el) el.style.display = 'inline-flex';
    }

    tick().then(() => {
      requestAnimationFrame(() => {
        isMeasuring = false;
        cachedWidths = {};
        for (const t of tabTargets) {
          const el = tabElMap[t];
          if (el) {
            cachedWidths[t] = el.offsetWidth;
            el.style.display = ''; // clear inline override
          }
        }
        recomputeHidden();
      });
    });
  }

  /** Recompute hidden set from cached widths. */
  function recomputeHidden() {
    if (!barEl || Object.keys(cachedWidths).length === 0) return;

    // Spot-check: stale widths -> re-measure
    const probe = tabTargets[0];
    if (probe && tabElMap[probe]) {
      const actual = tabElMap[probe].offsetWidth;
      if (Math.abs(actual - (cachedWidths[probe] ?? 0)) > 2) {
        measureAndCompute();
        return;
      }
    }

    const barWidth = barEl.clientWidth;
    const totalWidth = tabTargets.reduce((sum, t) => sum + (cachedWidths[t] ?? 0), 0);

    if (totalWidth <= barWidth) {
      hiddenTargets = new Set();
      return;
    }

    const available = barWidth - CHEVRON_WIDTH;
    const hidden = new Set<string>();

    let used = 0;
    for (const t of tabTargets) {
      const w = cachedWidths[t] ?? 0;
      if (used + w <= available) {
        used += w;
      } else {
        hidden.add(t);
      }
    }

    // Ensure selected tab stays visible
    if (selectedTab && hidden.has(selectedTab)) {
      hidden.delete(selectedTab);
      used += cachedWidths[selectedTab] ?? 0;
      for (let i = tabTargets.length - 1; i >= 0 && used > available; i--) {
        const t = tabTargets[i];
        if (t === selectedTab || hidden.has(t)) continue;
        hidden.add(t);
        used -= cachedWidths[t] ?? 0;
      }
    }

    hiddenTargets = hidden;
  }

  $effect(() => {
    void tabTargets; void size; void tabOverflow;
    if (tabOverflow === 'menu') {
      measureAndCompute();
    } else {
      hiddenTargets = new Set();
    }
  });

  $effect(() => {
    void selectedTab;
    if (tabOverflow === 'menu' && Object.keys(cachedWidths).length > 0) {
      recomputeHidden();
    }
  });

  // ResizeObserver: recompute on bar resize
  $effect(() => {
    if (tabOverflow !== 'menu' || !barEl) return;
    let lastWidth = 0;
    const ro = new ResizeObserver(() => {
      const w = barEl.clientWidth;
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

  // MutationObserver: re-measure when content changes
  $effect(() => {
    if (tabOverflow !== 'menu' || !barEl) return;
    let pending = false;
    const mo = new MutationObserver(() => {
      if (pending || isMeasuring) return;
      const probe = tabTargets[0];
      if (!probe || !tabElMap[probe] || cachedWidths[probe] === undefined) return;
      const actual = tabElMap[probe].offsetWidth;
      if (Math.abs(actual - cachedWidths[probe]) > 2) {
        pending = true;
        requestAnimationFrame(() => {
          pending = false;
          measureAndCompute();
        });
      }
    });
    mo.observe(barEl, { childList: true, subtree: true, characterData: true });
    return () => mo.disconnect();
  });

  // --- Inline editing ---

  let editingTarget = $state<string | null>(null);
  let editValue = $state('');

  function startEditing(target: string) {
    const config = getConfig(target);
    if (!config?.editable || disabled || config.disabled) return;
    editingTarget = target;
    editValue = config.label;
  }

  function commitEdit() {
    if (!editingTarget) return;
    const target = editingTarget;
    editingTarget = null;
    const trimmed = editValue.trim();
    if (trimmed && trimmed !== getConfig(target)?.label) {
      // Update via ChildEntry proxy for instant reactivity
      const entry = childEntries[target]?.[0];
      if (entry && entry.props.label !== undefined) {
        entry.props.label = trimmed;
      }
      tabRenamed?.({ value: { target, label: trimmed } });
    }
  }

  function cancelEdit() {
    editingTarget = null;
  }

  function handleEditKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      commitEdit();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      cancelEdit();
    }
  }

  // --- Menu ---

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
      class:ic-tc__bar--single={tabTargets.length <= 1}
      role="tablist"
      tabindex="0"
      aria-orientation="horizontal"
      onkeydown={handleKeyDown}
      use:dndzone={{
        items: dndItems,
        flipDurationMs: FLIP_MS,
        type: 'ic-tab-reorder',
        dragDisabled: disabled || !dragEnabled,
        dropTargetStyle: {},
        morphDisabled: true,
        zoneTabIndex: -1,
        centreDraggedOnCursor: true,
      }}
      onconsider={handleConsider}
      onfinalize={handleFinalize}
    >
      {#each dndItems as item (item.id)}
        {@const target = item.id}
        {@const isShadow = item[SHADOW_ITEM_MARKER_PROPERTY_NAME]}
        {@const config = getConfig(target)}
        {@const active = target === selectedTab}
        {@const isHidden = tabOverflow === 'menu' && hiddenTargets.has(target)}
        {@const isEditing = editingTarget === target}
        {@const tabEntry = childEntries[target]?.[0]}
        <div
          bind:this={tabElMap[target]}
          class="ic-tc__tab"
          class:ic-tc__tab--active={active}
          class:ic-tc__tab--disabled={config?.disabled}
          class:ic-tc__tab--menu-hidden={isHidden}
          class:ic-tc__tab--shadow={isShadow}
          class:ic-tc__tab--editing={isEditing}
          role="tab"
          aria-selected={active}
          aria-disabled={config?.disabled}
          tabindex={active ? 0 : -1}
          onclick={() => handleTabClick(target)}
          ondblclick={() => startEditing(target)}
          onkeydown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              handleTabClick(target);
            }
          }}
          animate:flip={{ duration: FLIP_MS }}
          use:attachTab={{ entry: tabEntry, target }}
        >
          {#if isEditing}
            <!-- svelte-ignore a11y_autofocus -->
            <input
              class="ic-tc__edit-input"
              type="text"
              bind:value={editValue}
              onblur={commitEdit}
              onkeydown={handleEditKeyDown}
              onclick={(e) => e.stopPropagation()}
              onmousedown={(e) => e.stopPropagation()}
              autofocus
            />
          {:else if !tabEntry?.attach && config}
            <!-- Fallback: standalone usage without IC Tab component -->
            <span class="ic-tab__indicator"></span>
            {#if config.icon}
              {@const iconSvg = resolveIcon(config.icon, ICON_SIZES[size] ?? 14)}
              {#if iconSvg}
                <span class="ic-tab__icon">{@html iconSvg}</span>
              {/if}
            {/if}
            <span class="ic-tab__label">{config.label}</span>
            {#if config.closable && !disabled}
              <!-- svelte-ignore a11y_no_static_element_interactions -->
              <button
                class="ic-tab__close"
                tabindex={-1}
                aria-label="Close {config.label}"
                onpointerdown={(e) => handleClose(e, target)}
              >
                <svg width="8" height="8" viewBox="0 0 10 10" fill="none">
                  <path d="M7.5 2.5L2.5 7.5M2.5 2.5L7.5 7.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                </svg>
              </button>
            {/if}
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
          {@const config = getConfig(target)}
          {@const active = target === selectedTab}
          <div
            class="ic-tc__menu-item"
            class:ic-tc__menu-item--active={active}
            class:ic-tc__menu-item--disabled={config?.disabled}
            role="menuitem"
            tabindex={-1}
            onclick={() => handleTabClick(target)}
            onkeydown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                handleTabClick(target);
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
      {@const panelEntry = childEntries[target]?.[0]}
      <div
        class="ic-tc__panel"
        class:ic-tc__panel--active={active}
        role="tabpanel"
        aria-hidden={!active}
      >
        {#if panelEntry?.snippet}
          {@render panelEntry.snippet()}
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  /* -- Container -- */
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

  /* -- Bar wrapper -- */
  .ic-tc__bar-wrap {
    position: relative;
    flex-shrink: 0;
    min-width: 0;
  }

  /* -- Tab bar -- */
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
    scrollbar-width: none;
  }
  .ic-tc__bar--scroll::-webkit-scrollbar {
    display: none;
  }

  .ic-tc__bar--wrap {
    flex-wrap: wrap;
  }

  .ic-tc__bar--menu {
    flex-wrap: nowrap;
    overflow: clip;
  }

  /* -- Tab button -- */
  .ic-tc__tab {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border: 1px solid transparent;
    border-radius: 0;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: var(--_tc-cursor, pointer) !important;
    white-space: nowrap;
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
    border-color: var(--ic-border);
    background: var(--ic-secondary);
  }

  /* Editing state: hide attached Tab content, show edit input */
  .ic-tc__tab--editing {
    cursor: text;
  }
  .ic-tc__tab--editing :global(.ic-tab__indicator),
  .ic-tc__tab--editing :global(.ic-tab__icon),
  .ic-tc__tab--editing :global(.ic-tab__label),
  .ic-tc__tab--editing :global(.ic-tab__close) {
    display: none;
  }

  /* Inline rename input */
  .ic-tc__edit-input {
    all: unset;
    font: inherit;
    color: var(--ic-foreground);
    background: var(--ic-background);
    border: 1px solid var(--ic-primary);
    border-radius: 1px;
    padding: 0 2px;
    min-width: 40px;
    max-width: 160px;
    box-sizing: border-box;
    line-height: 1.2;
  }

  /* -- Left indicator (rendered by attached Tab.svelte or fallback) -- */
  .ic-tc__tab :global(.ic-tab__indicator) {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    border-radius: 0;
    background: transparent;
    transition: background-color 0.15s ease;
  }

  .ic-tc__tab--active :global(.ic-tab__indicator) {
    background-color: var(--ic-primary);
  }

  /* -- Icon (rendered by attached Tab.svelte or fallback) -- */
  .ic-tc__tab :global(.ic-tab__icon) {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: inherit;
    line-height: 0;
  }

  /* Icon sizes per bar size variant */
  .ic-tc__bar--sm .ic-tc__tab :global(.ic-tc__icon svg) { width: 12px; height: 12px; }
  .ic-tc__bar--md .ic-tc__tab :global(.ic-tc__icon svg) { width: 14px; height: 14px; }
  .ic-tc__bar--lg .ic-tc__tab :global(.ic-tc__icon svg) { width: 16px; height: 16px; }

  /* -- Label (rendered by attached Tab.svelte or fallback) -- */
  .ic-tc__tab :global(.ic-tab__label) {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    line-height: 1.2;
  }

  /* -- Close button (rendered by attached Tab.svelte or fallback) -- */
  .ic-tc__tab :global(.ic-tab__close) {
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
  .ic-tc__tab:hover :global(.ic-tab__close),
  .ic-tc__tab--active :global(.ic-tab__close) {
    opacity: 0.7;
  }

  .ic-tc__tab :global(.ic-tc__close:hover) {
    opacity: 1;
    background-color: rgba(220, 50, 50, 0.15);
    color: var(--ic-destructive);
  }

  /* Hide close button when only one tab remains */
  .ic-tc__bar--single .ic-tc__tab :global(.ic-tab__close) {
    display: none;
  }

  /* -- Chevron >> button -- */
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

  /* -- Menu popup -- */
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

  /* -- Content area -- */
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
