/**
 * Shared Mermaid rendering utility.
 *
 * Lazy-loads mermaid.js on first use and provides a simple render API
 * for both the standalone ic.Mermaid component and the Markdown plugin.
 *
 * Theming uses Mermaid's `base` theme with `themeVariables` derived from
 * `--ic-mermaid-*` CSS custom properties. These default to IC theme vars
 * (`--ic-primary`, `--ic-background`, etc.) so diagrams match the UI
 * automatically, but can be overridden per-instance via the `style()` API.
 */

import type { MermaidConfig } from 'mermaid';

// ============================================================================
// Types
// ============================================================================

export interface RenderResult {
  /** Rendered SVG markup */
  svg: string;
  /** Whether rendering succeeded */
  ok: true;
}

export interface RenderError {
  /** Error message */
  message: string;
  ok: false;
}

/** Options passed from ic.Mermaid props into the renderer. */
export interface RenderOptions {
  htmlLabels?: boolean;
  wrap?: boolean;
  darkMode?: boolean;
  /** Diagram-specific config (flowchart, sequence, gantt, etc.) */
  config?: Record<string, unknown>;
}

// ============================================================================
// CSS var → Mermaid themeVariable mapping
// ============================================================================

/**
 * CSS var → Mermaid themeVariable mapping.
 *
 * The first 4 ("root") vars have CSS fallbacks to IC theme variables in
 * Mermaid.svelte, so they always resolve. Mermaid's `base` theme derives
 * all other colors (borders, contrast text, fills, etc.) from these roots.
 *
 * The remaining vars have **no defaults** — they are only passed to Mermaid
 * when explicitly set via the IC `style()` API, letting users override
 * specific diagram elements without affecting the overall theme:
 *
 *   m.style(".ic-mermaid", "--ic-mermaid-note-bkg", "#fef3c7")
 */
const VAR_MAP: [cssVar: string, mermaidKey: string][] = [
  // ── Roots (always set via CSS fallbacks) ──────────────────────────
  ['--ic-mermaid-primary',           'primaryColor'],
  ['--ic-mermaid-background',        'mainBkg'],
  ['--ic-mermaid-text',              'textColor'],
  ['--ic-mermaid-line',              'lineColor'],

  // ── General (opt-in overrides) ────────────────────────────────────
  ['--ic-mermaid-primary-text',      'primaryTextColor'],
  ['--ic-mermaid-primary-border',    'primaryBorderColor'],
  ['--ic-mermaid-secondary',         'secondaryColor'],
  ['--ic-mermaid-secondary-text',    'secondaryTextColor'],
  ['--ic-mermaid-secondary-border',  'secondaryBorderColor'],
  ['--ic-mermaid-tertiary',          'tertiaryColor'],
  ['--ic-mermaid-tertiary-text',     'tertiaryTextColor'],
  ['--ic-mermaid-tertiary-border',   'tertiaryBorderColor'],

  // ── Notes ─────────────────────────────────────────────────────────
  ['--ic-mermaid-note-bkg',          'noteBkgColor'],
  ['--ic-mermaid-note-text',         'noteTextColor'],
  ['--ic-mermaid-note-border',       'noteBorderColor'],

  // ── Flowchart ─────────────────────────────────────────────────────
  ['--ic-mermaid-node-border',       'nodeBorder'],
  ['--ic-mermaid-cluster-bkg',       'clusterBkg'],
  ['--ic-mermaid-cluster-border',    'clusterBorder'],
  ['--ic-mermaid-link-color',        'defaultLinkColor'],
  ['--ic-mermaid-edge-label-bkg',    'edgeLabelBackground'],

  // ── Sequence diagrams ─────────────────────────────────────────────
  ['--ic-mermaid-actor-bkg',         'actorBkg'],
  ['--ic-mermaid-actor-text',        'actorTextColor'],
  ['--ic-mermaid-actor-border',      'actorBorder'],
  ['--ic-mermaid-actor-line',        'actorLineColor'],
  ['--ic-mermaid-signal-color',      'signalColor'],
  ['--ic-mermaid-signal-text',       'signalTextColor'],
  ['--ic-mermaid-activation-bkg',    'activationBkgColor'],
  ['--ic-mermaid-activation-border', 'activationBorderColor'],

  // ── Gantt charts ──────────────────────────────────────────────────
  ['--ic-mermaid-section-bkg',       'sectionBkgColor'],
  ['--ic-mermaid-section-bkg-2',     'sectionBkgColor2'],
  ['--ic-mermaid-grid-color',        'gridColor'],
  ['--ic-mermaid-task-bkg',          'taskBkgColor'],
  ['--ic-mermaid-task-text',         'taskTextColor'],
  ['--ic-mermaid-task-border',       'taskBorderColor'],
  ['--ic-mermaid-done-task-bkg',     'doneTaskBkgColor'],
  ['--ic-mermaid-done-task-border',  'doneTaskBorderColor'],
  ['--ic-mermaid-crit-bkg',          'critBkgColor'],
  ['--ic-mermaid-crit-border',       'critBorderColor'],
  ['--ic-mermaid-active-task-bkg',   'activeTaskBkgColor'],
  ['--ic-mermaid-active-task-border','activeTaskBorderColor'],
  ['--ic-mermaid-today-line',        'todayLineColor'],
];

