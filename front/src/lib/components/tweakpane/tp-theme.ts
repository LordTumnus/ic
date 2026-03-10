/**
 * Tweakpane IC Theme Mapper
 *
 * Tweakpane is inherently a dark/dense instrument-panel UI. Rather than
 * mapping IC colors 1:1 (which looks washed-out in light mode), we always
 * use IC's dark-mode palette for the pane — matching the "Industrial Flat"
 * design language (mixing consoles, oscilloscopes, lab instruments).
 */

export function applyIcTheme(container: HTMLElement): void {
  // Read the IC color scheme to pick the right accent colors
  const cs = getComputedStyle(container);
  const primary = cs.getPropertyValue('--ic-primary').trim() || '#3b82f6';
  const primaryFg = cs.getPropertyValue('--ic-primary-foreground').trim() || '#ffffff';

  // Dark instrument-panel palette (slate family, matches IC dark mode)
  const base = '#1e293b';       // slate-800 — main background
  const containerBg = '#273548'; // slightly lighter — container rows
  const inputBg = '#334155';    // slate-700 — input fields
  const inputBgHover = '#3e4f66';
  const fg = '#f1f5f9';         // slate-100 — primary text
  const labelFg = '#94a3b8';    // slate-400 — label text
  const monitorBg = '#1a2332';  // darker than base — recessed monitors

  const map: Record<string, string> = {
    '--tp-base-background-color': base,
    '--tp-base-shadow-color': 'rgba(0,0,0,0.4)',
    '--tp-button-background-color': primary,
    '--tp-button-background-color-active': primary,
    '--tp-button-background-color-focus': primary,
    '--tp-button-background-color-hover': primary,
    '--tp-button-foreground-color': primaryFg,
    '--tp-container-background-color': containerBg,
    '--tp-container-background-color-active': inputBg,
    '--tp-container-background-color-focus': inputBg,
    '--tp-container-background-color-hover': inputBg,
    '--tp-container-foreground-color': fg,
    '--tp-groove-foreground-color': primary,
    '--tp-input-background-color': inputBg,
    '--tp-input-background-color-active': inputBgHover,
    '--tp-input-background-color-focus': inputBgHover,
    '--tp-input-background-color-hover': inputBgHover,
    '--tp-input-foreground-color': fg,
    '--tp-label-foreground-color': labelFg,
    '--tp-monitor-background-color': monitorBg,
    '--tp-monitor-foreground-color': fg,
  };

  for (const [k, v] of Object.entries(map)) {
    container.style.setProperty(k, v);
  }

  // Industrial Flat — sharp corners, no rounding
  container.style.setProperty('--tp-base-border-radius', '2px');
  container.style.setProperty('--tp-blade-border-radius', '2px');
}
