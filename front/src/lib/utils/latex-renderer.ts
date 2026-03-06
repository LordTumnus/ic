/**
 * LaTeX rendering utility — wraps SwiftLaTeX's PdfTeX WASM engine.
 *
 * Lazy-loads the PdfTeX Worker on first use and provides a compile API
 * that produces PDF bytes. Follows the same singleton pattern as
 * typst-renderer.ts.
 *
 * The engine fetches LaTeX packages on demand from texlive2.swiftlatex.com.
 * If a custom TeX Live endpoint is needed, call `setTexliveEndpoint()` before
 * the first compilation.
 */

import logger from '$lib/core/logger';
import { resolveAsset } from '$lib/utils/asset-cache';
import type { AssetData } from '$lib/utils/asset-cache';

// ============================================================================
// Types
// ============================================================================

export interface LatexCompileResult {
  /** Compiled PDF as raw bytes */
  pdf: Uint8Array;
  /** TeX compilation log */
  log: string;
  ok: true;
}

export interface LatexCompileError {
  /** Human-readable error message */
  message: string;
  /** Full TeX compilation log */
  log: string;
  ok: false;
}

// ============================================================================
// PdfTeX Engine Wrapper (clean TypeScript rewrite of PdfTeXEngine.js)
// ============================================================================

const enum EngineStatus {
  Init = 1,
  Ready = 2,
  Busy = 3,
  Error = 4,
}

interface CompileResult {
  pdf: Uint8Array | undefined;
  status: number;
  log: string;
}

const ENGINE_PATH = './wasm/swiftlatex/swiftlatexpdftex.js';

class PdfTeXEngine {
  private worker: Worker | undefined;
  private status: EngineStatus = EngineStatus.Init;

  async loadEngine(): Promise<void> {
    if (this.worker !== undefined) {
      throw new Error('Engine already loaded');
    }
    this.status = EngineStatus.Init;

    await new Promise<void>((resolve, reject) => {
      this.worker = new Worker(ENGINE_PATH);
      this.worker.onmessage = (ev) => {
        const cmd = ev.data?.result;
        if (cmd === 'ok') {
          this.status = EngineStatus.Ready;
          resolve();
        } else {
          this.status = EngineStatus.Error;
          reject(new Error('PdfTeX engine failed to initialize'));
        }
      };
      this.worker.onerror = (err) => {
        this.status = EngineStatus.Error;
        reject(new Error(`Worker load error: ${err.message}`));
      };
    });

    // Clear handlers after init
    this.worker!.onmessage = () => {};
    this.worker!.onerror = () => {};
  }

  isReady(): boolean {
    return this.status === EngineStatus.Ready;
  }

  private checkReady(): void {
    if (!this.isReady()) {
      throw new Error('Engine is not ready');
    }
  }

  async compileLaTeX(): Promise<CompileResult> {
    this.checkReady();
    this.status = EngineStatus.Busy;

    const result = await new Promise<CompileResult>((resolve) => {
      this.worker!.onmessage = (ev) => {
        const data = ev.data;
        if (data?.cmd !== 'compile') return;

        this.status = EngineStatus.Ready;
        const report: CompileResult = {
          status: data.status ?? -254,
          log: data.log ?? 'No log',
          pdf: data.result === 'ok' ? new Uint8Array(data.pdf) : undefined,
        };
        resolve(report);
      };
      this.worker!.postMessage({ cmd: 'compilelatex' });
    });

    this.worker!.onmessage = () => {};
    return result;
  }

  setEngineMainFile(filename: string): void {
    this.checkReady();
    this.worker?.postMessage({ cmd: 'setmainfile', url: filename });
  }

  writeMemFSFile(filename: string, content: string | Uint8Array): void {
    this.checkReady();
    this.worker?.postMessage({ cmd: 'writefile', url: filename, src: content });
  }

  makeMemFSFolder(folder: string): void {
    this.checkReady();
    if (!folder || folder === '/') return;
    this.worker?.postMessage({ cmd: 'mkdir', url: folder });
  }

  flushCache(): void {
    this.checkReady();
    this.worker?.postMessage({ cmd: 'flushcache' });
  }

  setTexliveEndpoint(url: string): void {
    // Note: original SwiftLaTeX had a bug here (set worker=undefined).
    // We preserve the worker reference so compilation still works after.
    this.worker?.postMessage({ cmd: 'settexliveurl', url });
  }

