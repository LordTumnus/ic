<!--
  Popover.svelte — Floating panel anchored to a trigger component.

  Structural shell: manages trigger click-to-toggle, panel positioning,
  click-outside/Escape dismissal, and open/close transitions.

  Both trigger and panel are static children — no external addChild allowed.
  Content goes into the Panel via pop.Panel.addChild(...) in MATLAB.

  Positioning is computed in JS via popover-utils.ts (not CSS classes),
  which enables AvoidCollisions to flip the panel when it overflows.

  z-index: 50 (same as dropdowns).
-->
<script lang="ts">
  import type { StaticChildrenMap } from '$lib/types';
  import {
    computePosition,
    type Side,
    type PopoverAlign,
  } from '$lib/utils/popover-utils';

  let {
    open = $bindable(false),
    side = $bindable('bottom'),
    align = $bindable('center'),
    offset = $bindable(4),
    avoidCollisions = $bindable(true),
    staticChildren = new Map() as StaticChildrenMap,
    opened,
    closed,
  }: {
    open?: boolean;
    side?: string;
    align?: string;
    offset?: number;
    avoidCollisions?: boolean;
    staticChildren?: StaticChildrenMap;
    opened?: (data?: unknown) => void;
    closed?: (data?: unknown) => void;
  } = $props();

  let rootEl: HTMLDivElement;
  let panelEl: HTMLDivElement;

  // Position state (px relative to root)
  let posTop = $state(0);
  let posLeft = $state(0);
  let positionReady = $state(false);

  // panelOpen gates visibility until position is computed (prevents 1-frame flash)
  const panelOpen = $derived(open && positionReady);

  const triggerSlot = $derived(staticChildren.get('trigger') ?? []);
  const panelSlot = $derived(staticChildren.get('panel') ?? []);

  // ── Positioning ───────────────────────────────────────────
  function recalculate() {
    if (!rootEl || !panelEl) return;

    const s = (side?.toLowerCase() ?? 'bottom') as Side;
    const a = (align?.toLowerCase() ?? 'center') as PopoverAlign;

    const triggerRect = rootEl.getBoundingClientRect();
    const panelW = panelEl.offsetWidth;
    const panelH = panelEl.offsetHeight;

    const pos = computePosition(
      triggerRect,
      panelW,
      panelH,
      window.innerWidth,
      window.innerHeight,
      { side: s, align: a, offset: offset ?? 4, avoidCollisions: avoidCollisions ?? true },
    );

    posTop = pos.top;
    posLeft = pos.left;
    positionReady = true;
  }

  // Recalculate whenever open or positioning props change
  $effect(() => {
    // Touch reactive deps
    void side;
    void align;
    void offset;
    void avoidCollisions;

    if (open) {
      requestAnimationFrame(recalculate);
    } else {
      positionReady = false;
    }
  });

  // Debounced resize recalculation while open
  $effect(() => {
    if (!open) return;
    let timer: ReturnType<typeof setTimeout>;
    function handleResize() {
      clearTimeout(timer);
      timer = setTimeout(recalculate, 100);
    }
    window.addEventListener('resize', handleResize);
    return () => {
      clearTimeout(timer);
      window.removeEventListener('resize', handleResize);
    };
  });

  // ── Toggle (user click on trigger) ──────────────────────
  function toggle() {
    if (open) {
      closePanel();
    } else {
      openPanel();
    }
  }

  function openPanel() {
    open = true;
    opened?.({});
  }

  function closePanel() {
    open = false;
    closed?.({});
  }

  // ── Click-outside listener (managed by $effect) ─────────
  function handleClickOutside(e: PointerEvent) {
    const target = e.target as Node;
    if (rootEl && !rootEl.contains(target)) {
      closePanel();
    }
  }

  $effect(() => {
    if (open) {
      const raf = requestAnimationFrame(() => {
        document.addEventListener('pointerdown', handleClickOutside);
      });
      return () => {
        cancelAnimationFrame(raf);
        document.removeEventListener('pointerdown', handleClickOutside);
      };
    }
  });

  // ── Escape key ──────────────────────────────────────────
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && open) {
      e.preventDefault();
      e.stopPropagation();
      closePanel();
    }
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={rootEl}
  class="ic-popover"
  onkeydown={handleKeydown}
>
  <!-- Trigger (static child) -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="ic-popover__trigger" onclick={toggle}>
    {#each triggerSlot as child}
      {@render child.snippet()}
    {/each}
  </div>

  <!-- Panel wrapper: positioning + transitions -->
  <div
    bind:this={panelEl}
    class="ic-popover__panel"
    class:ic-popover__panel--open={panelOpen}
    style:top="{posTop}px"
    style:left="{posLeft}px"
  >
    <!-- Panel content (static child) -->
    {#each panelSlot as child}
      {@render child.snippet()}
    {/each}
  </div>
</div>

<style>
  /* ===== ROOT ===== */

  .ic-popover {
    position: relative;
    display: inline-flex;
  }

  /* ===== TRIGGER ===== */

  .ic-popover__trigger {
    display: contents;
  }

  /* ===== PANEL ===== */

  .ic-popover__panel {
    position: absolute;
    z-index: 50;
    visibility: hidden;
    pointer-events: none;
    opacity: 0;
    transform: scale(0.97);
    transition: opacity 0.15s ease, transform 0.15s ease, visibility 0.15s;
  }

  .ic-popover__panel--open {
    visibility: visible;
    pointer-events: auto;
    opacity: 1;
    transform: scale(1);
  }
</style>
