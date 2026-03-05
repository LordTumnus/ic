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
import { resolveAsset } from '$lib/utils/asset-cache';
import type { AssetData } from '$lib/utils/asset-cache';

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

/**
 * Single map tracking all images mapped into the WASM shadow filesystem.
 * Key: original path as written in `#image("...")`.
 * Value: shadow filename for source rewriting, or `null` for relative
 *        paths that don't need rewriting (mapped directly under /tmp/).
 */
const shadowMap = new Map<string, string | null>();

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
// Error Formatting
// ============================================================================

/**
 * Parse Typst's Rust-debug `SourceDiagnostic` array into human-readable lines.
 *
 * Input looks like:
 *   [SourceDiagnostic { severity: Error, span: Span(...), message: "...", trace: [], hints: ["..."] }, ...]
 *
 * Output:
 *   error: failed to load file (access denied)
 *     hint: cannot read file outside of project root
 *   warning: `diff` is deprecated, use `partial` instead
 */
function formatTypstError(raw: string): string {
  const diagRe = /SourceDiagnostic\s*\{[^}]*severity:\s*(\w+)[^}]*message:\s*"([^"]*)"[^}]*\}/g;
  const parts: string[] = [];
  let match: RegExpExecArray | null;

  while ((match = diagRe.exec(raw)) !== null) {
    if (match[1].toLowerCase() === 'warning') continue; // skip warnings
    parts.push(match[2]);
  }

  return parts.length > 0 ? parts.join('\n') : raw;
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
    const raw = err instanceof Error ? err.message : String(err);
    const stack = err instanceof Error ? err.stack : undefined;
    logger.error('Typst', 'Render failed', { message: raw, stack });
    return { message: formatTypstError(raw), ok: false };
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

  // Also try nested: some typst.ts versions wrap pages in a container <g>
  if (pageGroups.length === 0) {
    pageGroups = svg.querySelectorAll('g[data-page-width]');
  }

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
// Image Resolution
// ============================================================================

/** Match `#image("path")` or bare `image("path")` calls in Typst source. */
const IMAGE_RE = /#?image\s*\(\s*"([^"]+)"/g;

/**
 * Extract all image paths referenced in Typst source.
 *
 * Finds `#image("...")` calls and returns the raw paths as written.
 * Does not deduplicate — callers should filter with `isShadowMapped`.
 */
export function extractImagePaths(source: string): string[] {
  const paths: string[] = [];
  let m: RegExpExecArray | null;
  // Reset lastIndex since the regex is global (reused across calls)
  IMAGE_RE.lastIndex = 0;
  while ((m = IMAGE_RE.exec(source)) !== null) {
    paths.push(m[1]);
  }
  return paths;
}

/** Check whether a path has already been mapped into the WASM shadow filesystem. */
export function isShadowMapped(path: string): boolean {
  return shadowMap.has(path);
}

/** Get the source-rewrite map for all currently cached paths that need rewriting. */
export function getShadowRewrites(paths: string[]): Record<string, string> {
  const rewrites: Record<string, string> = {};
  for (const p of paths) {
    const r = shadowMap.get(p);
    if (r) rewrites[p] = r; // null entries (relative paths) are skipped
  }
  return rewrites;
}

/**
 * Map resolved images into the WASM compiler's shadow filesystem and
 * return a path-rewrite map for source substitution.
 *
 * Typst's project root is `/tmp/` (where the snippet places the main
 * `.typ` file). URLs and absolute paths would be rejected as "outside
 * project root", so we map them under `/tmp/_img_{hash}.{ext}` and
 * rewrite the source to use these sanitized paths before compilation.
 *
 * Returns `Record<originalPath, shadowFilename>` for paths that need
 * rewriting. Simple relative paths (e.g. `photo.png`) map directly
 * and don't need rewriting.
 */
export async function mapImagesToShadow(
  paths: string[],
  assets: AssetData[],
): Promise<Record<string, string>> {
  await ensureConfigured();
  const rewrites: Record<string, string> = {};

  for (let i = 0; i < paths.length; i++) {
    const path = paths[i];
    const asset = assets[i];
    if (!path || !asset) continue;

    // Already mapped — return existing rewrite if applicable
    if (shadowMap.has(path)) {
      const existing = shadowMap.get(path);
      if (existing) rewrites[path] = existing;
      continue;
    }

    // Resolve through asset-cache (caches by hash, dedup with other components)
    const resolved = resolveAsset(asset);
    if (!resolved) continue;

    const shadowPath = toShadowPath(path, asset.hash);
    const bytes = base64ToUint8Array(resolved.data);
    await snippet.mapShadow(shadowPath, bytes);

    // Track in unified map: shadow filename for URLs/absolute, null for relative
    const needsRewrite = path !== shadowPath.replace('/tmp/', '');
    if (needsRewrite) {
      const filename = shadowPath.slice('/tmp/'.length);
      rewrites[path] = filename;
      shadowMap.set(path, filename);
    } else {
      shadowMap.set(path, null);
    }

    logger.info('Typst', 'Mapped shadow image', { path: shadowPath, size: bytes.length });
  }

  return rewrites;
}

// ============================================================================
// Helpers
// ============================================================================

/**
 * Convert an image path to a safe shadow filesystem path under `/tmp/`.
 *
 * Typst's project root is `/tmp/` (where the main `.typ` lives). Paths
 * containing `://` or starting with `/` would be rejected as "outside
 * project root". We flatten those using the asset hash + original extension.
 * Simple relative paths (e.g. `photo.png`) map directly to `/tmp/photo.png`.
 */
function toShadowPath(originalPath: string, hash: string): string {
  // Simple relative path — map directly under /tmp/
  if (!originalPath.includes('://') && !originalPath.startsWith('/')) {
    return `/tmp/${originalPath}`;
  }
  // URL or absolute path — use hash + extension to stay under project root
  const ext = originalPath.match(/\.(\w+)(?:[?#].*)?$/)?.[1] ?? 'bin';
  return `/tmp/_img_${hash}.${ext}`;
}

/** Decode a base64 string to Uint8Array. */
function base64ToUint8Array(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

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