  /**
   * Send text + font bundles to the Worker in one message.
   * The Worker stores them and kpse_find_file_impl writes files
   * on-demand when kpathsea requests them (lazy loading).
   */
  async loadBundle(
    textBundle: Record<string, string>,
    fontBundle: Record<string, string>,
  ): Promise<void> {
    this.checkReady();
    return new Promise<void>((resolve) => {
      this.worker!.onmessage = (ev) => {
        if (ev.data?.cmd === 'loadbundle') {
          this.worker!.onmessage = () => {};
          resolve();
        }
      };
      this.worker!.postMessage({ cmd: 'loadbundle', text: textBundle, fonts: fontBundle });
    });
  }

  closeWorker(): void {
    this.worker?.postMessage({ cmd: 'grace' });
    this.worker = undefined;
  }
}

// ============================================================================
// State (lazy singleton)
// ============================================================================

let engine: PdfTeXEngine | null = null;
let initPromise: Promise<void> | null = null;

/**
 * Maps original image path → shadow filename (for source rewriting).
 * null value means the path was mapped directly (no rewrite needed).
 */
const imageMap = new Map<string, string | null>();

// ============================================================================
// Initialization
// ============================================================================

/** Bundled TeX Live packages (.sty, .cls, etc.) as JSON: { filename: content } */
const TEXLIVE_BUNDLE_PATH = './wasm/swiftlatex/texlive-bundle.json';

/** Bundled font files (.tfm, .pfb, .map) as JSON: { filename: base64 } */
const TEXLIVE_FONTS_PATH = './wasm/swiftlatex/texlive-fonts.json';

/** Pre-compiled LaTeX format file (the LaTeX kernel in binary form). */
const FORMAT_FILE_PATH = './wasm/swiftlatex/swiftlatexpdftex.fmt.bin';

/**
 * Lazy-load the PdfTeX WASM engine on first use.
 *
 * After the Worker initializes, we:
 * 1. Write the LaTeX format file directly to MemFS (it's always needed)
 * 2. Send text + font bundles to the Worker in ONE message — the patched
 *    kpse_find_file_impl writes them to MemFS on-demand when kpathsea
 *    requests a file. This avoids 1300+ individual postMessage calls.
 */
async function ensureEngine(): Promise<void> {
  if (engine?.isReady()) return;
  if (!initPromise) {
    initPromise = (async () => {
      try {
        logger.info('LaTeX', 'Starting PdfTeX WASM initialization...');
        engine = new PdfTeXEngine();
        await engine.loadEngine();
        logger.info('LaTeX', 'PdfTeX engine ready — loading bundles...');

        // Fetch all three bundles in parallel
        const [fmtResp, texResp, fontResp] = await Promise.all([
          fetch(FORMAT_FILE_PATH),
          fetch(TEXLIVE_BUNDLE_PATH),
          fetch(TEXLIVE_FONTS_PATH),
        ]);

        // Write format file directly (always needed, ~10MB)
        if (fmtResp.ok) {
          const bytes = new Uint8Array(await fmtResp.arrayBuffer());
          engine!.writeMemFSFile('swiftlatexpdftex.fmt', bytes);
          logger.info('LaTeX', 'Format file loaded', { size: bytes.length });
        }

        // Send text + font bundles to Worker in ONE message for lazy loading
        const textBundle = texResp.ok ? await texResp.json() : {};
        const fontBundle = fontResp.ok ? await fontResp.json() : {};
        await engine!.loadBundle(textBundle, fontBundle);

        const textCount = Object.keys(textBundle).length;
        const fontCount = Object.keys(fontBundle).length;
        logger.info('LaTeX', `Bundles registered: ${textCount} text + ${fontCount} font files (lazy)`);
      } catch (err) {
        // Reset singleton so next call retries instead of re-throwing forever
        engine = null;
        initPromise = null;
        throw err;
      }
    })();
  }
  await initPromise;
}

// ============================================================================
// Compilation
// ============================================================================

/**
 * Inject pdftex driver declarations before \documentclass.
 *
 * SwiftLaTeX's patched kpathsea can't reliably find color.cfg / graphics.cfg
 * in the MemFS, so we force the pdftex driver via \PassOptionsToPackage.
 * These are harmless no-ops if the packages aren't loaded.
 */
function injectPreamble(source: string): string {
  const preamble =
    '\\PassOptionsToPackage{pdftex}{color}\n' +
    '\\PassOptionsToPackage{pdftex}{xcolor}\n' +
    '\\PassOptionsToPackage{pdftex}{graphics}\n' +
    '\\PassOptionsToPackage{pdftex}{graphicx}\n';

  // Insert before \documentclass (must come first in a LaTeX document)
  const dcIdx = source.indexOf('\\documentclass');
  if (dcIdx >= 0) {
    return source.slice(0, dcIdx) + preamble + source.slice(dcIdx);
  }
  // No \documentclass found — prepend anyway
  return preamble + source;
}

