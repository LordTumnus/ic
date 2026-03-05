/**
 * Shared Typst rendering utility.
 *
 * Lazy-loads the Typst WASM compiler/renderer on first use and provides
 * render APIs for both SVG (display) and PDF (export).
 *
 * Follows the same pattern as mermaid-renderer.ts: module-level lazy
 * singleton, async render function, typed result/error types.
 */

import logger from '$lib/core/logger';

// ============================================================================
// Types
// ============================================================================

export interface TypstRenderResult {
  /** Array of SVG strings, one per page */
  pages: string[];
  ok: true;
}

export interface TypstPdfResult {
  /** Base64-encoded PDF bytes */
  base64: string;
  ok: true;
}

export interface TypstRenderError {
  /** Error message */
  message: string;
  ok: false;
}

export interface TypstRenderOptions {
  /** Typst page width (e.g. "210mm", "auto") */
  pageWidth?: string;
  /** Typst page height (e.g. "297mm", "auto") */
  pageHeight?: string;
  /** Page margin (e.g. "1cm", "(x: 1cm, y: 2cm)") */
  pageMargin?: string;
  /** Base font size (e.g. "11pt") */
  fontSize?: string;
  /** Font family name */
  fontFamily?: string;
  /** Reserved for future Typst universe packages */
  packages?: string[];
}

// ============================================================================
// State
// ============================================================================

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- lazy-loaded; strict typing not worth the complexity
let snippet: any = null;
let configPromise: Promise<void> | null = null;

// ============================================================================
// Initialization
// ============================================================================

/**
 * Lazy-load and configure the Typst WASM compiler/renderer.
 *
 * Called before every render to ensure WASM is ready. The first call
 * triggers the full download (~28MB compiler WASM + ~1MB renderer WASM)
 * and loads all bundled fonts from public/fonts/typst/.
 * Subsequent calls resolve immediately.
 */
async function ensureConfigured(): Promise<void> {
  if (snippet) return;
  if (!configPromise) {
    configPromise = (async () => {
      logger.info('Typst', 'Starting WASM initialization...');

      const [mod, snippetMod, compilerWasmUrl, rendererWasmUrl] =
        await Promise.all([
          import('@myriaddreamin/typst.ts'),
          import('@myriaddreamin/typst.ts/contrib/snippet'),
          import(
            '@myriaddreamin/typst-ts-web-compiler/pkg/typst_ts_web_compiler_bg.wasm?url'
          ),
          import(
            '@myriaddreamin/typst-ts-renderer/pkg/typst_ts_renderer_bg.wasm?url'
          ),
        ]);

      snippet = mod.$typst;
      const TypstSnippet = snippetMod.TypstSnippet;

      // Load all bundled font categories (text, CJK, emoji) from local
      // assets instead of CDN. The library already knows all filenames —
      // we just redirect the base URL to our public/fonts/typst/ directory.
      snippet.use(TypstSnippet.preloadFontAssets({
        assets: ['text', 'cjk', 'emoji'],
        assetUrlPrefix: './fonts/typst/',
      }));

      snippet.setCompilerInitOptions({
        getModule: () => compilerWasmUrl.default,
      });
      snippet.setRendererInitOptions({
        getModule: () => rendererWasmUrl.default,
      });

      logger.info('Typst', 'Init options set — ready for first render');
    })();
  }
  await configPromise;
}

// ============================================================================
// Preamble
// ============================================================================

/**
 * Build Typst `#set` preamble from render options.
 *
 * Empty/undefined values are skipped — Typst uses its own defaults.
 */
function buildPreamble(options?: TypstRenderOptions): string {
  if (!options) return '';
  const lines: string[] = [];

  const pageArgs: string[] = [];
  if (options.pageWidth) pageArgs.push(`width: ${options.pageWidth}`);
  if (options.pageHeight) pageArgs.push(`height: ${options.pageHeight}`);
  if (options.pageMargin) pageArgs.push(`margin: ${options.pageMargin}`);
  if (pageArgs.length > 0) {
    lines.push(`#set page(${pageArgs.join(', ')})`);
  }

  const textArgs: string[] = [];
  if (options.fontSize) textArgs.push(`size: ${options.fontSize}`);
  if (options.fontFamily) textArgs.push(`font: "${options.fontFamily}"`);
  if (textArgs.length > 0) {
    lines.push(`#set text(${textArgs.join(', ')})`);
  }

  return lines.length > 0 ? lines.join('\n') + '\n' : '';
}

