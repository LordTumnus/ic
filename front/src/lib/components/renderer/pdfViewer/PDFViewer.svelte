<script lang="ts">
  import '$lib/utils/polyfills';
  import { getDocument } from 'pdfjs-dist';
  import type { PDFDocumentProxy, RenderTask } from 'pdfjs-dist';
  import { resolveAsset, type AssetData } from '$lib/utils/asset-cache';
  import { resolveIcon } from '$lib/utils/icons';
  import type { Resolution } from '$lib/types';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import logger from '$lib/core/logger';

  import { initPdfWorker } from '$lib/utils/pdf-worker-init';

  // ─── Props ────────────────────────────────────────────────────────────
  let {
    value = $bindable<AssetData | null>(null),
    toolbarMode = $bindable<string>('toolbar'),
    showZoomControls = $bindable(true),
    showPageControls = $bindable(true),
    showFitButton = $bindable(true),
    showRotateButton = $bindable(false),
    page = $bindable(1),
    zoom = $bindable(100),
    numPages = $bindable(0),
    height = $bindable<CssSize>('100%'),
    // Events
    pageChanged,
    zoomChanged,
    loaded,
    error: errorEvent,
    // Methods
    nextPage = $bindable((): Resolution => ({ success: true, data: null })),
    previousPage = $bindable((): Resolution => ({ success: true, data: null })),
    zoomIn = $bindable((): Resolution => ({ success: true, data: null })),
    zoomOut = $bindable((): Resolution => ({ success: true, data: null })),
    fitWidth = $bindable((): Resolution => ({ success: true, data: null })),
    fitPage = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: AssetData | null;
    toolbarMode?: string;
    showZoomControls?: boolean;
    showPageControls?: boolean;
    showFitButton?: boolean;
    showRotateButton?: boolean;
    page?: number;
    zoom?: number;
    numPages?: number;
    height?: CssSize;
    pageChanged?: (data?: unknown) => void;
    zoomChanged?: (data?: unknown) => void;
    loaded?: (data?: unknown) => void;
    error?: (data?: unknown) => void;
    nextPage?: () => Resolution;
    previousPage?: () => Resolution;
    zoomIn?: () => Resolution;
    zoomOut?: () => Resolution;
    fitWidth?: () => Resolution;
    fitPage?: () => Resolution;
  } = $props();

  // ─── Constants ────────────────────────────────────────────────────────
  const ZOOM_STEP = 25;
  const MIN_ZOOM = 10;
  const MAX_ZOOM = 500;
  const ICON_SIZE = 16;
  // ─── Types ────────────────────────────────────────────────────────────
  interface PageInfo {
    width: number;   // natural width at scale=1
    height: number;  // natural height at scale=1
  }

  // ─── Internal State ───────────────────────────────────────────────────
  let pdfDoc: PDFDocumentProxy | null = null;
  let loadTicket = 0;
  let observer: IntersectionObserver | null = null;

  // Track render state per page: what zoom/rotation was it rendered at?
  const renderedAt = new Map<number, { zoom: number; rotation: number }>();
  const activeRenders = new Map<number, RenderTask>();

  // Suppress scroll→page sync during programmatic scroll or zoom
  let programmaticScroll = false;
  let prevZoom = zoom;
  let prevRotation = 0;

  let loading = $state(false);
  let loadError = $state(false);
  let rotation = $state(0);
  let hovered = $state(false);
  let pageInfos = $state<PageInfo[]>([]);

  let viewportEl: HTMLDivElement;
  let pageEls = $state<HTMLDivElement[]>([]);
  let canvasEls = $state<HTMLCanvasElement[]>([]);

  // ─── Derived ──────────────────────────────────────────────────────────
  const hasControls = $derived(
    showZoomControls || showPageControls || showFitButton || showRotateButton
  );
  const isToolbar = $derived(toolbarMode === 'toolbar');
  const scale = $derived(zoom / 100);

  // ─── Icons (Lucide, constant) ─────────────────────────────────────────
  const icons = {
    prev: resolveIcon('chevron-left', ICON_SIZE),
    next: resolveIcon('chevron-right', ICON_SIZE),
    minus: resolveIcon('minus', ICON_SIZE),
    plus: resolveIcon('plus', ICON_SIZE),
    fitWidth: resolveIcon('move-horizontal', ICON_SIZE),
    fitPage: resolveIcon('maximize', ICON_SIZE),
    rotate: resolveIcon('rotate-cw', ICON_SIZE),
  };

  // ─── Load PDF when value changes ──────────────────────────────────────
  $effect(() => {
    const v = value;
    const ticket = ++loadTicket;

    if (!v || !v.hash) {
      destroyDoc();
      loading = false;
      loadError = false;
      return;
    }

    loading = true;
    loadError = false;
    loadPdfAsync(v, ticket);
  });

  // ─── Set up IntersectionObserver to lazily render visible pages ────────
  $effect(() => {
    // Re-run when pageInfos or zoom/rotation change
    const infos = pageInfos;
    const z = zoom;
    const r = rotation;
    if (infos.length === 0 || !viewportEl) return;

    // Clean up previous observer
    if (observer) observer.disconnect();

    // Render pages that are visible (or nearly visible)
    observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const idx = parseInt(entry.target.getAttribute('data-page-idx') ?? '-1');
          if (idx < 0) continue;
          if (entry.isIntersecting) {
            renderPageIfNeeded(idx + 1, z, r);
          }
        }
      },
      { root: viewportEl, rootMargin: '200px 0px' }
    );

    // Observe all page elements
    for (const el of pageEls) {
      if (el) observer.observe(el);
    }

    // Also render currently visible pages immediately (handles zoom/rotation changes)
    for (let i = 0; i < infos.length; i++) {
      if (isPageVisible(i)) {
        renderPageIfNeeded(i + 1, z, r);
      }
    }

    return () => {
      observer?.disconnect();
      observer = null;
    };
  });

  // ─── Track current page via scroll position ───────────────────────────
  function handleScroll() {
    if (programmaticScroll || !viewportEl || pageEls.length === 0) return;

    const viewTop = viewportEl.scrollTop;
    const viewMid = viewTop + viewportEl.clientHeight / 2;

    let closestIdx = 0;
    let closestDist = Infinity;
    for (let i = 0; i < pageEls.length; i++) {
      const el = pageEls[i];
      if (!el) continue;
      const pageMid = el.offsetTop + el.offsetHeight / 2;
      const dist = Math.abs(pageMid - viewMid);
      if (dist < closestDist) {
        closestDist = dist;
        closestIdx = i;
      }
    }

    const newPage = closestIdx + 1;
    if (newPage !== page) {
      page = newPage;
      pageChanged?.({ value: page });
    }
  }

  // ─── Preserve scroll position on zoom/rotation change ─────────────────
  $effect(() => {
    const z = zoom;
    const r = rotation;
    if (pageInfos.length === 0 || !viewportEl) return;

    if (z !== prevZoom || r !== prevRotation) {
      // Compute scroll ratio before sizes change
      const scrollRatio = viewportEl.scrollHeight > 0
        ? viewportEl.scrollTop / viewportEl.scrollHeight
        : 0;

      // Clear stale canvas content
      for (const canvas of canvasEls) {
        if (canvas) {
          const ctx = canvas.getContext('2d');
          ctx?.clearRect(0, 0, canvas.width, canvas.height);
        }
      }
      renderedAt.clear();

      // Restore scroll position after layout updates
      requestAnimationFrame(() => {
        if (viewportEl) {
          programmaticScroll = true;
          viewportEl.scrollTop = scrollRatio * viewportEl.scrollHeight;
          programmaticScroll = false;
        }
      });

      prevZoom = z;
      prevRotation = r;
    }
  });

  // ─── Scroll to a specific page element (explicit, not reactive) ───────
  function scrollToPageEl(p: number) {
    const idx = p - 1;
    const el = pageEls[idx];
    if (!el || !viewportEl) return;

    programmaticScroll = true;
    el.scrollIntoView({ block: 'start', behavior: 'auto' });
    requestAnimationFrame(() => {
      programmaticScroll = false;
    });
  }

  // ─── Method overrides ─────────────────────────────────────────────────
  $effect(() => {
    nextPage = () => {
      goToPage(page + 1);
      return { success: true, data: null };
    };
    previousPage = () => {
      goToPage(page - 1);
      return { success: true, data: null };
    };
    zoomIn = () => {
      setZoom(zoom + ZOOM_STEP);
      return { success: true, data: null };
    };
    zoomOut = () => {
      setZoom(zoom - ZOOM_STEP);
      return { success: true, data: null };
    };
    fitWidth = () => {
      doFitWidth();
      return { success: true, data: null };
    };
    fitPage = () => {
      doFitPage();
      return { success: true, data: null };
    };
  });

  // ─── Helpers ───────────────────────────────────────────────────────────

  function destroyDoc() {
    cancelAllRenders();
    renderedAt.clear();
    if (pdfDoc) {
      pdfDoc.destroy();
      pdfDoc = null;
    }
    pageInfos = [];
    numPages = 0;
    pageEls = [];
    canvasEls = [];
  }

  function cancelAllRenders() {
    for (const [, task] of activeRenders) {
      try { task.cancel(); } catch { /* already done */ }
    }
    activeRenders.clear();
  }

  async function loadPdfAsync(asset: AssetData, ticket: number) {
    try {
      // Ensure pdf.js worker is initialized (real Worker or main-thread fallback)
      await initPdfWorker();

      const resolved = resolveAsset(asset);
      if (!resolved) {
        if (ticket !== loadTicket) return;
        loading = false;
        loadError = true;
        errorEvent?.({ error: 'Could not resolve asset' });
        return;
      }

      const binary = atob(resolved.data);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

      const doc = await getDocument({ data: bytes }).promise;
      if (ticket !== loadTicket) {
        doc.destroy();
        return;
      }

      // Replace previous document
      if (pdfDoc) pdfDoc.destroy();
      pdfDoc = doc;
      numPages = doc.numPages;

      // Gather page dimensions
      const infos: PageInfo[] = [];
      for (let i = 1; i <= doc.numPages; i++) {
        const pg = await doc.getPage(i);
        const vp = pg.getViewport({ scale: 1, rotation: 0 });
        infos.push({ width: vp.width, height: vp.height });
      }
      if (ticket !== loadTicket) return;

      pageInfos = infos;
      pageEls = new Array(infos.length);
      canvasEls = new Array(infos.length);
      page = 1;
      rotation = 0;
      renderedAt.clear();
      loading = false;
      loadError = false;

      loaded?.({ numPages: doc.numPages });
    } catch (err) {
      if (ticket !== loadTicket) return;
      logger.error('PDFViewer', 'Load failed', { error: String(err) });
      loading = false;
      loadError = true;
      errorEvent?.({ error: String(err) });
    }
  }

  function isPageVisible(idx: number): boolean {
    const el = pageEls[idx];
    if (!el || !viewportEl) return false;
    const viewTop = viewportEl.scrollTop;
    const viewBottom = viewTop + viewportEl.clientHeight;
    const elTop = el.offsetTop;
    const elBottom = elTop + el.offsetHeight;
    return elBottom > viewTop && elTop < viewBottom;
  }

  async function renderPageIfNeeded(pageNum: number, z: number, rot: number) {
    const prev = renderedAt.get(pageNum);
    if (prev && prev.zoom === z && prev.rotation === rot) return;

    // Cancel any in-progress render for this page
    const existing = activeRenders.get(pageNum);
    if (existing) {
      try { existing.cancel(); } catch { /* */ }
      activeRenders.delete(pageNum);
    }

    if (!pdfDoc) return;
    const canvas = canvasEls[pageNum - 1];
    if (!canvas) return;

    try {
      const pg = await pdfDoc.getPage(pageNum);
      const viewport = pg.getViewport({ scale: z / 100, rotation: rot });
      const outputScale = window.devicePixelRatio || 1;

      canvas.width = Math.floor(viewport.width * outputScale);
      canvas.height = Math.floor(viewport.height * outputScale);
      canvas.style.width = `${Math.floor(viewport.width)}px`;
      canvas.style.height = `${Math.floor(viewport.height)}px`;

      const transform =
        outputScale !== 1
          ? [outputScale, 0, 0, outputScale, 0, 0] as [number, number, number, number, number, number]
          : undefined;

      const ctx = canvas.getContext('2d')!;
      const renderTask = pg.render({ canvasContext: ctx, viewport, transform });
      activeRenders.set(pageNum, renderTask);
      await renderTask.promise;
      activeRenders.delete(pageNum);
      renderedAt.set(pageNum, { zoom: z, rotation: rot });
    } catch (err: unknown) {
      activeRenders.delete(pageNum);
      const errObj = err as { name?: string };
      if (errObj.name === 'RenderingCancelledException') return;
      logger.error('PDFViewer', `Render page ${pageNum} failed`, { error: String(err) });
    }
  }

  // ─── Page navigation ──────────────────────────────────────────────────

  function goToPage(p: number) {
    const clamped = Math.max(1, Math.min(p, numPages));
    if (clamped !== page) {
      page = clamped;
      pageChanged?.({ value: page });
      scrollToPageEl(clamped);
    }
  }

  function setZoom(z: number) {
    const clamped = Math.max(MIN_ZOOM, Math.min(z, MAX_ZOOM));
    if (clamped !== zoom) {
      zoom = clamped;
      zoomChanged?.({ value: zoom });
    }
  }

  function handlePrevPage() { goToPage(page - 1); }
  function handleNextPage() { goToPage(page + 1); }
  function handleZoomOut() { setZoom(zoom - ZOOM_STEP); }
  function handleZoomIn() { setZoom(zoom + ZOOM_STEP); }

  async function doFitWidth() {
    if (!pdfDoc || !viewportEl || pageInfos.length === 0) return;
    try {
      const pg = await pdfDoc.getPage(page);
      const vp = pg.getViewport({ scale: 1, rotation });
      const available = viewportEl.clientWidth - 16;
      const newZoom = Math.round((available / vp.width) * 100);
      setZoom(newZoom);
    } catch (err) {
      logger.error('PDFViewer', 'fitWidth failed', { error: String(err) });
    }
  }

  async function doFitPage() {
    if (!pdfDoc || !viewportEl || pageInfos.length === 0) return;
    try {
      const pg = await pdfDoc.getPage(page);
      const vp = pg.getViewport({ scale: 1, rotation });
      const availW = viewportEl.clientWidth - 16;
      const availH = viewportEl.clientHeight - 16;
      const scaleX = availW / vp.width;
      const scaleY = availH / vp.height;
      const newZoom = Math.round(Math.min(scaleX, scaleY) * 100);
      setZoom(newZoom);
    } catch (err) {
      logger.error('PDFViewer', 'fitPage failed', { error: String(err) });
    }
  }

  function handleRotate() {
    renderedAt.clear();
    rotation = (rotation + 90) % 360;
  }

  function scaledSize(info: PageInfo): { w: number; h: number } {
    const rot = rotation % 360;
    const swapped = rot === 90 || rot === 270;
    const w = swapped ? info.height : info.width;
    const h = swapped ? info.width : info.height;
    return { w: Math.floor(w * scale), h: Math.floor(h * scale) };
  }
