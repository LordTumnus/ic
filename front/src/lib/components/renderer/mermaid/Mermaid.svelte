<script lang="ts">
  import { renderMermaid } from '$lib/utils/mermaid-renderer';
  import type { RenderOptions } from '$lib/utils/mermaid-renderer';
  import { resolveIcon } from '$lib/utils/icons';
  import type { Resolution, SubscribeFn } from '$lib/types';
  import logger from '$lib/core/logger';

  // ─── Props ────────────────────────────────────────────────────────────
  let {
    value = $bindable(''),
    height = $bindable<number | string>('100%'),
    toolbarOnHover = $bindable(true),
    htmlLabels = $bindable(true),
    wrap = $bindable(true),
    darkMode = $bindable(false),
    config = $bindable<Record<string, unknown>>({}),
    subscribe = (() => () => {}) as SubscribeFn,
    // Methods
    zoomIn = $bindable((): Resolution => ({ success: true, data: null })),
    zoomOut = $bindable((): Resolution => ({ success: true, data: null })),
    resetView = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    height?: number | string;
    toolbarOnHover?: boolean;
    htmlLabels?: boolean;
    wrap?: boolean;
    darkMode?: boolean;
    config?: Record<string, unknown>;
    subscribe?: SubscribeFn;
    zoomIn?: () => Resolution;
    zoomOut?: () => Resolution;
    resetView?: () => Resolution;
  } = $props();

  // ─── Constants ────────────────────────────────────────────────────────
  const ZOOM_STEP = 0.2;
  const TRANSITION_MS = 250;
  const ICON_SIZE = 14;
  const MIN_ZOOM = 0.1;
  const MAX_ZOOM = 10;

  const icons = {
    plus: resolveIcon('plus', ICON_SIZE),
    minus: resolveIcon('minus', ICON_SIZE),
    home: resolveIcon('home', ICON_SIZE),
  };

  // ─── State ────────────────────────────────────────────────────────────
  let containerEl = $state<HTMLDivElement>(undefined!);
  let viewportEl = $state<HTMLDivElement>(undefined!);
  let svgContainerEl = $state<HTMLDivElement>(undefined!);

  let loading = $state(false);
  let errorMsg = $state('');
  let currentSvg = $state('');
  let currentZoom = $state(1);
  let hovered = $state(false);

  // d3 modules (lazy-loaded)
  let d3Zoom: typeof import('d3-zoom') | null = null;
  let d3Selection: typeof import('d3-selection') | null = null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- lazy-loaded d3; strict generics aren't worth it
  let zoomBehavior: any = null;

  // Track render version to discard stale results
  let renderTicket = 0;
  // Bumped when style() sets CSS vars (via adopted stylesheet, not inline)
  let styleVersion = $state(0);

  const heightCss = $derived(typeof height === 'number' ? `${height}px` : height);
  const zoomPercent = $derived(Math.round(currentZoom * 100));

  // ─── Watch for style() changes (theme vars via adopted stylesheet) ──
  $effect(() => {
    const unsub = subscribe('@style', () => { styleVersion++; });
    return unsub;
  });

  // ─── Render diagram when value, options, or theme vars change ───────
  $effect(() => {
    const v = value;
    void styleVersion; // re-render when style vars change
    // Build render options (reading these registers them as dependencies)
    const opts: RenderOptions = { htmlLabels, wrap, darkMode, config };
    const ticket = ++renderTicket;

    if (!v.trim()) {
      currentSvg = '';
      errorMsg = '';
      return;
    }

    loading = true;
    errorMsg = '';

    renderMermaid(v, containerEl, opts).then((result) => {
      if (ticket !== renderTicket) return; // stale
      loading = false;

      if (result.ok) {
        currentSvg = result.svg;
        errorMsg = '';
        // Re-initialize zoom after SVG is inserted
        requestAnimationFrame(() => initZoom());
      } else {
        currentSvg = '';
        errorMsg = result.message;
        logger.warn('Mermaid', 'Render failed', { error: result.message });
      }
    });
  });

  // ─── d3-zoom setup ────────────────────────────────────────────────────
  async function loadD3() {
    if (d3Zoom && d3Selection) return;
    [d3Zoom, d3Selection] = await Promise.all([
      import('d3-zoom'),
      import('d3-selection'),
    ]);
  }

  async function initZoom() {
    if (!viewportEl || !svgContainerEl) return;

    await loadD3();
    if (!d3Zoom || !d3Selection) return;

    const svg = svgContainerEl.querySelector('svg');
    if (!svg) return;

    // Make SVG fill the container and remove inline dimensions
    svg.removeAttribute('height');
    svg.style.width = '100%';
    svg.style.height = '100%';
    svg.style.maxWidth = 'none';

    // Create zoom behavior
    zoomBehavior = d3Zoom.zoom<HTMLDivElement, unknown>()
      .scaleExtent([MIN_ZOOM, MAX_ZOOM])
      .on('zoom', (event) => {
        const { x, y, k } = event.transform;
        svgContainerEl.style.transform = `translate(${x}px, ${y}px) scale(${k})`;
        svgContainerEl.style.transformOrigin = '0 0';
        currentZoom = k;
      });

    // Apply to viewport
    const sel = d3Selection.select(viewportEl);
    sel.call(zoomBehavior as any);
  }

  // ─── Zoom actions ─────────────────────────────────────────────────────
  function doZoomIn() {
    if (!zoomBehavior || !d3Selection || !viewportEl) return;
    const sel = d3Selection.select(viewportEl) as any;
    zoomBehavior.scaleBy(sel.transition().duration(TRANSITION_MS), 1 + ZOOM_STEP);
  }

  function doZoomOut() {
    if (!zoomBehavior || !d3Selection || !viewportEl) return;
    const sel = d3Selection.select(viewportEl) as any;
    zoomBehavior.scaleBy(sel.transition().duration(TRANSITION_MS), 1 / (1 + ZOOM_STEP));
  }

  function doResetView() {
    if (!zoomBehavior || !d3Selection || !d3Zoom || !viewportEl) return;
    const sel = d3Selection.select(viewportEl) as any;
    zoomBehavior.transform(sel.transition().duration(TRANSITION_MS), d3Zoom.zoomIdentity);
  }

  // ─── Method overrides ─────────────────────────────────────────────────
  $effect(() => {
    zoomIn = () => {
      doZoomIn();
      return { success: true, data: null };
    };
    zoomOut = () => {
      doZoomOut();
      return { success: true, data: null };
    };
    resetView = () => {
      doResetView();
      return { success: true, data: null };
    };
  });