/** Read resolved CSS vars from an element and build themeVariables. */
function readThemeVars(element: HTMLElement): Record<string, string> {
  const style = getComputedStyle(element);
  const vars: Record<string, string> = {};
  for (const [cssVar, mermaidKey] of VAR_MAP) {
    const val = style.getPropertyValue(cssVar).trim();
    if (val) vars[mermaidKey] = val;
  }
  return vars;
}

// ============================================================================
// State
// ============================================================================

let mermaidModule: typeof import('mermaid') | null = null;
let initPromise: Promise<void> | null = null;
let renderCounter = 0;

// ============================================================================
// Rendering
// ============================================================================

/**
 * Render a Mermaid diagram definition to SVG.
 *
 * Lazy-loads the mermaid library on first call. Reads `--ic-mermaid-*`
 * CSS vars from `element` to configure the base theme. Returns either
 * the SVG markup or an error message for invalid definitions.
 */
export async function renderMermaid(
  definition: string,
  element?: HTMLElement,
  options?: RenderOptions,
): Promise<RenderResult | RenderError> {
  if (!definition.trim()) {
    return { message: 'Empty diagram definition', ok: false };
  }

  try {
    const el = element ?? document.documentElement;
    await ensureLoaded(el, options);
    const id = `ic-mermaid-${++renderCounter}`;
    const { svg } = await mermaidModule!.default.render(id, definition.trim());
    return { svg, ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    // Clean up any orphaned render containers mermaid may have left
    const orphan = document.getElementById(`dic-mermaid-${renderCounter}`);
    orphan?.remove();
    return { message, ok: false };
  }
}

// ============================================================================
// Initialization
// ============================================================================

/**
 * Lazy-load mermaid and (re-)initialize with the current IC theme vars.
 *
 * Re-initializes on every render because CSS vars may have changed
 * (e.g. user called style() or IC theme switched light/dark).
 */
async function ensureLoaded(element: HTMLElement, options?: RenderOptions): Promise<void> {
  if (!mermaidModule) {
    if (!initPromise) {
      initPromise = (async () => {
        mermaidModule = await import('mermaid');
      })();
    }
    await initPromise;
  }

  const themeVariables = readThemeVars(element);

  const config: MermaidConfig = {
    startOnLoad: false,
    fontFamily: 'inherit',
    // User-configurable options (defaults match Mermaid's own defaults)
    htmlLabels: options?.htmlLabels ?? true,
    wrap: options?.wrap ?? true,
    darkMode: options?.darkMode ?? false,
    // Diagram-specific overrides (flowchart, sequence, gantt, etc.)
    ...options?.config,
    // Locked values — cannot be overridden by user config
    theme: 'base' as MermaidConfig['theme'],
    themeVariables,
    securityLevel: 'strict',
  };
  mermaidModule!.default.initialize(config);
}