</script>

<!-- ─── Controls snippet (shared between toolbar and hover) ──────────── -->
{#snippet controls(mode: 'toolbar' | 'hover')}
  {#if showPageControls}
    <div class="ic-pdfv__group">
      <button
        class="ic-pdfv__btn ic-pdfv__btn--{mode}"
        disabled={page <= 1}
        onclick={handlePrevPage}
        title="Previous page"
      >
        {@html icons.prev}
      </button>
      <span class="ic-pdfv__info ic-pdfv__info--{mode}">{page} / {numPages}</span>
      <button
        class="ic-pdfv__btn ic-pdfv__btn--{mode}"
        disabled={page >= numPages}
        onclick={handleNextPage}
        title="Next page"
      >
        {@html icons.next}
      </button>
    </div>
  {/if}

  {#if showPageControls && showZoomControls}
    <div class="ic-pdfv__sep ic-pdfv__sep--{mode}"></div>
  {/if}

  {#if showZoomControls}
    <div class="ic-pdfv__group">
      <button
        class="ic-pdfv__btn ic-pdfv__btn--{mode}"
        disabled={zoom <= MIN_ZOOM}
        onclick={handleZoomOut}
        title="Zoom out"
      >
        {@html icons.minus}
      </button>
      <span class="ic-pdfv__info ic-pdfv__info--{mode}">{zoom}%</span>
      <button
        class="ic-pdfv__btn ic-pdfv__btn--{mode}"
        disabled={zoom >= MAX_ZOOM}
        onclick={handleZoomIn}
        title="Zoom in"
      >
        {@html icons.plus}
      </button>
    </div>
  {/if}

  {#if showFitButton && (showPageControls || showZoomControls)}
    <div class="ic-pdfv__sep ic-pdfv__sep--{mode}"></div>
  {/if}

  {#if showFitButton}
    <button
      class="ic-pdfv__btn ic-pdfv__btn--{mode}"
      onclick={() => doFitWidth()}
      title="Fit to width"
    >
      {@html icons.fitWidth}
    </button>
    <button
      class="ic-pdfv__btn ic-pdfv__btn--{mode}"
      onclick={() => doFitPage()}
      title="Fit to page"
    >
      {@html icons.fitPage}
    </button>
  {/if}

  {#if showRotateButton}
    <button
      class="ic-pdfv__btn ic-pdfv__btn--{mode}"
      onclick={handleRotate}
      title="Rotate 90°"
    >
      {@html icons.rotate}
    </button>
  {/if}
{/snippet}

<!-- ─── Template ─────────────────────────────────────────────────────── -->
<div class="ic-pdfv" style:height={toSize(height)}>
  {#if isToolbar && hasControls}
    <div class="ic-pdfv__toolbar">
      {@render controls('toolbar')}
    </div>
  {/if}

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-pdfv__viewport"
    bind:this={viewportEl}
    onscroll={handleScroll}
    onmouseenter={() => (hovered = true)}
    onmouseleave={() => (hovered = false)}
  >
    {#if loading}
      <div class="ic-pdfv__status">
        <div class="ic-pdfv__spinner"></div>
      </div>
    {:else if loadError}
      <div class="ic-pdfv__status">
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10" />
          <line x1="15" y1="9" x2="9" y2="15" />
          <line x1="9" y1="9" x2="15" y2="15" />
        </svg>
        <span class="ic-pdfv__status-text">Failed to load PDF</span>
      </div>
    {:else if pageInfos.length === 0}
      <div class="ic-pdfv__status">
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" />
          <line x1="16" y1="13" x2="8" y2="13" />
          <line x1="16" y1="17" x2="8" y2="17" />
        </svg>
        <span class="ic-pdfv__status-text">No document</span>
      </div>
    {:else}
      <div class="ic-pdfv__pages">
        {#each pageInfos as info, i}
          {@const size = scaledSize(info)}
          <div
            class="ic-pdfv__page"
            style:width="{size.w}px"
            style:height="{size.h}px"
            data-page-idx={i}
            bind:this={pageEls[i]}
          >
            <canvas bind:this={canvasEls[i]} class="ic-pdfv__canvas"></canvas>
          </div>
        {/each}
      </div>
    {/if}

    {#if !isToolbar && hasControls && numPages > 0}
      <div
        class="ic-pdfv__hover-bar"
        class:ic-pdfv__hover-bar--visible={hovered}
      >
        {@render controls('hover')}
      </div>
    {/if}
  </div>
</div>

<style>
  /* ─── Block ──────────────────────────────────────────────────────────── */
  .ic-pdfv {
    position: relative;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-secondary);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
  }

  /* ─── Toolbar ────────────────────────────────────────────────────────── */
  .ic-pdfv__toolbar {
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 3px 8px;
    background-color: var(--ic-secondary);
    border-bottom: 1px solid var(--ic-border);
    box-shadow: inset 0 -1px 2px rgba(0, 0, 0, 0.06);
    min-height: 30px;
    flex-shrink: 0;
  }

  /* ─── Viewport (scrollable area) ────────────────────────────────────── */
  .ic-pdfv__viewport {
    position: relative;
    flex: 1;
    overflow: auto;
    background-color: var(--ic-muted);
  }

  /* ─── Pages column ─────────────────────────────────────────────────── */
  .ic-pdfv__pages {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 8px;
  }

  /* ─── Page wrapper (sized placeholder) ─────────────────────────────── */
  .ic-pdfv__page {
    flex-shrink: 0;
    position: relative;
    background-color: var(--ic-background);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
  }

  /* ─── Canvas ─────────────────────────────────────────────────────────── */
  .ic-pdfv__canvas {
    display: block;
  }

  /* ─── Hover bar (floating controls) ──────────────────────────────────── */
  .ic-pdfv__hover-bar {
    position: sticky;
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
  .ic-pdfv__hover-bar--visible {
    opacity: 1;
    pointer-events: auto;
  }

  /* ─── Control group ──────────────────────────────────────────────────── */
  .ic-pdfv__group {
    display: flex;
    align-items: center;
    gap: 1px;
  }

  /* ─── Separator ──────────────────────────────────────────────────────── */
  .ic-pdfv__sep {
    width: 1px;
    height: 16px;
    background-color: var(--ic-border);
    margin: 0 5px;
  }

  /* ─── Buttons (shared base) ──────────────────────────────────────────── */
  .ic-pdfv__btn {
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
  .ic-pdfv__btn:hover:not(:disabled) {
    color: var(--ic-foreground);
    background-color: var(--ic-background);
    border-color: var(--ic-border);
  }
  .ic-pdfv__btn:active:not(:disabled) {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }
  .ic-pdfv__btn:disabled {
    opacity: 0.35;
    cursor: default;
  }

  /* Toolbar-specific button overrides */
  .ic-pdfv__btn--toolbar:hover:not(:disabled) {
    background-color: var(--ic-background);
  }

  /* Hover-bar-specific button overrides */
  .ic-pdfv__btn--hover:hover:not(:disabled) {
    background-color: var(--ic-muted);
  }

  /* ─── Info text (page indicator, zoom %) ─────────────────────────────── */
  .ic-pdfv__info {
    font-family: var(--ic-font-mono, 'Roboto Mono', monospace);
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    color: var(--ic-muted-foreground);
    min-width: 44px;
    text-align: center;
    user-select: none;
    line-height: 24px;
  }

  /* ─── Status states (loading, error, empty) ──────────────────────────── */
  .ic-pdfv__status {
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
  .ic-pdfv__status-text {
    font-size: 12px;
  }

  /* ─── Spinner ────────────────────────────────────────────────────────── */
  .ic-pdfv__spinner {
    width: 24px;
    height: 24px;
    border: 2px solid var(--ic-border);
    border-top-color: var(--ic-primary);
    border-radius: 50%;
    animation: ic-pdfv-spin 0.8s linear infinite;
  }
  @keyframes ic-pdfv-spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
