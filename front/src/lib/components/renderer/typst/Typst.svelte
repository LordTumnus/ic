<script lang="ts">
  import {
    renderTypst,
    renderTypstPdf,
    extractImagePaths,
    isShadowMapped,
    mapImagesToShadow,
    getShadowRewrites,
  } from '$lib/utils/typst-renderer';
  import type { TypstRenderOptions } from '$lib/utils/typst-renderer';
  import type { AssetData } from '$lib/utils/asset-cache';
  import { resolveIcon } from '$lib/utils/icons';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import type { Resolution, SubscribeFn, RequestFn } from '$lib/types';
  import logger from '$lib/core/logger';
  import { untrack } from 'svelte';

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
    maximize: resolveIcon('maximize', ICON_SIZE),
    download: resolveIcon('download', ICON_SIZE),
    chevronUp: resolveIcon('chevron-up', 12),
    chevronDown: resolveIcon('chevron-down', 12),
  };

  // ─── State ────────────────────────────────────────────────────────────
  let viewportEl = $state<HTMLDivElement>(undefined!);
  let loading = $state(false);
  let errorMsg = $state('');
  let pages = $state<string[]>([]);
  let currentZoom = $state(1);
  let hovered = $state(false);
  let exporting = $state(false);
  let errorExpanded = $state(false);
  let currentPage = $state(1);

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
  // Debounce: image downloads take time; without debouncing, each keystroke
  // in a live editor fires a new render that invalidates the in-progress one.
  let debounceTimer: ReturnType<typeof setTimeout> | undefined;
  const RENDER_DEBOUNCE_MS = 300;

  $effect(() => {
    const v = value;
    void styleVersion;
    const opts = buildOptions();

    if (!v.trim()) {
      clearTimeout(debounceTimer);
      ++renderTicket;
      pages = [];
      errorMsg = '';
      numPages = 0;
      return;
    }

    // Only show spinner on initial load — during recompiles, keep old pages visible
    // untrack: don't subscribe to `pages` here — resolveAndRender writes it async
    if (untrack(() => pages.length) === 0) loading = true;
    errorMsg = '';

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      const ticket = ++renderTicket;
      resolveAndRender(v, opts, ticket);
    }, RENDER_DEBOUNCE_MS);
  });

  /** Resolve images from MATLAB (if needed), then compile. */
  async function resolveAndRender(
    source: string,
    opts: TypstRenderOptions,
    ticket: number,
  ) {
    try {
      // 1. Extract image paths and filter to uncached ones
      const allPaths = extractImagePaths(source);
      const uncached = allPaths.filter((p) => !isShadowMapped(p));

      // 2. Fetch uncached images from MATLAB
      let rewrites: Record<string, string> = {};
      let imageErrors: string[] = [];
      if (uncached.length > 0 && request) {
        try {
          const res = await request('resolveImages', { paths: uncached });
          if (res.success && res.data) {
            const d = res.data as {
              paths: string | string[];
              assets: AssetData | AssetData[];
              errors?: { path: string; message: string } | { path: string; message: string }[];
            };
            // Normalize: MATLAB encodes single-element arrays as scalars
            const resPaths = Array.isArray(d.paths) ? d.paths : d.paths ? [d.paths] : [];
            const resAssets = Array.isArray(d.assets) ? d.assets : d.assets ? [d.assets] : [];
            rewrites = await mapImagesToShadow(resPaths, resAssets);

            // Collect image fetch errors from MATLAB
            if (d.errors) {
              const errs = Array.isArray(d.errors) ? d.errors : [d.errors];
              imageErrors = errs.map((e) => {
                // Shorten MATLAB HTTP errors: extract just the status
                const statusMatch = e.message.match(/status (\d+)/);
                const short = statusMatch ? `HTTP ${statusMatch[1]}` : e.message;
                // Shorten long URLs to just the filename
                const name = e.path.includes('/') ? e.path.split('/').pop() : e.path;
                return `image "${name}": ${short}`;
              });
            }
          }
        } catch (err) {
          logger.error('Typst', 'Image resolution failed', { error: String(err) });
        }
      }
      // Always merge rewrites for already-cached paths (covers mixed cached+uncached)
      if (allPaths.length > 0) {
        const cachedRewrites = getShadowRewrites(allPaths);
        rewrites = { ...cachedRewrites, ...rewrites };
      }

      // 3. Rewrite image paths in source (URLs → shadow filenames)
      let compileSrc = source;
      for (const [original, shadowName] of Object.entries(rewrites)) {
        compileSrc = compileSrc.replaceAll(original, shadowName);
      }

      // 4. Stale guard — another edit may have started during the await
      if (ticket !== renderTicket) return;

      // 5. Compile
      const result = await renderTypst(compileSrc, opts);
      if (ticket !== renderTicket) return;

      loading = false;
      if (result.ok) {
        pages = result.pages;
        numPages = result.pages.length;
        // Show image errors even on successful compilation
        errorMsg = imageErrors.length > 0 ? imageErrors.join('\n') : '';
        errorExpanded = false;
        compiled?.({ value: { numPages: result.pages.length } });
      } else {
        const parts = imageErrors.length > 0
          ? [result.message, ...imageErrors]
          : [result.message];
        errorMsg = parts.join('\n');
        errorEvent?.({ value: { message: errorMsg } });
        logger.warn('Typst', 'Compilation failed', { error: result.message });
      }
    } catch (err) {
      if (ticket !== renderTicket) return;
      loading = false;
      errorMsg = String(err);
    }
  }

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

  // ─── Track current page on scroll ───────────────────────────────────
  $effect(() => {
    if (!viewportEl) return;
    function onScroll() {
      const pageEls = viewportEl.querySelectorAll('.ic-typst__page');
      if (pageEls.length <= 1) { currentPage = 1; return; }
      // untrack: read zoom without subscribing — we only need it for the offset calc
      const zoom = untrack(() => currentZoom);
      const vpMid = viewportEl.scrollTop + viewportEl.clientHeight / 2;
      let best = 1;
      for (let i = 0; i < pageEls.length; i++) {
        if ((pageEls[i] as HTMLElement).offsetTop * zoom <= vpMid) best = i + 1;
      }
      currentPage = best;
    }
    viewportEl.addEventListener('scroll', onScroll, { passive: true });
    return () => viewportEl.removeEventListener('scroll', onScroll);
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

  function doFitPage() {
    if (!viewportEl) return;
    const firstPage = viewportEl.querySelector('.ic-typst__page');
    if (!firstPage) return;
    // offsetHeight = layout height, unaffected by parent's CSS transform: scale()
    const pageH = (firstPage as HTMLElement).offsetHeight;
    const padding = isMultiPage ? 32 : 24; // top + bottom padding of scroll-content
    const availH = viewportEl.clientHeight - padding;
    if (pageH > 0) {
      currentZoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, availH / pageH));
    }
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
  <!-- Status: only shown when no pages to display -->
  {#if loading && pages.length === 0}
    <div class="ic-typst__status">
      <div class="ic-typst__spinner"></div>
      <span class="ic-typst__status-text">Compiling...</span>
    </div>
  {:else if errorMsg && pages.length === 0}
    <div class="ic-typst__status ic-typst__status--error">
      <span class="ic-typst__status-icon">{@html resolveIcon('triangle-alert', 20)}</span>
      <span class="ic-typst__status-text">{errorMsg}</span>
    </div>
  {:else if pages.length === 0}
    <div class="ic-typst__status">
      <span class="ic-typst__status-text">No content</span>
    </div>
  {/if}

  <!-- Viewport: stays mounted once pages exist (preserves scroll position) -->
  {#if pages.length > 0}
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

    {#if errorMsg}
      <div
        class="ic-typst__error-bar"
        class:ic-typst__error-bar--expanded={errorExpanded}
      >
        <span class="ic-typst__error-bar-icon">{@html resolveIcon('triangle-alert', 12)}</span>
        <span class="ic-typst__error-bar-text">{errorMsg}</span>
        <button class="ic-typst__error-bar-toggle" onclick={() => (errorExpanded = !errorExpanded)}>
          {@html errorExpanded ? icons.chevronDown : icons.chevronUp}
        </button>
      </div>
    {/if}

    <!-- Floating controls -->
    {#if toolbarOnHover && !errorMsg}
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
          title="Reset to 100%"
        >
          {@html icons.home}
        </button>

        <button
          class="ic-typst__btn"
          onclick={doFitPage}
          title="Fit page"
        >
          {@html icons.maximize}
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
          <span class="ic-typst__info">{currentPage}/{pages.length}</span>
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
    width: 100%;
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

  /* ─── Error bar (overlay when pages exist) ────────────────────────────── */
  .ic-typst__error-bar {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    background-color: var(--ic-destructive, #ef4444);
    color: #fff;
    font-size: 11px;
    line-height: 1.4;
    overflow: clip;
  }
  .ic-typst__error-bar-icon {
    flex-shrink: 0;
    line-height: 0;
  }
  .ic-typst__error-bar-text {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ic-typst__error-bar--expanded .ic-typst__error-bar-text {
    white-space: pre-wrap;
    word-break: break-word;
    overflow: visible;
  }
  .ic-typst__error-bar-toggle {
    flex-shrink: 0;
    line-height: 0;
    opacity: 0.7;
    background: none;
    border: none;
    color: inherit;
    padding: 2px;
    cursor: pointer;
    border-radius: 2px;
  }
  .ic-typst__error-bar-toggle:hover {
    opacity: 1;
    background-color: rgba(255, 255, 255, 0.15);
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
