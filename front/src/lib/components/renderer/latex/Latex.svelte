<script lang="ts">
  import '$lib/utils/polyfills';
  import { getDocument } from 'pdfjs-dist';
  import type { PDFDocumentProxy, RenderTask } from 'pdfjs-dist';
  import {
    compileLaTeX,
    extractImagePaths,
    isShadowMapped,
    mapImagesToShadow,
    getShadowRewrites,
    uint8ArrayToBase64,
  } from '$lib/utils/latex-renderer';
  import type { AssetData } from '$lib/utils/asset-cache';
  import { resolveIcon } from '$lib/utils/icons';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import type { Resolution, SubscribeFn, RequestFn } from '$lib/types';
  import logger from '$lib/core/logger';
  import { onMount, tick, untrack } from 'svelte';

  import { initPdfWorker } from '$lib/utils/pdf-worker-init';

  // ─── Props ────────────────────────────────────────────────────────────
  let {
    value = $bindable(''),
    height = $bindable<CssSize>('100%'),
    toolbarOnHover = $bindable(true),
    pageGap = $bindable(16),
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
    renderOnChange = $bindable(true),
    render = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: string;
    height?: CssSize;
    toolbarOnHover?: boolean;
    pageGap?: number;
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
    renderOnChange?: boolean;
    render?: () => Resolution;
  } = $props();

  // ─── Constants ────────────────────────────────────────────────────────
  const ZOOM_STEP = 0.2;
  const MIN_ZOOM = 0.25;
  const MAX_ZOOM = 4;
  const ICON_SIZE = 14;
  const RENDER_DEBOUNCE_MS = 300;

  const icons = {
    plus: resolveIcon('plus', ICON_SIZE),
    minus: resolveIcon('minus', ICON_SIZE),
    home: resolveIcon('home', ICON_SIZE),
    maximize: resolveIcon('maximize', ICON_SIZE),
    download: resolveIcon('download', ICON_SIZE),
    refreshCw: resolveIcon('refresh-cw', ICON_SIZE),
    chevronUp: resolveIcon('chevron-up', 12),
    chevronDown: resolveIcon('chevron-down', 12),
  };

  // ─── Types ────────────────────────────────────────────────────────────
  interface PageInfo {
    width: number;
    height: number;
  }

  // ─── State ────────────────────────────────────────────────────────────
  let viewportEl = $state<HTMLDivElement>(undefined!);
  let loading = $state(false);
  let errorMsg = $state('');
  let currentZoom = $state(1);
  let hovered = $state(false);
  let exporting = $state(false);
  let errorExpanded = $state(false);
  let currentPage = $state(1);
  let pendingRender = $state(false);

  let pageInfos = $state<PageInfo[]>([]);
  let pageEls = $state<HTMLDivElement[]>([]);
  let canvasEls = $state<HTMLCanvasElement[]>([]);

  // PDF state
  let pdfDoc: PDFDocumentProxy | null = null;
  let lastPdfBytes: Uint8Array | null = null;
  const renderedAt = new Map<number, number>(); // pageNum → zoom it was rendered at
  const activeRenders = new Map<number, RenderTask>();
  let observer: IntersectionObserver | null = null;

  // Render versioning
  let renderTicket = 0;
  let hasRenderedOnce = false;
  let styleVersion = $state(0);
  let prevRenderScale = 0;

  // Viewport-aware scaling: baseScale maps PDF points → fit-width pixels,
  // so currentZoom=1 fills the viewport width (same mental model as Typst).
  let viewportWidth = $state(0);

  const heightCss = $derived(toSize(height));
  const isMultiPage = $derived(pageInfos.length > 1);

  const baseScale = $derived.by(() => {
    if (viewportWidth === 0 || pageInfos.length === 0) return 1;
    const maxW = Math.max(...pageInfos.map((p) => p.width));
    if (maxW === 0) return 1;
    const hPadding = isMultiPage ? 32 : 24;
    const border = isMultiPage ? 2 : 0;
    return (viewportWidth - hPadding - border) / maxW;
  });

  const renderScale = $derived(baseScale * currentZoom);
  const zoomPercent = $derived(Math.round(currentZoom * 100));

  // ─── Watch for style() changes ───────────────────────────────────────
  $effect(() => {
    const unsub = subscribe('@style', () => { styleVersion++; });
    return unsub;
  });

  // ─── Track viewport width for fit-width scaling ─────────────────────
  $effect(() => {
    if (!viewportEl) return;
    viewportWidth = viewportEl.clientWidth;
    const ro = new ResizeObserver((entries) => {
      for (const entry of entries) {
        viewportWidth =
          entry.contentBoxSize?.[0]?.inlineSize ?? entry.target.clientWidth;
      }
    });
    ro.observe(viewportEl);
    return () => ro.disconnect();
  });

  // ─── Render when value changes ────────────────────────────────────────
  let debounceTimer: ReturnType<typeof setTimeout> | undefined;

  $effect(() => {
    const v = value;
    void styleVersion;
    const roc = renderOnChange;

    if (!v.trim()) {
      clearTimeout(debounceTimer);
      ++renderTicket;
      destroyDoc();
      errorMsg = '';
      numPages = 0;
      pendingRender = false;
      return;
    }

    if (!roc && hasRenderedOnce) { pendingRender = true; return; }

    hasRenderedOnce = true;
    pendingRender = false;
    if (untrack(() => pageInfos.length) === 0) loading = true;
    errorMsg = '';

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      const ticket = ++renderTicket;
      resolveAndRender(v, ticket);
    }, RENDER_DEBOUNCE_MS);
  });

  /** Resolve images from MATLAB (if needed), then compile. */
  async function resolveAndRender(source: string, ticket: number) {
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
            const resPaths = Array.isArray(d.paths) ? d.paths : d.paths ? [d.paths] : [];
            const resAssets = Array.isArray(d.assets) ? d.assets : d.assets ? [d.assets] : [];
            rewrites = await mapImagesToShadow(resPaths, resAssets);

            if (d.errors) {
              const errs = Array.isArray(d.errors) ? d.errors : [d.errors];
              imageErrors = errs.map((e) => {
                const statusMatch = e.message.match(/status (\d+)/);
                const short = statusMatch ? `HTTP ${statusMatch[1]}` : e.message;
                const name = e.path.includes('/') ? e.path.split('/').pop() : e.path;
                return `image "${name}": ${short}`;
              });
              for (const msg of imageErrors) logger.warn('LaTeX', msg);
            }
          }
        } catch (err) {
          logger.error('LaTeX', 'Image resolution failed', { error: String(err) });
        }
      }
      // Merge cached rewrites
      if (allPaths.length > 0) {
        const cachedRewrites = getShadowRewrites(allPaths);
        rewrites = { ...cachedRewrites, ...rewrites };
      }

      // 3. Rewrite image paths in source
      let compileSrc = source;
      for (const [original, shadowName] of Object.entries(rewrites)) {
        compileSrc = compileSrc.replaceAll(original, shadowName);
      }

      // 4. Stale guard
      if (ticket !== renderTicket) return;

      // 5. Compile LaTeX to PDF
      const result = await compileLaTeX(compileSrc);
      if (ticket !== renderTicket) return;

      loading = false;
      if (result.ok) {
        // Store a COPY — pdfjs-dist may detach the original ArrayBuffer
        lastPdfBytes = new Uint8Array(result.pdf);
        await loadPdfFromBytes(result.pdf, ticket);
        // Show image errors even on successful compilation
        errorMsg = imageErrors.length > 0 ? imageErrors.join('\n') : '';
        errorExpanded = false;
      } else {
        // Include the TeX log when the parsed message is generic
        const hasSpecificError = result.message !== 'Compilation failed (check log)';
        const msgParts = hasSpecificError
          ? [result.message]
          : result.log ? [result.log] : [result.message];
        const parts = [...imageErrors, ...msgParts];
        errorMsg = parts.join('\n');
        errorEvent?.({ value: { message: errorMsg } });
        logger.warn('LaTeX', 'Compilation failed', { error: result.message, log: result.log });
      }
    } catch (err) {
      if (ticket !== renderTicket) return;
      loading = false;
      errorMsg = String(err);
    }
  }

  // ─── PDF Loading (pdfjs-dist) ──────────────────────────────────────────
  async function loadPdfFromBytes(bytes: Uint8Array, ticket: number) {
    await initPdfWorker();
    const doc = await getDocument({ data: bytes }).promise;
    if (ticket !== renderTicket) {
      doc.destroy();
      return;
    }

    // Replace previous document
    destroyDoc();
    pdfDoc = doc;
    numPages = doc.numPages;

    // Gather page dimensions
    const infos: PageInfo[] = [];
    for (let i = 1; i <= doc.numPages; i++) {
      const pg = await doc.getPage(i);
      const vp = pg.getViewport({ scale: 1 });
      infos.push({ width: vp.width, height: vp.height });
    }
    if (ticket !== renderTicket) return;

    pageInfos = infos;
    pageEls = new Array(infos.length);
    canvasEls = new Array(infos.length);
    renderedAt.clear();

    compiled?.({ value: { numPages: doc.numPages } });
  }

  function destroyDoc() {
    cancelAllRenders();
    renderedAt.clear();
    if (pdfDoc) {
      pdfDoc.destroy();
      pdfDoc = null;
    }
    pageInfos = [];
    pageEls = [];
    canvasEls = [];
  }

  function cancelAllRenders() {
    for (const [, task] of activeRenders) {
      try { task.cancel(); } catch { /* already done */ }
    }
    activeRenders.clear();
  }

  // ─── Canvas rendering (IntersectionObserver) ──────────────────────────
  $effect(() => {
    const infos = pageInfos;
    const rs = renderScale;
    if (infos.length === 0 || !viewportEl) return;

    // Clean up previous observer
    if (observer) observer.disconnect();

    observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const idx = parseInt(entry.target.getAttribute('data-page-idx') ?? '-1');
          if (idx < 0) continue;
          if (entry.isIntersecting) {
            renderPageIfNeeded(idx + 1, rs);
          }
        }
      },
      { root: viewportEl, rootMargin: '200px 0px' },
    );

    for (const el of pageEls) {
      if (el) observer.observe(el);
    }

    // Render currently visible pages immediately
    for (let i = 0; i < infos.length; i++) {
      if (isPageVisible(i)) {
        renderPageIfNeeded(i + 1, rs);
      }
    }

    return () => {
      observer?.disconnect();
      observer = null;
    };
  });

  // ─── Preserve scroll position on scale change ─────────────────────────
  $effect(() => {
    const rs = renderScale;
    if (pageInfos.length === 0 || !viewportEl) return;

    if (rs !== prevRenderScale) {
      const scrollRatio = viewportEl.scrollHeight > 0
        ? viewportEl.scrollTop / viewportEl.scrollHeight
        : 0;

      // Don't clear canvases eagerly — stale content at old zoom (slightly
      // blurry) is better UX than a white flash. renderPageIfNeeded() resets
      // canvas dimensions which clears them right before painting fresh content.
      renderedAt.clear();

      requestAnimationFrame(() => {
        if (viewportEl) {
          viewportEl.scrollTop = scrollRatio * viewportEl.scrollHeight;
        }
      });

      prevRenderScale = rs;
    }
  });

  function isPageVisible(idx: number): boolean {
    const el = pageEls[idx];
    if (!el || !viewportEl) return false;
    const viewTop = viewportEl.scrollTop;
    const viewBottom = viewTop + viewportEl.clientHeight;
    const elTop = el.offsetTop;
    const elBottom = elTop + el.offsetHeight;
    return elBottom > viewTop && elTop < viewBottom;
  }

  async function renderPageIfNeeded(pageNum: number, z: number) {
    const prev = renderedAt.get(pageNum);
    if (prev === z) return;

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
      const viewport = pg.getViewport({ scale: z });
      const outputScale = window.devicePixelRatio || 1;

      canvas.width = Math.floor(viewport.width * outputScale);
      canvas.height = Math.floor(viewport.height * outputScale);
      canvas.style.width = `${Math.floor(viewport.width)}px`;
      canvas.style.height = `${Math.floor(viewport.height)}px`;

      const transform: [number, number, number, number, number, number] | undefined =
        outputScale !== 1
          ? [outputScale, 0, 0, outputScale, 0, 0]
          : undefined;

      const ctx = canvas.getContext('2d')!;
      const renderTask = pg.render({ canvasContext: ctx, viewport, transform });
      activeRenders.set(pageNum, renderTask);
      await renderTask.promise;
      activeRenders.delete(pageNum);
      renderedAt.set(pageNum, z);
    } catch (err: unknown) {
      activeRenders.delete(pageNum);
      const errObj = err as { name?: string };
      if (errObj.name === 'RenderingCancelledException') return;
      logger.error('LaTeX', `Render page ${pageNum} failed`, { error: String(err) });
    }
  }

  // ─── Handle PDF link annotations ──────────────────────────────────────
  async function renderAnnotations(pageNum: number, pageEl: HTMLDivElement) {
    if (!pdfDoc) return;

    // Remove previous annotation overlays
    pageEl.querySelectorAll('.ic-latex__link-overlay').forEach(el => el.remove());

    try {
      const pg = await pdfDoc.getPage(pageNum);
      const viewport = pg.getViewport({ scale: renderScale });
      const annotations = await pg.getAnnotations();

      for (const ann of annotations) {
        if (ann.subtype !== 'Link') continue;

        const rect = viewport.convertToViewportRectangle(ann.rect);
        const left = Math.min(rect[0], rect[2]);
        const top = Math.min(rect[1], rect[3]);
        const w = Math.abs(rect[2] - rect[0]);
        const h = Math.abs(rect[3] - rect[1]);

        const div = document.createElement('div');
        div.className = 'ic-latex__link-overlay';
        div.style.cssText = `position:absolute;left:${left}px;top:${top}px;width:${w}px;height:${h}px;cursor:pointer;`;
        div.onclick = (e) => {
          e.preventDefault();
          e.stopPropagation();
          if (ann.url && request) {
            request('openLink', { url: ann.url });
          } else if (ann.dest && pdfDoc) {
            // dest can be a string (named destination) or an array (explicit destination)
            const destPromise = typeof ann.dest === 'string'
              ? pdfDoc.getDestination(ann.dest)
              : Promise.resolve(ann.dest);
            destPromise.then(dest => {
              if (dest) {
                pdfDoc!.getPageIndex(dest[0]).then(idx => {
                  doScrollToPage(idx + 1);
                });
              }
            });
          }
        };
        pageEl.appendChild(div);
      }
    } catch (err) {
      logger.error('LaTeX', `Annotations for page ${pageNum} failed`, { error: String(err) });
    }
  }

  // Re-render annotations when pages are rendered or scale changes
  $effect(() => {
    if (pageInfos.length === 0 || !pdfDoc) return;
    // Read renderScale synchronously so Svelte tracks it as a dependency —
    // the async renderAnnotations() reads it after an await, which is invisible
    // to effect tracking.
    const _scale = renderScale;
    for (let i = 0; i < pageInfos.length; i++) {
      if (pageEls[i]) {
        renderAnnotations(i + 1, pageEls[i]);
      }
    }
  });

  // ─── Track current page on scroll ───────────────────────────────────
  $effect(() => {
    if (!viewportEl) return;
    function onScroll() {
      if (pageEls.length <= 1) { currentPage = 1; return; }
      const vpMid = viewportEl.scrollTop + viewportEl.clientHeight / 2;
      let best = 1;
      for (let i = 0; i < pageEls.length; i++) {
        if (pageEls[i] && pageEls[i].offsetTop <= vpMid) best = i + 1;
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
    if (viewportEl) viewportEl.scrollTop = 0;
  }

  function doFitPage() {
    if (!viewportEl || pageInfos.length === 0 || baseScale <= 0) return;
    const info = pageInfos[0];
    const vPadding = isMultiPage ? 32 : 24;
    const availH = viewportEl.clientHeight - vPadding;
    if (info.height > 0) {
      currentZoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, availH / (info.height * baseScale)));
    }
  }

  function doScrollToPage(pageNum: number) {
    const el = pageEls[pageNum - 1];
    if (el) el.scrollIntoView({ behavior: 'instant', block: 'start' });
  }

  // ─── Manual render ──────────────────────────────────────────────────
  async function doRender() {
    const ticket = ++renderTicket;
    pendingRender = false;
    if (!value.trim()) return;
    if (pageInfos.length === 0) loading = true;

    // Preserve scroll position across re-render
    const savedScrollTop = viewportEl?.scrollTop ?? 0;
    await resolveAndRender(value, ticket);

    // Restore after Svelte flushes DOM updates
    if (viewportEl && ticket === renderTicket) {
      await tick();
      viewportEl.scrollTop = savedScrollTop;
    }
  }

  // ─── PDF Export ──────────────────────────────────────────────────────
  async function doExportPdf(filepath: string) {
    if (exporting || !lastPdfBytes) return;
    exporting = true;

    try {
      const base64 = uint8ArrayToBase64(lastPdfBytes);
      if (request) {
        await request('savePdf', { base64, filepath });
      }
    } catch (err) {
      logger.warn('LaTeX', 'PDF export error', { error: String(err) });
    } finally {
      exporting = false;
    }
  }

  // ─── Scaled page size ────────────────────────────────────────────────
  function scaledSize(info: PageInfo): { w: number; h: number } {
    return {
      w: Math.floor(info.width * renderScale),
      h: Math.floor(info.height * renderScale),
    };
  }

  // ─── Method overrides ────────────────────────────────────────────────
  onMount(() => {
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
    render = () => {
      doRender();
      return { success: true, data: null };
    };
  });
</script>

<!-- ─── Template ─────────────────────────────────────────────────────── -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-latex"
  class:ic-latex--multi={isMultiPage}
  style:height={heightCss}
  onmouseenter={() => (hovered = true)}
  onmouseleave={() => (hovered = false)}
>
  <!-- Status: only shown when no pages to display -->
  {#if loading && pageInfos.length === 0}
    <div class="ic-latex__status">
      <div class="ic-latex__spinner"></div>
      <span class="ic-latex__status-text">Compiling...</span>
    </div>
  {:else if errorMsg && pageInfos.length === 0}
    <div class="ic-latex__status ic-latex__status--error">
      <span class="ic-latex__status-icon">{@html resolveIcon('triangle-alert', 20)}</span>
      <span class="ic-latex__status-text">{errorMsg}</span>
    </div>
  {:else if pageInfos.length === 0}
    <div class="ic-latex__status">
      <span class="ic-latex__status-text">No content</span>
    </div>
  {/if}

  <!-- Viewport: stays mounted once pages exist (preserves scroll position) -->
  {#if pageInfos.length > 0}
    <div
      class="ic-latex__viewport"
      bind:this={viewportEl}
    >
      <div class="ic-latex__pages">
        {#each pageInfos as info, i (i)}
          {@const size = scaledSize(info)}
          <div
            class="ic-latex__page"
            style:width="{size.w}px"
            style:height="{size.h}px"
            style:margin-bottom="{i < pageInfos.length - 1 ? (isMultiPage ? pageGap : 0) : 0}px"
            data-page-idx={i}
            bind:this={pageEls[i]}
          >
            <canvas bind:this={canvasEls[i]} class="ic-latex__canvas"></canvas>
          </div>
        {/each}
      </div>
    </div>

    {#if errorMsg}
      <div
        class="ic-latex__error-bar"
        class:ic-latex__error-bar--expanded={errorExpanded}
      >
        <span class="ic-latex__error-bar-icon">{@html resolveIcon('triangle-alert', 12)}</span>
        <span class="ic-latex__error-bar-text">{errorMsg}</span>
        <button class="ic-latex__error-bar-toggle" onclick={() => (errorExpanded = !errorExpanded)}>
          {@html errorExpanded ? icons.chevronDown : icons.chevronUp}
        </button>
      </div>
    {/if}

    <!-- Floating controls -->
    {#if toolbarOnHover && !errorMsg}
      <div
        class="ic-latex__controls"
        class:ic-latex__controls--visible={hovered}
      >
        {#if !renderOnChange}
          <button
            class="ic-latex__btn"
            class:ic-latex__btn--active={pendingRender}
            onclick={doRender}
            title="Render"
          >
            {@html icons.refreshCw}
          </button>
          <div class="ic-latex__sep"></div>
        {/if}
        <button
          class="ic-latex__btn"
          onclick={doZoomIn}
          title="Zoom in"
        >
          {@html icons.plus}
        </button>

        <span class="ic-latex__info">{zoomPercent}%</span>

        <button
          class="ic-latex__btn"
          onclick={doZoomOut}
          title="Zoom out"
        >
          {@html icons.minus}
        </button>

        <div class="ic-latex__sep"></div>

        <button
          class="ic-latex__btn"
          onclick={doResetView}
          title="Reset to 100%"
        >
          {@html icons.home}
        </button>

        <button
          class="ic-latex__btn"
          onclick={doFitPage}
          title="Fit page"
        >
          {@html icons.maximize}
        </button>

        <div class="ic-latex__sep"></div>

        <button
          class="ic-latex__btn"
          class:ic-latex__btn--active={exporting}
          onclick={() => doExportPdf('')}
          title="Export PDF"
          disabled={exporting}
        >
          {@html icons.download}
        </button>

        {#if isMultiPage && pageInfos.length > 1}
          <div class="ic-latex__sep"></div>
          <span class="ic-latex__info">{currentPage}/{pageInfos.length}</span>
        {/if}
      </div>
    {/if}
  {/if}
</div>

<style>
  /* ─── Block ──────────────────────────────────────────────────────────── */
  .ic-latex {
    position: relative;
    display: flex;
    flex-direction: column;
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
  }

  .ic-latex--multi {
    background-color: var(--ic-muted);
  }

  /* ─── Viewport (scrollable area) ─────────────────────────────────────── */
  .ic-latex__viewport {
    position: relative;
    flex: 1;
    overflow: auto;
  }
  .ic-latex--multi .ic-latex__viewport {
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  /* ─── Pages container ────────────────────────────────────────────────── */
  .ic-latex__pages {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 12px;
  }
  .ic-latex--multi .ic-latex__pages {
    padding: 16px;
  }

  /* ─── Individual page ────────────────────────────────────────────────── */
  .ic-latex__page {
    position: relative;
    line-height: 0;
  }

  .ic-latex--multi .ic-latex__page {
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
    overflow: clip;
  }

  .ic-latex__canvas {
    display: block;
    width: 100%;
    height: 100%;
  }

  /* ─── Link overlays ────────────────────────────────────────────────── */
  .ic-latex :global(.ic-latex__link-overlay) {
    z-index: 1;
    border-radius: 1px;
  }
  .ic-latex :global(.ic-latex__link-overlay:hover) {
    background-color: rgba(0, 100, 255, 0.04);
    box-shadow: 0 1px 0 0 rgba(0, 100, 255, 0.35);
  }

  /* ─── Floating controls ──────────────────────────────────────────────── */
  .ic-latex__controls {
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
  .ic-latex__controls--visible {
    opacity: 1;
    pointer-events: auto;
  }

  /* ─── Control buttons ────────────────────────────────────────────────── */
  .ic-latex__btn {
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
  .ic-latex__btn:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
    border-color: var(--ic-border);
  }
  .ic-latex__btn:active {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }
  .ic-latex__btn:disabled {
    opacity: 0.5;
    cursor: default;
  }
  .ic-latex__btn--active {
    color: var(--ic-primary);
  }

  /* ─── Info text ──────────────────────────────────────────────────────── */
  .ic-latex__info {
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
  .ic-latex__sep {
    width: 1px;
    height: 16px;
    background-color: var(--ic-border);
    margin: 0 5px;
  }

  /* ─── Status states ──────────────────────────────────────────────────── */
  .ic-latex__status {
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
  .ic-latex__status--error {
    color: var(--ic-destructive, #ef4444);
  }
  .ic-latex__status-text {
    font-size: 12px;
    max-width: 80%;
    text-align: center;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .ic-latex__status-icon {
    line-height: 0;
  }

  /* ─── Error bar ────────────────────────────────────────────────────── */
  .ic-latex__error-bar {
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
  .ic-latex__error-bar-icon {
    flex-shrink: 0;
    line-height: 0;
  }
  .ic-latex__error-bar-text {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ic-latex__error-bar--expanded .ic-latex__error-bar-text {
    white-space: pre-wrap;
    word-break: break-word;
    overflow: visible;
  }
  .ic-latex__error-bar-toggle {
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
  .ic-latex__error-bar-toggle:hover {
    opacity: 1;
    background-color: rgba(255, 255, 255, 0.15);
  }

  /* ─── Spinner ────────────────────────────────────────────────────────── */
  .ic-latex__spinner {
    width: 24px;
    height: 24px;
    border: 2px solid var(--ic-border);
    border-top-color: var(--ic-primary);
    border-radius: 50%;
    animation: ic-latex-spin 0.8s linear infinite;
  }
  @keyframes ic-latex-spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