</script>

<!-- ─── Template ─────────────────────────────────────────────────────── -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-mermaid"
  style:height={heightCss}
  bind:this={containerEl}
  onmouseenter={() => (hovered = true)}
  onmouseleave={() => (hovered = false)}
>
  {#if loading}
    <div class="ic-mermaid__status">
      <div class="ic-mermaid__spinner"></div>
      <span class="ic-mermaid__status-text">Rendering diagram...</span>
    </div>
  {:else if errorMsg}
    <div class="ic-mermaid__status ic-mermaid__status--error">
      <span class="ic-mermaid__status-icon">{@html resolveIcon('triangle-alert', 20)}</span>
      <span class="ic-mermaid__status-text">{errorMsg}</span>
    </div>
  {:else if !currentSvg}
    <div class="ic-mermaid__status">
      <span class="ic-mermaid__status-text">No diagram</span>
    </div>
  {:else}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="ic-mermaid__viewport"
      class:ic-mermaid__viewport--grab={true}
      bind:this={viewportEl}
    >
      <div class="ic-mermaid__svg" bind:this={svgContainerEl}>
        {@html currentSvg}
      </div>
    </div>

    <!-- Floating controls -->
    {#if toolbarOnHover}
      <div
        class="ic-mermaid__controls"
        class:ic-mermaid__controls--visible={hovered}
      >
        <button
          class="ic-mermaid__btn"
          onclick={doZoomIn}
          title="Zoom in"
        >
          {@html icons.plus}
        </button>

        <span class="ic-mermaid__info">{zoomPercent}%</span>

        <button
          class="ic-mermaid__btn"
          onclick={doZoomOut}
          title="Zoom out"
        >
          {@html icons.minus}
        </button>

        <div class="ic-mermaid__sep"></div>

        <button
          class="ic-mermaid__btn"
          onclick={doResetView}
          title="Reset view"
        >
          {@html icons.home}
        </button>
      </div>
    {/if}
  {/if}
</div>

<style>
  /* ─── Mermaid theme vars ─────────────────────────────────────────── */
  /* Root vars auto-theme from IC. The rest are unset — Mermaid        */
  /* derives them from the roots. Override any via style() API.        */
  .ic-mermaid {
    /* Roots (auto-themed) */
    --ic-mermaid-primary: var(--ic-primary);
    --ic-mermaid-background: var(--ic-background);
    --ic-mermaid-text: var(--ic-foreground);
    --ic-mermaid-line: var(--ic-muted-foreground);

    /* General */
    --ic-mermaid-primary-text: ;
    --ic-mermaid-primary-border: ;
    --ic-mermaid-secondary: ;
    --ic-mermaid-secondary-text: ;
    --ic-mermaid-secondary-border: ;
    --ic-mermaid-tertiary: ;
    --ic-mermaid-tertiary-text: ;
    --ic-mermaid-tertiary-border: ;

    /* Notes */
    --ic-mermaid-note-bkg: ;
    --ic-mermaid-note-text: ;
    --ic-mermaid-note-border: ;

    /* Flowchart */
    --ic-mermaid-node-border: ;
    --ic-mermaid-cluster-bkg: ;
    --ic-mermaid-cluster-border: ;
    --ic-mermaid-link-color: ;
    --ic-mermaid-edge-label-bkg: ;

    /* Sequence diagrams */
    --ic-mermaid-actor-bkg: ;
    --ic-mermaid-actor-text: ;
    --ic-mermaid-actor-border: ;
    --ic-mermaid-actor-line: ;
    --ic-mermaid-signal-color: ;
    --ic-mermaid-signal-text: ;
    --ic-mermaid-activation-bkg: ;
    --ic-mermaid-activation-border: ;

    /* Gantt charts */
    --ic-mermaid-section-bkg: ;
    --ic-mermaid-section-bkg-2: ;
    --ic-mermaid-grid-color: ;
    --ic-mermaid-task-bkg: ;
    --ic-mermaid-task-text: ;
    --ic-mermaid-task-border: ;
    --ic-mermaid-done-task-bkg: ;
    --ic-mermaid-done-task-border: ;
    --ic-mermaid-crit-bkg: ;
    --ic-mermaid-crit-border: ;
    --ic-mermaid-active-task-bkg: ;
    --ic-mermaid-active-task-border: ;
    --ic-mermaid-today-line: ;
  }

  /* ─── Block ──────────────────────────────────────────────────────────── */
  .ic-mermaid {
    position: relative;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
  }

  /* ─── Viewport (zoomable area) ───────────────────────────────────────── */
  .ic-mermaid__viewport {
    position: relative;
    flex: 1;
    overflow: hidden;
    background-color: var(--ic-muted);
  }
  .ic-mermaid__viewport--grab {
    cursor: grab;
  }
  .ic-mermaid__viewport--grab:active {
    cursor: grabbing;
  }

  /* ─── SVG container (transformed by d3-zoom) ─────────────────────────── */
  .ic-mermaid__svg {
    transform-origin: 0 0;
    will-change: transform;
  }
  .ic-mermaid__svg :global(svg) {
    display: block;
  }

  /* ─── Floating controls ──────────────────────────────────────────────── */
  .ic-mermaid__controls {
    position: absolute;
    bottom: 12px;
    left: 50%;
    transform: translateX(-50%);
    display: inline-flex;
    align-items: center;
    gap: 2px;
    padding: 4px 10px;
    background-color: var(--ic-secondary);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    opacity: 0;
    transition: opacity 0.15s ease;
    pointer-events: none;
    z-index: 10;
  }
  .ic-mermaid__controls--visible {
    opacity: 1;
    pointer-events: auto;
  }

  /* ─── Control buttons ───────────────────────────────────────────────── */
  .ic-mermaid__btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    padding: 0;
    border: 1px solid transparent;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    transition: color 0.1s ease, background-color 0.1s ease, border-color 0.1s ease;
    line-height: 0;
  }
  .ic-mermaid__btn:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
    border-color: var(--ic-border);
  }
  .ic-mermaid__btn:active {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  /* ─── Zoom info text ────────────────────────────────────────────────── */
  .ic-mermaid__info {
    font-family: var(--ic-font-mono, 'Roboto Mono', monospace);
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    color: var(--ic-muted-foreground);
    min-width: 40px;
    text-align: center;
    user-select: none;
    line-height: 24px;
  }

  /* ─── Separator ─────────────────────────────────────────────────────── */
  .ic-mermaid__sep {
    width: 1px;
    height: 16px;
    background-color: var(--ic-border);
    margin: 0 5px;
  }

  /* ─── Status states (loading, error, empty) ─────────────────────────── */
  .ic-mermaid__status {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    flex: 1;
    min-height: 100%;
    color: var(--ic-muted-foreground);
    user-select: none;
  }
  .ic-mermaid__status--error {
    color: var(--ic-destructive, #ef4444);
  }
  .ic-mermaid__status-text {
    font-size: 12px;
    max-width: 80%;
    text-align: center;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .ic-mermaid__status-icon {
    line-height: 0;
  }

  /* ─── Spinner ───────────────────────────────────────────────────────── */
  .ic-mermaid__spinner {
    width: 24px;
    height: 24px;
    border: 2px solid var(--ic-border);
    border-top-color: var(--ic-primary);
    border-radius: 50%;
    animation: ic-mermaid-spin 0.8s linear infinite;
  }
  @keyframes ic-mermaid-spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