/**
 * Compile LaTeX source to PDF bytes.
 *
 * Lazy-loads the WASM engine on first call. Returns PDF bytes on success
 * or an error message with the TeX log on failure.
 */
export async function compileLaTeX(
  source: string,
): Promise<LatexCompileResult | LatexCompileError> {
  if (!source.trim()) {
    return { message: 'Empty LaTeX source', log: '', ok: false };
  }

  try {
    await ensureEngine();

    engine!.writeMemFSFile('main.tex', injectPreamble(source));
    engine!.setEngineMainFile('main.tex');

    const result = await engine!.compileLaTeX();

    if (result.status !== 0 || !result.pdf || result.pdf.length === 0) {
      logger.warn('LaTeX', 'TeX compilation log', { status: result.status, log: result.log });
      const message = parseLatexErrors(result.log);
      return { message, log: result.log, ok: false };
    }

    return { pdf: result.pdf, log: result.log, ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { message, log: '', ok: false };
  }
}

// ============================================================================
// Error Parsing
// ============================================================================

/**
 * Extract human-readable error lines from a TeX compilation log.
 *
 * TeX errors start with `! ` (e.g. `! Undefined control sequence.`).
 * We also include the line immediately following for context.
 */
function parseLatexErrors(log: string): string {
  const lines = log.split('\n');
  const errors: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('! ')) {
      errors.push(lines[i].slice(2));
      // Include next line for context (usually shows the offending input)
      if (i + 1 < lines.length && lines[i + 1].startsWith('l.')) {
        errors.push('  ' + lines[i + 1]);
      }
    }
  }

  return errors.length > 0 ? errors.join('\n') : 'Compilation failed (check log)';
}

// ============================================================================
// Image Resolution
// ============================================================================

/** Match \includegraphics[options]{path} in LaTeX source. */
const INCLUDEGRAPHICS_RE = /\\includegraphics\s*(?:\[[^\]]*\])?\s*\{([^}]+)\}/g;

/**
 * Extract all image paths from \includegraphics commands in LaTeX source.
 */
export function extractImagePaths(source: string): string[] {
  const paths: string[] = [];
  INCLUDEGRAPHICS_RE.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = INCLUDEGRAPHICS_RE.exec(source)) !== null) {
    paths.push(m[1]);
  }
  return paths;
}

/** Check whether a path has already been mapped into the engine's MemFS. */
export function isShadowMapped(path: string): boolean {
  return imageMap.has(path);
}

/** Get path-rewrite map for cached paths that need rewriting. */
export function getShadowRewrites(paths: string[]): Record<string, string> {
  const rewrites: Record<string, string> = {};
  for (const p of paths) {
    const r = imageMap.get(p);
    if (r) rewrites[p] = r;
  }
  return rewrites;
}

/**
 * Map resolved images into the PdfTeX engine's MemFS and return a
 * path-rewrite map for source substitution.
 *
 * URLs and absolute paths are mapped to `_img_{hash}.{ext}` in the working
 * directory. Simple relative paths are mapped directly by name.
 */
export async function mapImagesToShadow(
  paths: string[],
  assets: AssetData[],
): Promise<Record<string, string>> {
  await ensureEngine();
  const rewrites: Record<string, string> = {};

  for (let i = 0; i < paths.length; i++) {
    const path = paths[i];
    const asset = assets[i];
    if (!path || !asset) continue;

    // Already mapped
    if (imageMap.has(path)) {
      const existing = imageMap.get(path);
      if (existing) rewrites[path] = existing;
      continue;
    }

    const resolved = resolveAsset(asset);
    if (!resolved) continue;

    const bytes = base64ToUint8Array(resolved.data);
    const ext = path.match(/\.(\w+)(?:[?#].*)?$/)?.[1] ?? 'png';

    // Simple relative path → write with original name
    const isRelative = !path.includes('://') && !path.startsWith('/');
    const shadowName = isRelative ? path : `_img_${asset.hash}.${ext}`;

    engine!.writeMemFSFile(shadowName, bytes);

    if (!isRelative) {
      rewrites[path] = shadowName;
      imageMap.set(path, shadowName);
    } else {
      imageMap.set(path, null);
    }

    logger.info('LaTeX', 'Mapped image to MemFS', { shadowName, size: bytes.length });
  }

  return rewrites;
}

// ============================================================================
// Helpers
// ============================================================================

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
export function uint8ArrayToBase64(bytes: Uint8Array): string {
  const chunkSize = 8192;
  let binary = '';
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}
