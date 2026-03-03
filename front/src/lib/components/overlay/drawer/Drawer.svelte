<!--
  Drawer.svelte — Slide-in panel overlay with backdrop.

  Always in the DOM; the `open` prop toggles visibility via CSS transitions.
  Added via addOverlay() so it renders at the container's root level
  (the "overlay" snippet target). position: absolute covers the parent container.
  Panel slides from the specified edge (left/right/top/bottom).
  Targets: "body" (main content), "header" (custom header replaces default title+X).
  z-index 8000 (below Toast at 9000).
-->
<script lang="ts">
  import type { Snippets } from '$lib/types';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    title = $bindable(''),
    open = $bindable(false),
    side = $bindable('right'),
    size = $bindable('md'),
    closable = $bindable(true),
    overlay = $bindable(true),
    closeOnBackdropClick = $bindable(true),
    snippets = { body: [], header: [] } as Snippets,
    closed,
  }: {
    title?: string;
    open?: boolean;
    side?: string;
    size?: string;
    closable?: boolean;
    overlay?: boolean;
    closeOnBackdropClick?: boolean;
    snippets?: Snippets;
    closed?: (data?: unknown) => void;
  } = $props();

  let panelEl: HTMLDivElement;

  const closeSvg = resolveIcon('x', 14);

  const hasCustomHeader = $derived((snippets.header?.length ?? 0) > 0);
  const isHorizontal = $derived(side === 'left' || side === 'right');

  // Focus the panel when opened
  $effect(() => {
    if (open) {
      requestAnimationFrame(() => {
        panelEl?.focus();
      });
    }
  });

  function handleClose() {
    open = false;
    closed?.({});
  }

  function handleBackdropPointerDown(e: PointerEvent) {
    if (closeOnBackdropClick && e.target === e.currentTarget) {
      handleClose();
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && closable && open) {
      e.preventDefault();
      e.stopPropagation();
      handleClose();
    }
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-drawer"
  class:ic-drawer--open={open}
  onkeydown={handleKeydown}
>
  <!-- Backdrop (only when overlay=true) -->
  {#if overlay}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="ic-drawer__backdrop"
      onpointerdown={handleBackdropPointerDown}
    ></div>
  {/if}

  <!-- Panel -->
  <div
    bind:this={panelEl}
    class="ic-drawer__panel"
    class:ic-drawer__panel--left={side === 'left'}
    class:ic-drawer__panel--right={side === 'right'}
    class:ic-drawer__panel--top={side === 'top'}
    class:ic-drawer__panel--bottom={side === 'bottom'}
    class:ic-drawer__panel--horizontal={isHorizontal}
    class:ic-drawer__panel--vertical={!isHorizontal}
    class:ic-drawer__panel--sm={size === 'sm'}
    class:ic-drawer__panel--md={size === 'md'}
    class:ic-drawer__panel--lg={size === 'lg'}
    class:ic-drawer__panel--xl={size === 'xl'}
    class:ic-drawer__panel--full={size === 'full'}
    role="dialog"
    aria-modal="true"
    aria-label={title || 'Drawer'}
    tabindex="-1"
  >
    <!-- Header -->
    {#if hasCustomHeader}
      <div class="ic-drawer__header">
        {#each snippets.header ?? [] as child (child)}
          {@render child()}
        {/each}
      </div>
    {:else if title || closable}
      <div class="ic-drawer__header">
        {#if title}
          <h2 class="ic-drawer__title">{title}</h2>
        {/if}
        {#if closable}
          <button
            class="ic-drawer__close"
            onclick={handleClose}
            aria-label="Close drawer"
          >
            {@html closeSvg}
          </button>
        {/if}
      </div>
    {/if}

    <!-- Body -->
    <div class="ic-drawer__body">
      {#each snippets.body ?? [] as child (child)}
        {@render child()}
      {/each}
    </div>
  </div>
</div>

<style>
  /* ===== WRAPPER ===== */

  .ic-drawer {
    position: absolute;
    inset: 0;
    z-index: 8000;
    visibility: hidden;
    pointer-events: none;
  }

  .ic-drawer--open {
    visibility: visible;
    pointer-events: auto;
  }

  /* ===== BACKDROP ===== */

  .ic-drawer__backdrop {
    position: absolute;
    inset: 0;
    background-color: rgba(0, 0, 0, 0.4);
    opacity: 0;
    transition: opacity 0.25s ease;
  }

  .ic-drawer--open .ic-drawer__backdrop {
    opacity: 1;
  }

  /* ===== PANEL ===== */

  .ic-drawer__panel {
    position: absolute;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    outline: none;
    overflow: clip;
    transition: transform 0.25s ease;
  }

  /* Horizontal panels (left/right): full height, width by size */
  .ic-drawer__panel--horizontal {
    top: 0;
    bottom: 0;
  }

  /* Vertical panels (top/bottom): full width, height by size */
  .ic-drawer__panel--vertical {
    left: 0;
    right: 0;
  }

  /* Side positioning + slide transforms */
  .ic-drawer__panel--left {
    left: 0;
    border-left: none;
    box-shadow: 4px 0 16px rgba(0, 0, 0, 0.2);
    transform: translateX(-100%);
  }

  .ic-drawer__panel--right {
    right: 0;
    border-right: none;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.2);
    transform: translateX(100%);
  }

  .ic-drawer__panel--top {
    top: 0;
    border-top: none;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
    transform: translateY(-100%);
  }

  .ic-drawer__panel--bottom {
    bottom: 0;
    border-bottom: none;
    box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.2);
    transform: translateY(100%);
  }

  /* Open state: slide in */
  .ic-drawer--open .ic-drawer__panel--left,
  .ic-drawer--open .ic-drawer__panel--right {
    transform: translateX(0);
  }

  .ic-drawer--open .ic-drawer__panel--top,
  .ic-drawer--open .ic-drawer__panel--bottom {
    transform: translateY(0);
  }

  /* ===== SIZES (horizontal = width, vertical = height) ===== */

  .ic-drawer__panel--horizontal.ic-drawer__panel--sm   { width: 320px; }
  .ic-drawer__panel--horizontal.ic-drawer__panel--md   { width: 400px; }
  .ic-drawer__panel--horizontal.ic-drawer__panel--lg   { width: 560px; }
  .ic-drawer__panel--horizontal.ic-drawer__panel--xl   { width: 720px; }
  .ic-drawer__panel--horizontal.ic-drawer__panel--full { width: 100%; }

  .ic-drawer__panel--vertical.ic-drawer__panel--sm   { height: 320px; }
  .ic-drawer__panel--vertical.ic-drawer__panel--md   { height: 400px; }
  .ic-drawer__panel--vertical.ic-drawer__panel--lg   { height: 560px; }
  .ic-drawer__panel--vertical.ic-drawer__panel--xl   { height: 720px; }
  .ic-drawer__panel--vertical.ic-drawer__panel--full { height: 100%; }

  /* ===== HEADER ===== */

  .ic-drawer__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--ic-border);
    flex-shrink: 0;
  }

  .ic-drawer__title {
    margin: 0;
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ic-foreground);
    line-height: 1.4;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ic-drawer__close {
    all: unset;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    border-radius: 2px;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    margin-left: auto;
  }

  .ic-drawer__close:hover {
    color: var(--ic-foreground);
    background: rgba(0, 0, 0, 0.08);
  }

  /* ===== BODY ===== */

  .ic-drawer__body {
    flex: 1 1 auto;
    padding: 16px;
    overflow: auto;
    min-height: 0;
  }
</style>
