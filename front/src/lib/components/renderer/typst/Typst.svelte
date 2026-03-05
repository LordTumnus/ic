<script lang="ts">
  import { renderTypst, renderTypstPdf } from '$lib/utils/typst-renderer';
  import type { TypstRenderOptions } from '$lib/utils/typst-renderer';
  import { resolveIcon } from '$lib/utils/icons';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import type { Resolution, SubscribeFn, RequestFn } from '$lib/types';
  import logger from '$lib/core/logger';

  // ─── Props ────────────────────────────────────────────────────────────
  let {
    value = $bindable(''),
    height = $bindable<CssSize>('100%'),
    toolbarOnHover = $bindable(true),
    pageWidth = $bindable(''),
    pageHeight = $bindable(''),
    pageMargin = $bindable(''),
    fontSize = $bindable(''),
    fontFamily = $bindable(''),
    pageGap = $bindable(16),
    packages = $bindable<string[]>([]),
    numPages = $bindable(0),
    subscribe = (() => () => {}) as SubscribeFn,
    request,
    // Events
    compiled,
    error: errorEvent,
    // Methods
    zoomIn = $bindable((): Resolution => ({ success: true, data: null })),
    zoomOut = $bindable((): Resolution => ({ success: true, data: null })),
    resetView = $bindable((): Resolution => ({ success: true, data: null })),
    scrollToPage = $bindable((_page: number): Resolution => ({ success: true, data: null })),
    exportPdf = $bindable((_filepath: string): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    height?: CssSize;
    toolbarOnHover?: boolean;
    pageWidth?: string;
    pageHeight?: string;
    pageMargin?: string;
    fontSize?: string;
    fontFamily?: string;
    pageGap?: number;
    packages?: string[];
    numPages?: number;
    subscribe?: SubscribeFn;
    request?: RequestFn;
    compiled?: (data?: unknown) => void;
    error?: (data?: unknown) => void;
    zoomIn?: () => Resolution;
    zoomOut?: () => Resolution;
    resetView?: () => Resolution;
    scrollToPage?: (page: number) => Resolution;
    exportPdf?: (filepath: string) => Resolution;
  } = $props();

  // ─── Constants ────────────────────────────────────────────────────────
  const ZOOM_STEP = 0.2;
  const MIN_ZOOM = 0.25;
  const MAX_ZOOM = 4;
  const ICON_SIZE = 14;

  const icons = {
    plus: resolveIcon('plus', ICON_SIZE),
    minus: resolveIcon('minus', ICON_SIZE),
    home: resolveIcon('home', ICON_SIZE),
    download: resolveIcon('download', ICON_SIZE),
  };

  // ─── State ────────────────────────────────────────────────────────────
  let viewportEl = $state<HTMLDivElement>(undefined!);
  let loading = $state(false);
  let errorMsg = $state('');
  let pages = $state<string[]>([]);
  let currentZoom = $state(1);
  let hovered = $state(false);
  let exporting = $state(false);

  // Track render version to discard stale results
  let renderTicket = 0;
  // Bumped when style() sets CSS vars
  let styleVersion = $state(0);

  const heightCss = $derived(toSize(height));
  const zoomPercent = $derived(Math.round(currentZoom * 100));
  const isMultiPage = $derived(pages.length > 1);

  // ─── Watch for style() changes ───────────────────────────────────────
  $effect(() => {
    const unsub = subscribe('@style', () => { styleVersion++; });
    return unsub;
  });

  // ─── Build render options ────────────────────────────────────────────
  function buildOptions(): TypstRenderOptions {
    const opts: TypstRenderOptions = {};
    if (pageWidth) opts.pageWidth = pageWidth;
    if (pageHeight) opts.pageHeight = pageHeight;
    if (pageMargin) opts.pageMargin = pageMargin;
    if (fontSize) opts.fontSize = fontSize;
    if (fontFamily) opts.fontFamily = fontFamily;
    if (packages.length > 0) opts.packages = packages;
    return opts;
  }

  // ─── Render when value or options change ─────────────────────────────
  $effect(() => {
    const v = value;
    void styleVersion;
    // Read all option props to register as dependencies
    const opts = buildOptions();
    const ticket = ++renderTicket;

    if (!v.trim()) {
      pages = [];
      errorMsg = '';
      numPages = 0;
      return;
    }

    loading = true;
    errorMsg = '';

    renderTypst(v, opts).then((result) => {
      if (ticket !== renderTicket) return; // stale
      loading = false;

      if (result.ok) {
        pages = result.pages;
        numPages = result.pages.length;
        errorMsg = '';
        compiled?.({ value: { numPages: result.pages.length } });
      } else {
        pages = [];
        numPages = 0;
        errorMsg = result.message;
        errorEvent?.({ value: { message: result.message } });
        logger.warn('Typst', 'Compilation failed', { error: result.message });
      }
    });
  });

  // ─── Handle SVG links ───────────────────────────────────────────
  // Typst SVG embeds onclick="handleTypstLocation(this, page, x, y); return false"
  // on cross-ref anchors. We define the global function so the inline
  // handler works natively. The capture listener only handles external
  // links and acts as a safety net for xlink:href="#" navigation.
  $effect(() => {
    if (!viewportEl) return;

    // Define the global callback that Typst's inline onclick expects.
    // Parameters: (element, page [1-based], x, y) in SVG units.
    (window as any).handleTypstLocation = (
      _el: Element,
      page: number,
      _x: number,
      y: number,
    ) => {
      const pageEls = viewportEl.querySelectorAll('.ic-typst__page');
      const pageEl = pageEls[page - 1] ?? pageEls[page];
      if (!pageEl) return;

      const svg = pageEl.querySelector('svg');
      if (!svg) return;
      const vbHeight = parseFloat(svg.getAttribute('viewBox')?.split(/\s+/)[3] ?? '0');
      const scale = vbHeight > 0 ? pageEl.getBoundingClientRect().height / vbHeight : 1;
      const pageTop = (pageEl as HTMLElement).offsetTop - viewportEl.offsetTop;

      viewportEl.scrollTo({
        top: (pageTop + y * scale) * currentZoom - 40,
        behavior: 'smooth',
      });
    };

    // Capture-phase: prevent xlink:href="#" navigation (crashes uihtml)
    // and intercept external links for MATLAB's system browser.
    function handleLink(e: Event) {
      const anchor = (e.target as Element).closest('a');
      if (!anchor) return;

      // Always prevent the xlink:href="#" default navigation
      e.preventDefault();

      const href =
        anchor.getAttribute('href') ||
        anchor.getAttributeNS('http://www.w3.org/1999/xlink', 'href') ||
        '';

      // External link → open via MATLAB, block propagation
      if (request && (href.startsWith('http://') || href.startsWith('https://'))) {
        e.stopPropagation();
        request('openLink', { url: href });
      }
      // For Typst refs: don't stopPropagation — let inline onclick fire
    }

    viewportEl.addEventListener('click', handleLink, true);
    return () => {
      viewportEl.removeEventListener('click', handleLink, true);
      delete (window as any).handleTypstLocation;
    };
  });

  // ─── Zoom actions ────────────────────────────────────────────────────
  function doZoomIn() {
    currentZoom = Math.min(MAX_ZOOM, currentZoom * (1 + ZOOM_STEP));
  }

  function doZoomOut() {
    currentZoom = Math.max(MIN_ZOOM, currentZoom / (1 + ZOOM_STEP));
  }

  function doResetView() {
    currentZoom = 1;
  }

  function doScrollToPage(pageNum: number) {
    const pageEls = viewportEl?.querySelectorAll('.ic-typst__page');
    const el = pageEls?.[pageNum - 1];
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ─── PDF Export ──────────────────────────────────────────────────────
  async function doExportPdf(filepath: string) {
    if (exporting || !value.trim()) return;
    exporting = true;

    try {
      const result = await renderTypstPdf(value, buildOptions());
      if (!result.ok) {
        logger.warn('Typst', 'PDF export failed', { error: result.message });
        return;
      }

      // Send base64 PDF to MATLAB for saving
      if (request) {
        await request('savePdf', { base64: result.base64, filepath });
      }
    } catch (err) {
      logger.warn('Typst', 'PDF export error', { error: String(err) });
    } finally {
      exporting = false;
    }
  }

  // ─── Method overrides ────────────────────────────────────────────────
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
    scrollToPage = (pageNum: number) => {
      doScrollToPage(pageNum);
      return { success: true, data: null };
    };
    exportPdf = (filepath: string) => {
      doExportPdf(filepath ?? '');
      return { success: true, data: null };
    };
  });
