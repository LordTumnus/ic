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
  /** Typst universe packages (e.g. ["@preview/cetz:0.3.4"]) */
  packages?: string[];
}

export interface PackageSpec {
  namespace: string;
  name: string;
  version: string;
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

/**
 * Cache of downloaded Typst universe package tar.gz data.
 * Key: "name-version" (e.g. "cetz-0.3.4").
 * Value: raw tar.gz bytes.
 * Persists for page lifetime (packages are immutable/versioned).
 */
const packageCache = new Map<string, Uint8Array>();

/**
 * Specs requested by the compiler during `resolve()` but not found in cache.
 * Populated by the synchronous package fetcher; consumed by the retry loop
 * in Typst.svelte after a failed compilation attempt.
 */
let missingPackages: PackageSpec[] = [];

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

      // Register a custom package registry that serves from our pre-fetched
      // cache. The built-in FetchPackageRegistry uses sync XHR to the CDN,
      // which fails in MATLAB's CEF due to CORS (file:// → https://).
      // Instead, packages are downloaded by MATLAB and cached here before
      // compilation. The fetcher is synchronous (required by the PackageRegistry
      // contract); cache misses are tracked in `missingPackages` for retry.
      const { MemoryAccessModel } = await import(
        '@myriaddreamin/typst.ts/dist/esm/fs/memory.mjs'
      );
      const am = new MemoryAccessModel();

      snippet.use(TypstSnippet.withAccessModel(am));
      snippet.use(
        TypstSnippet.fetchPackageBy(
          am,
          (spec: { namespace: string; name: string; version: string }) => {
            const key = `${spec.name}-${spec.version}`;
            const data = packageCache.get(key);
            if (!data) {
              missingPackages.push({
                namespace: spec.namespace,
                name: spec.name,
                version: spec.version,
              });
              return undefined;
            }
            return data;
          },
        ),
      );

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
    const svg: string = await snippet.svg({ mainContent: preamble + source });
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
  // Parse via HTML parser — typst.ts SVG output can contain constructs
  // that are invalid XML but valid in HTML's more lenient SVG parser.
  const parser = new DOMParser();
  const doc = parser.parseFromString(svgString, 'text/html');
  const svg = doc.querySelector('svg');

  if (!svg) {
    return [svgString];
  }

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
    const bytes = resolved.bytes;
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
// Package Resolution
// ============================================================================

/** Match `#import "@namespace/name:version"` in Typst source. */
const PACKAGE_RE = /#import\s+"@([^/]+)\/([^:]+):([^"]+)"/g;

/**
 * Extract all package specs referenced in Typst source via `#import`.
 * Returns deduplicated specs.
 */
export function extractPackageSpecs(source: string): PackageSpec[] {
  const seen = new Set<string>();
  const specs: PackageSpec[] = [];
  PACKAGE_RE.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = PACKAGE_RE.exec(source)) !== null) {
    const key = `${m[1]}/${m[2]}/${m[3]}`;
    if (seen.has(key)) continue;
    seen.add(key);
    specs.push({ namespace: m[1], name: m[2], version: m[3] });
  }
  return specs;
}

/**
 * Parse manual package strings (e.g. "@preview/cetz:0.3.4") from the
 * Packages property into PackageSpec objects.
 */
export function parseManualPackages(packages: string[]): PackageSpec[] {
  const specs: PackageSpec[] = [];
  for (const p of packages) {
    const m = p.match(/^@([^/]+)\/([^:]+):(.+)$/);
    if (m) specs.push({ namespace: m[1], name: m[2], version: m[3] });
  }
  return specs;
}

/** Check whether a package is already in the pre-fetch cache. */
export function isPackageCached(spec: PackageSpec): boolean {
  return packageCache.has(`${spec.name}-${spec.version}`);
}

/** Store downloaded tar.gz bytes in the pre-fetch cache. */
export function cachePackage(spec: PackageSpec, tarGzBytes: Uint8Array): void {
  const key = `${spec.name}-${spec.version}`;
  packageCache.set(key, tarGzBytes);
  logger.info('Typst', 'Cached package', { key, size: tarGzBytes.length });
}

/**
 * Return and clear the list of packages that the compiler requested
 * during `resolve()` but were not found in cache. Used by the retry
 * loop to fetch missing transitive dependencies.
 */
export function getMissingPackages(): PackageSpec[] {
  const specs = missingPackages;
  missingPackages = [];
  return specs;
}

/**
 * Reset the WASM compiler's internal state.
 *
 * Required before retrying compilation after fetching missing packages.
 * The `snippet.svg()` path intentionally skips `compiler.reset()` for
 * performance (incremental rendering), which means the WASM compiler
 * caches failed package resolutions across calls. Calling this before
 * a retry forces the compiler to re-invoke `PackageRegistry.resolve()`
 * for packages that previously failed.
 */
export async function resetCompiler(): Promise<void> {
  if (snippet) {
    await snippet.getCompilerReset();
  }
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

// Re-export from centralized asset-cache utilities
export { base64ToUint8Array, uint8ArrayToBase64 } from '$lib/utils/asset-cache';
