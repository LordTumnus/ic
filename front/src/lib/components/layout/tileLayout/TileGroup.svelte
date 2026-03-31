<!--
  TileGroup.svelte — A single tab group within a TileLayout.

  Renders a tab bar with DnD (svelte-dnd-action) and a content area
  for the active panel. Simplified subset of TabContainer:
  - No overflow modes (always scroll)
  - No inline editing
  - No menu chevron
  - Cross-group DnD via shared type 'tile-tab'
-->
<script lang="ts">
  import { untrack } from 'svelte';
  import { flip } from 'svelte/animate';
  import {
    dndzone,
    SHADOW_ITEM_MARKER_PROPERTY_NAME,
    SHADOW_PLACEHOLDER_ITEM_ID
  } from 'svelte-dnd-action';
  import type { ChildEntries } from '$lib/types';
  import type { TileTabConfig, DropZone } from './tile-types';
  import { resolveIcon, type IconSource } from '$lib/utils/icons';
  import TileOverlay from './TileOverlay.svelte';

  const ICON_SIZES: Record<string, number> = { sm: 12, md: 14, lg: 16 };
  const FLIP_MS = 150;

  interface DndTabItem {
    id: string;
    [SHADOW_ITEM_MARKER_PROPERTY_NAME]?: boolean;
  }

  let {
    groupId,
    tabs = [] as string[],
    selectedTab = '',
    size = 'sm' as 'sm' | 'md' | 'lg',
    disabled = false,
    dragEnabled = true,
    childEntries = {} as ChildEntries,
    onTabClick,
    onTabClose,
    overlayZone = null as DropZone | null,
    onDragStart,
    onConsider,
    onFinalize,
  }: {
    groupId: string;
    tabs?: string[];
    selectedTab?: string;
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
    dragEnabled?: boolean;
    childEntries?: ChildEntries;
    overlayZone?: DropZone | null;
    onTabClick?: (groupId: string, tabTarget: string) => void;
    onTabClose?: (groupId: string, tabTarget: string) => void;
    onDragStart?: (groupId: string, tabTarget: string) => void;
    onConsider?: (groupId: string, items: DndTabItem[]) => void;
    onFinalize?: (groupId: string, items: DndTabItem[]) => void;
  } = $props();

  // --- Element refs ---
  let groupEl: HTMLElement | undefined = $state();
  let barEl: HTMLElement | undefined = $state();

  // --- Tab config resolution (from ChildEntry proxy) ---

  function getConfig(target: string): TileTabConfig | undefined {
    const entry = childEntries[target]?.[0];
    if (entry && entry.props.label !== undefined) {
      return {
        label: (entry.props.label as string) ?? '',
        closable: tabs.length > 1 && ((entry.props.closable as boolean) ?? false),
        disabled: (entry.props.disabled as boolean) ?? false,
        icon: (entry.props.icon as IconSource) ?? null,
      };
    }
    return undefined;
  }

  // --- DnD ---

  let dndItems = $state<DndTabItem[]>([]);
  let isDragging = $state(false);

  // Flip duration: FLIP_MS during drag for smooth reorder animation,
  // 0 on finalize to prevent the "ghost flies back" visual artifact.
  // handleFinalize sets isDragging=false BEFORE Svelte processes the
  // update, so animate:flip uses 0 → items jump to final position instantly.
  let flipMs = $derived(isDragging ? FLIP_MS : 0);

  // Sync dndItems from tabs prop.
  // Uses untrack(isDragging) so this effect ONLY re-runs when `tabs` changes,
  // not when isDragging toggles (which would fight svelte-dnd-action).
  // If tabs change while a drag is in progress (e.g. MATLAB removed a tab,
  // or svelte-dnd-action failed to fire finalize), force-reset isDragging
  // to prevent the stuck-drag state that causes tab headers to vanish.
  $effect(() => {
    const newItems = tabs.map((t) => ({ id: t }));
    if (untrack(() => isDragging)) {
      isDragging = false;
      document.documentElement.style.removeProperty('--_tg-cursor');
    }
    dndItems = newItems;
  });

  function handleConsider(e: CustomEvent<{ items: DndTabItem[] }>) {
    const wasDragging = isDragging;
    isDragging = true;
    dndItems = e.detail.items;

    // Undo preventShrinking() inline styles
    if (barEl) {
      barEl.style.minHeight = '';
      barEl.style.minWidth = '';
    }

    document.documentElement.style.setProperty('--_tg-cursor', 'grabbing');

    // Detect drag start: first consider event means a drag just began.
    // The shadow placeholder has SHADOW_PLACEHOLDER_ITEM_ID as its id,
    // NOT the original tab's id. Find the dragged tab by diffing against
    // the original tabs list to see which one is missing.
    if (!wasDragging) {
      const currentIds = new Set(
        dndItems
          .filter((it) => it.id !== SHADOW_PLACEHOLDER_ITEM_ID)
          .map((it) => it.id)
      );
      const draggedTab = tabs.find((t) => !currentIds.has(t));
      if (draggedTab) {
        onDragStart?.(groupId, draggedTab);
      }
    }

    onConsider?.(groupId, dndItems);
  }

  function handleFinalize(e: CustomEvent<{ items: DndTabItem[] }>) {
    isDragging = false;
    document.documentElement.style.removeProperty('--_tg-cursor');
    dndItems = e.detail.items;
    onFinalize?.(groupId, dndItems);
  }

  // --- Tab interaction ---

  function handleTabClick(target: string) {
    const config = getConfig(target);
    if (disabled || config?.disabled) return;
    selectedTab = target;
    onTabClick?.(groupId, target);
  }

  function handleClose(e: PointerEvent, target: string) {
    e.stopPropagation();
    e.preventDefault();
    onTabClose?.(groupId, target);
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (disabled) return;
    const n = tabs.length;
    if (n === 0) return;

    const currentIdx = tabs.indexOf(selectedTab);
    let current = currentIdx >= 0 ? currentIdx : 0;

    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      let next = (current + 1) % n;
      for (let tries = 0; tries < n; tries++) {
        if (!getConfig(tabs[next])?.disabled) break;
        next = (next + 1) % n;
      }
      selectedTab = tabs[next];
      onTabClick?.(groupId, selectedTab);
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      let prev = (current - 1 + n) % n;
      for (let tries = 0; tries < n; tries++) {
        if (!getConfig(tabs[prev])?.disabled) break;
        prev = (prev - 1 + n) % n;
      }
      selectedTab = tabs[prev];
      onTabClick?.(groupId, selectedTab);
    }
  }