</script>

<!-- ─── Template ─────────────────────────────────────────────────────── -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-typst"
  class:ic-typst--multi={isMultiPage}
  style:height={heightCss}
  onmouseenter={() => (hovered = true)}
  onmouseleave={() => (hovered = false)}
>
  {#if loading}
    <div class="ic-typst__status">
      <div class="ic-typst__spinner"></div>
      <span class="ic-typst__status-text">Compiling...</span>
    </div>
  {:else if errorMsg}
    <div class="ic-typst__status ic-typst__status--error">
      <span class="ic-typst__status-icon">{@html resolveIcon('triangle-alert', 20)}</span>
      <span class="ic-typst__status-text">{errorMsg}</span>
    </div>
  {:else if pages.length === 0}
    <div class="ic-typst__status">
      <span class="ic-typst__status-text">No content</span>
    </div>
  {:else}
    <div
      class="ic-typst__viewport"
      bind:this={viewportEl}
    >
      <div
        class="ic-typst__scroll-content"
        style:transform="scale({currentZoom})"
        style:transform-origin="top center"
      >
        {#each pages as pageSvg, i}
          <div
            class="ic-typst__page"
            style:margin-bottom="{i < pages.length - 1 ? (isMultiPage ? pageGap : 0) : 0}px"
          >
            {@html pageSvg}
          </div>
        {/each}
      </div>
    </div>

    <!-- Floating controls -->
    {#if toolbarOnHover}
      <div
        class="ic-typst__controls"
        class:ic-typst__controls--visible={hovered}
      >
        <button
          class="ic-typst__btn"
          onclick={doZoomIn}
          title="Zoom in"
        >
          {@html icons.plus}
        </button>

        <span class="ic-typst__info">{zoomPercent}%</span>

        <button
          class="ic-typst__btn"
          onclick={doZoomOut}
          title="Zoom out"
        >
          {@html icons.minus}
        </button>

        <div class="ic-typst__sep"></div>

        <button
          class="ic-typst__btn"
          onclick={doResetView}
          title="Reset view"
        >
          {@html icons.home}
        </button>

        <div class="ic-typst__sep"></div>

        <button
          class="ic-typst__btn"
          class:ic-typst__btn--active={exporting}
          onclick={() => doExportPdf('')}
          title="Export PDF"
          disabled={exporting}
        >
          {@html icons.download}
        </button>

        {#if isMultiPage && pages.length > 1}
          <div class="ic-typst__sep"></div>
          <span class="ic-typst__info">{pages.length} pg</span>
        {/if}
      </div>
    {/if}
  {/if}
</div>

<style>
  /* ─── Block ──────────────────────────────────────────────────────────── */
  .ic-typst {
    position: relative;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
  }

  /* Multi-page: gray background for page cards */
  .ic-typst--multi {
    background-color: var(--ic-muted);
  }

  /* ─── Viewport (scrollable area) ─────────────────────────────────────── */
  .ic-typst__viewport {
    position: relative;
    flex: 1;
    overflow: auto;
  }
  .ic-typst--multi .ic-typst__viewport {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  /* ─── Scroll content (scaled for zoom) ───────────────────────────────── */
  .ic-typst__scroll-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 12px;
  }
  .ic-typst--multi .ic-typst__scroll-content {
    padding: 16px;
  }

  /* ─── Individual page ────────────────────────────────────────────────── */
  .ic-typst__page {
    line-height: 0;
  }
  .ic-typst__page :global(svg) {
    display: block;
    width: 100%;
    height: auto;
  }

  /* Multi-page: page cards */
  .ic-typst--multi .ic-typst__page {
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
    overflow: clip;
  }

  /* ─── Floating controls ──────────────────────────────────────────────── */
  .ic-typst__controls {
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
  .ic-typst__controls--visible {
    opacity: 1;
    pointer-events: auto;
  }

  /* ─── Control buttons ────────────────────────────────────────────────── */
  .ic-typst__btn {
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
  .ic-typst__btn:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
    border-color: var(--ic-border);
  }
  .ic-typst__btn:active {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }
  .ic-typst__btn:disabled {
    opacity: 0.5;
    cursor: default;
  }
  .ic-typst__btn--active {
    color: var(--ic-primary);
  }

  /* ─── Info text ──────────────────────────────────────────────────────── */
  .ic-typst__info {
    font-family: var(--ic-font-mono, 'Roboto Mono', monospace);
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    color: var(--ic-muted-foreground);
    min-width: 40px;
    text-align: center;
    user-select: none;
    line-height: 24px;
  }

  /* ─── Separator ──────────────────────────────────────────────────────── */
  .ic-typst__sep {
    width: 1px;
    height: 16px;
    background-color: var(--ic-border);
    margin: 0 5px;
  }

  /* ─── Status states (loading, error, empty) ──────────────────────────── */
  .ic-typst__status {
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
  .ic-typst__status--error {
    color: var(--ic-destructive, #ef4444);
  }
  .ic-typst__status-text {
    font-size: 12px;
    max-width: 80%;
    text-align: center;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .ic-typst__status-icon {
    line-height: 0;
  }

  /* ─── Spinner ────────────────────────────────────────────────────────── */
  .ic-typst__spinner {
    width: 24px;
    height: 24px;
    border: 2px solid var(--ic-border);
    border-top-color: var(--ic-primary);
    border-radius: 50%;
    animation: ic-typst-spin 0.8s linear infinite;
  }
  @keyframes ic-typst-spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
