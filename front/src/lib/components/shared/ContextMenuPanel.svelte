<script lang="ts">
  import type { ContextMenuEntry, ContextMenuFolder } from '$lib/utils/context-menu-types';
  import Icon from '$lib/components/display/icon/Icon.svelte';
  import ContextMenuPanel from './ContextMenuPanel.svelte';

  let {
    entries,
    x,
    y,
    onaction,
    onclose,
  }: {
    entries: ContextMenuEntry[];
    x: number;
    y: number;
    onaction: (key: string) => void;
    onclose: () => void;
  } = $props();

  let panelEl: HTMLDivElement;

  // Viewport-clamp position — derived from props (reactive to x/y changes)
  let panelWidth = $state(0);
  let panelHeight = $state(0);

  $effect(() => {
    if (panelEl) {
      panelWidth = panelEl.offsetWidth;
      panelHeight = panelEl.offsetHeight;
    }
  });

  const adjustedX = $derived.by(() => {
    const vw = typeof window !== 'undefined' ? window.innerWidth : 9999;
    return (x + panelWidth > vw) ? Math.max(0, vw - panelWidth - 4) : x;
  });

  const adjustedY = $derived.by(() => {
    const vh = typeof window !== 'undefined' ? window.innerHeight : 9999;
    return (y + panelHeight > vh) ? Math.max(0, vh - panelHeight - 4) : y;
  });

  // Submenu state
  let openFolder = $state<{ folder: ContextMenuFolder; x: number; y: number } | null>(null);
  let hoverTimer: ReturnType<typeof setTimeout> | null = null;

  function handleFolderEnter(e: PointerEvent, folder: ContextMenuFolder) {
    if (hoverTimer) clearTimeout(hoverTimer);
    const target = e.currentTarget as HTMLElement;
    hoverTimer = setTimeout(() => {
      const rect = target.getBoundingClientRect();
      // Open to the right; ContextMenuPanel will viewport-clamp if overflow
      openFolder = {
        folder,
        x: rect.right,
        y: rect.top,
      };
    }, 150);
  }

  function handleFolderLeave() {
    if (hoverTimer) {
      clearTimeout(hoverTimer);
      hoverTimer = null;
    }
  }

  function handleItemClick(key: string) {
    onaction(key);
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_interactive_supports_focus -->
<div
  bind:this={panelEl}
  class="ic-ctx__panel"
  style:left="{adjustedX}px"
  style:top="{adjustedY}px"
  onclick={(e: MouseEvent) => e.stopPropagation()}
  onpointerdown={(e: PointerEvent) => e.stopPropagation()}
  role="menu"
  tabindex={-1}
>
  {#each entries as entry, idx (idx)}
    {#if entry.type === 'separator'}
      <div class="ic-ctx__separator"></div>
    {:else if entry.type === 'item'}
      <button
        class="ic-ctx__item"
        class:ic-ctx__item--disabled={entry.disabled}
        onclick={() => handleItemClick(entry.key)}
        disabled={entry.disabled}
      >
        <span class="ic-ctx__icon">
          {#if entry.icon}
            <Icon source={entry.icon} size={14} />
          {/if}
        </span>
        <span class="ic-ctx__label">{entry.label || entry.key}</span>
        {#if entry.shortcut}
          <span class="ic-ctx__shortcut">{entry.shortcut}</span>
        {/if}
      </button>
    {:else if entry.type === 'folder'}
      <button
        class="ic-ctx__item ic-ctx__item--folder"
        class:ic-ctx__item--disabled={entry.disabled}
        onpointerenter={(e: PointerEvent) => handleFolderEnter(e, entry)}
        onpointerleave={handleFolderLeave}
        disabled={entry.disabled}
      >
        <span class="ic-ctx__icon">
          {#if entry.icon}
            <Icon source={entry.icon} size={14} />
          {/if}
        </span>
        <span class="ic-ctx__label">{entry.label || ''}</span>
        <span class="ic-ctx__chevron">
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M3.5 2L6.5 5L3.5 8" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </span>
      </button>
      {#if openFolder && openFolder.folder === entry && entry.children?.length}
        <ContextMenuPanel
          entries={entry.children}
          x={openFolder.x}
          y={openFolder.y}
          {onaction}
          {onclose}
        />
      {/if}
    {/if}
  {/each}
</div>

<style>
  .ic-ctx__panel {
    position: fixed;
    z-index: 200;
    min-width: 160px;
    padding: 3px 0;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.18);
  }

  .ic-ctx__item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 5px 10px 5px 8px;
    border: none;
    background: none;
    font-size: 0.8rem;
    font-family: inherit;
    color: var(--ic-foreground);
    cursor: pointer;
    white-space: nowrap;
    text-align: left;
  }
  .ic-ctx__item:hover {
    background: var(--ic-secondary);
  }
  .ic-ctx__item--disabled {
    opacity: 0.4;
    pointer-events: none;
  }

  .ic-ctx__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    flex-shrink: 0;
    color: var(--ic-muted-foreground);
  }

  .ic-ctx__label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ic-ctx__shortcut {
    color: var(--ic-muted-foreground);
    font-size: 0.7rem;
    margin-left: auto;
    padding-left: 16px;
  }

  .ic-ctx__chevron {
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    display: flex;
    align-items: center;
  }

  .ic-ctx__separator {
    margin: 3px 8px;
    border-top: 1px solid var(--ic-border);
  }
</style>