</script>

<div
  class="ic-tg"
  class:ic-tg--disabled={disabled}
  bind:this={groupEl}
  data-group-id={groupId}
>
  <!-- Tab bar -->
  <div
    bind:this={barEl}
    class="ic-tg__bar"
    class:ic-tg__bar--sm={size === 'sm'}
    class:ic-tg__bar--md={size === 'md'}
    class:ic-tg__bar--lg={size === 'lg'}
    role="tablist"
    tabindex="0"
    aria-orientation="horizontal"
    onkeydown={handleKeyDown}
    use:dndzone={{
      items: dndItems,
      flipDurationMs: flipMs,
      type: 'tile-tab',
      dragDisabled: disabled || !dragEnabled,
      dropTargetStyle: {},
      morphDisabled: true,
      zoneTabIndex: -1,
      centreDraggedOnCursor: true,
      dropAnimationDisabled: true,
    }}
    onconsider={handleConsider}
    onfinalize={handleFinalize}
  >
    {#each dndItems as item (item.id)}
      {@const target = item.id}
      {@const isShadow = item[SHADOW_ITEM_MARKER_PROPERTY_NAME]}
      {@const config = getConfig(target)}
      {@const active = target === selectedTab}
      <div
        class="ic-tg__tab"
        class:ic-tg__tab--active={active}
        class:ic-tg__tab--disabled={config?.disabled}
        class:ic-tg__tab--shadow={isShadow}
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
        animate:flip={{ duration: flipMs }}
      >
        <span class="ic-tg__indicator" class:ic-tg__indicator--active={active}></span>
        {#if config}
          {#if config.icon}
            {@const iconSvg = resolveIcon(config.icon, ICON_SIZES[size] ?? 12)}
            {#if iconSvg}
              <span class="ic-tg__icon">{@html iconSvg}</span>
            {/if}
          {/if}
          <span class="ic-tg__label">{config.label}</span>
          {#if config.closable && !disabled}
            <button
              class="ic-tg__close"
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

  <!-- Content area (panels render at TileLayout level) -->
  <div class="ic-tg__content">
    {#if overlayZone}
      <TileOverlay zone={overlayZone} />
    {/if}
  </div>
</div>

<style>
  /* -- Group container -- */
  .ic-tg {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    overflow: clip;
    font-family: var(--ic-font-family);
    font-size: var(--ic-font-size);
    min-width: 0;
    min-height: 0;
  }

  .ic-tg--disabled {
    opacity: 0.65;
    pointer-events: none;
  }

  /* -- Tab bar (always horizontal scroll) -- */
  .ic-tg__bar {
    display: flex;
    align-items: stretch;
    background-color: var(--ic-secondary);
    border-bottom: 1px solid var(--ic-border);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    flex-shrink: 0;
    min-height: 0;
    overflow-x: auto;
    overflow-y: hidden;
    scrollbar-width: none;
  }

  .ic-tg__bar::-webkit-scrollbar { display: none; }

  /* -- Tab button -- */
  .ic-tg__tab {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 5px;
    border: 1px solid transparent;
    border-radius: 0;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: var(--_tg-cursor, pointer) !important;
    white-space: nowrap;
    flex-shrink: 0;
    transition: background-color 0.12s ease, color 0.12s ease;
    font-family: inherit;
  }

  /* Sizes */
  .ic-tg__bar--sm .ic-tg__tab { padding: 3px 8px; font-size: 0.7rem; }
  .ic-tg__bar--md .ic-tg__tab { padding: 4px 10px; font-size: 0.75rem; }
  .ic-tg__bar--lg .ic-tg__tab { padding: 6px 14px; font-size: 0.8125rem; }

  .ic-tg__tab:hover:not(.ic-tg__tab--disabled):not(.ic-tg__tab--active) {
    background-color: rgba(255, 255, 255, 0.04);
    color: var(--ic-foreground);
  }

  .ic-tg__tab--active {
    background-color: var(--ic-background);
    color: var(--ic-foreground);
  }

  .ic-tg__tab:focus-visible {
    outline: 1px solid var(--ic-primary);
    outline-offset: -1px;
  }

  .ic-tg__tab--disabled {
    opacity: 0.4;
    cursor: default;
  }

  .ic-tg__tab--shadow {
    opacity: 0.4;
    border-style: dashed;
    border-color: var(--ic-border);
    background: var(--ic-secondary);
  }

  /* -- Left indicator -- */
  .ic-tg__indicator {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 2px;
    background: transparent;
    transition: background-color 0.15s ease;
  }

  .ic-tg__indicator--active {
    background-color: var(--ic-primary);
  }

  /* -- Icon -- */
  .ic-tg__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: inherit;
    line-height: 0;
  }

  /* -- Label -- */
  .ic-tg__label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    line-height: 1.2;
  }

  /* -- Close button -- */
  .ic-tg__close {
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
  .ic-tg__close svg { width: 8px; height: 8px; }

  .ic-tg__tab:hover .ic-tg__close,
  .ic-tg__tab--active .ic-tg__close {
    opacity: 0.7;
  }

  .ic-tg__close:hover {
    opacity: 1;
    background-color: rgba(220, 50, 50, 0.15);
    color: var(--ic-destructive);
  }

  /* -- Content area (overlay container only; panels render at TileLayout level) -- */
  .ic-tg__content {
    position: relative;
    flex: 1;
    overflow: clip;
    min-height: 0;
    min-width: 0;
  }
</style>