// ============================================================================
// Rendering
// ============================================================================

/**
 * Compile Typst source to SVG pages.
 *
 * Lazy-loads the WASM compiler on first call. Returns an array of SVG
 * strings (one per page) on success, or an error message on failure.
 */
export async function renderTypst(
  source: string,
  options?: TypstRenderOptions,
): Promise<TypstRenderResult | TypstRenderError> {
  if (!source.trim()) {
    return { message: 'Empty Typst source', ok: false };
  }

  try {
    await ensureConfigured();
    const preamble = buildPreamble(options);
    logger.info('Typst', 'Calling snippet.svg()', { preambleLength: preamble.length, sourceLength: source.length });
    const svg: string = await snippet.svg({ mainContent: preamble + source });
    logger.info('Typst', 'SVG rendered', { svgLength: svg?.length ?? 0 });
    const pages = extractPages(svg);
    return { pages, ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const stack = err instanceof Error ? err.stack : undefined;
    logger.error('Typst', 'Render failed', { message, stack });
    return { message, ok: false };
  }
}

/**
 * Compile Typst source to PDF and return as base64.
 *
 * Uses the same lazy-loaded WASM compiler. PDF generation only needs
 * the compiler (not the renderer), but we initialize both for consistency.
 */
export async function renderTypstPdf(
  source: string,
  options?: TypstRenderOptions,
): Promise<TypstPdfResult | TypstRenderError> {
  if (!source.trim()) {
    return { message: 'Empty Typst source', ok: false };
  }

  try {
    await ensureConfigured();
    const preamble = buildPreamble(options);
    const pdfBytes: Uint8Array = await snippet.pdf({
      mainContent: preamble + source,
    });
    const base64 = uint8ArrayToBase64(pdfBytes);
    return { base64, ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { message, ok: false };
  }
}

// ============================================================================
// Page Extraction
// ============================================================================

/**
 * Split a multi-page SVG into individual page SVGs.
 *
 * typst.ts renders all pages into a single SVG with each page as a
 * top-level `<g>` group. This function extracts each into a standalone
 * SVG element preserving shared `<defs>` and `<style>` resources.
 *
 * Falls back to returning the full SVG as a single page if no page
 * groups are detected.
 */
function extractPages(svgString: string): string[] {
  const parser = new DOMParser();
  const doc = parser.parseFromString(svgString, 'image/svg+xml');
  const svg = doc.documentElement;

  // Find page groups — typst.ts uses data-page-width on page <g> elements
  let pageGroups = svg.querySelectorAll(':scope > g[data-page-width]');
  if (pageGroups.length === 0) {
    // Fallback: direct child <g> elements (skip <defs>, <style>, etc.)
    pageGroups = svg.querySelectorAll(':scope > g');
  }

  if (pageGroups.length <= 1) {
    // Single page — return the whole SVG as-is
    return [svgString];
  }

  // Collect shared resources (defs, styles)
  const defs = svg.querySelector('defs');
  const styles = svg.querySelectorAll('style');
  const serializer = new XMLSerializer();
  const pages: string[] = [];

  for (const group of pageGroups) {
    const pageWidth = group.getAttribute('data-page-width') || '595.28';
    const pageHeight = group.getAttribute('data-page-height') || '841.89';

    const pageSvg = document.createElementNS(
      'http://www.w3.org/2000/svg',
      'svg',
    );
    pageSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    pageSvg.setAttribute('viewBox', `0 0 ${pageWidth} ${pageHeight}`);
    pageSvg.setAttribute('width', '100%');
    pageSvg.setAttribute('height', 'auto');

    // Clone shared resources into each page SVG
    if (defs) pageSvg.appendChild(defs.cloneNode(true));
    for (const style of styles) pageSvg.appendChild(style.cloneNode(true));

    // Clone page content and reset transform to origin
    const clonedGroup = group.cloneNode(true) as SVGGElement;
    clonedGroup.setAttribute('transform', 'translate(0, 0)');
    pageSvg.appendChild(clonedGroup);

    pages.push(serializer.serializeToString(pageSvg));
  }

  return pages;
}

// ============================================================================
// Helpers
// ============================================================================

/** Convert Uint8Array to base64 string (chunked to avoid stack overflow). */
function uint8ArrayToBase64(bytes: Uint8Array): string {
  const chunkSize = 8192;
  let binary = '';
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}
