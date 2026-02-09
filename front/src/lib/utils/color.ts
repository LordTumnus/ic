/**
 * Color conversion utilities for the ColorPicker component.
 *
 * All conversions go through HSL+A as the canonical internal representation,
 * since the hue slider maps directly to H (0-360) and alpha to A (0-1).
 */

// ============================================================================
// Types
// ============================================================================

export interface HSLA {
  h: number; // 0-360
  s: number; // 0-100
  l: number; // 0-100
  a: number; // 0-1
}

// ============================================================================
// Parsing
// ============================================================================

/**
 * Parse any supported CSS color string into HSLA components.
 * Supports: #RGB, #RRGGBB, #RRGGBBAA, rgb(), rgba(), hsl(), hsla().
 * Returns black on parse failure.
 */
export function parseColor(str: string): HSLA {
  const s = str.trim().toLowerCase();

  // Hex formats
  if (s.startsWith('#')) {
    const { r, g, b, a } = hexToRgb(s);
    const hsl = rgbToHsl(r, g, b);
    return { ...hsl, a };
  }

  // rgba(r, g, b, a)
  const rgbaMatch = s.match(
    /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+))?\s*\)$/
  );
  if (rgbaMatch) {
    const r = clamp(parseFloat(rgbaMatch[1]), 0, 255);
    const g = clamp(parseFloat(rgbaMatch[2]), 0, 255);
    const b = clamp(parseFloat(rgbaMatch[3]), 0, 255);
    const a = rgbaMatch[4] !== undefined ? clamp(parseFloat(rgbaMatch[4]), 0, 1) : 1;
    const hsl = rgbToHsl(r, g, b);
    return { ...hsl, a };
  }

  // hsla(h, s%, l%, a) or hsl(h, s%, l%)
  const hslaMatch = s.match(
    /^hsla?\(\s*([\d.]+)\s*,\s*([\d.]+)%?\s*,\s*([\d.]+)%?\s*(?:,\s*([\d.]+))?\s*\)$/
  );
  if (hslaMatch) {
    return {
      h: ((parseFloat(hslaMatch[1]) % 360) + 360) % 360,
      s: clamp(parseFloat(hslaMatch[2]), 0, 100),
      l: clamp(parseFloat(hslaMatch[3]), 0, 100),
      a: hslaMatch[4] !== undefined ? clamp(parseFloat(hslaMatch[4]), 0, 1) : 1,
    };
  }

  // Fallback: black
  return { h: 0, s: 0, l: 0, a: 1 };
}

// ============================================================================
// Hex ↔ RGB
// ============================================================================

/** Parse hex string (#RGB, #RRGGBB, #RRGGBBAA) to RGB+A (0-255 / 0-1). */
export function hexToRgb(hex: string): { r: number; g: number; b: number; a: number } {
  let h = hex.replace('#', '');

  // #RGB → #RRGGBB
  if (h.length === 3) {
    h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
  }
  // #RGBA → #RRGGBBAA
  if (h.length === 4) {
    h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2] + h[3] + h[3];
  }

  const r = parseInt(h.substring(0, 2), 16);
  const g = parseInt(h.substring(2, 4), 16);
  const b = parseInt(h.substring(4, 6), 16);
  const a = h.length === 8 ? parseInt(h.substring(6, 8), 16) / 255 : 1;

  return { r: r || 0, g: g || 0, b: b || 0, a };
}

/** Convert RGB (0-255) to hex string. Includes alpha pair if a < 1. */
export function rgbToHex(r: number, g: number, b: number, a = 1): string {
  const toHex = (n: number) => Math.round(clamp(n, 0, 255)).toString(16).padStart(2, '0');
  const hex = '#' + toHex(r) + toHex(g) + toHex(b);
  if (a < 1) {
    return hex + toHex(Math.round(a * 255));
  }
  return hex;
}

// ============================================================================
// RGB ↔ HSL
// ============================================================================

/** Convert RGB (0-255) to HSL (h: 0-360, s: 0-100, l: 0-100). */
export function rgbToHsl(r: number, g: number, b: number): { h: number; s: number; l: number } {
  const rn = r / 255;
  const gn = g / 255;
  const bn = b / 255;
  const max = Math.max(rn, gn, bn);
  const min = Math.min(rn, gn, bn);
  const delta = max - min;
  const l = (max + min) / 2;

  if (delta === 0) {
    return { h: 0, s: 0, l: l * 100 };
  }

  const s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
  let h: number;

  if (max === rn) {
    h = ((gn - bn) / delta + (gn < bn ? 6 : 0)) * 60;
  } else if (max === gn) {
    h = ((bn - rn) / delta + 2) * 60;
  } else {
    h = ((rn - gn) / delta + 4) * 60;
  }

  return { h: Math.round(h), s: Math.round(s * 100), l: Math.round(l * 100) };
}

/** Convert HSL (h: 0-360, s: 0-100, l: 0-100) to RGB (0-255). */
export function hslToRgb(h: number, s: number, l: number): { r: number; g: number; b: number } {
  const sn = s / 100;
  const ln = l / 100;

  if (sn === 0) {
    const v = Math.round(ln * 255);
    return { r: v, g: v, b: v };
  }

  const hue2rgb = (p: number, q: number, t: number): number => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };

  const q = ln < 0.5 ? ln * (1 + sn) : ln + sn - ln * sn;
  const p = 2 * ln - q;
  const hn = h / 360;

  return {
    r: Math.round(hue2rgb(p, q, hn + 1 / 3) * 255),
    g: Math.round(hue2rgb(p, q, hn) * 255),
    b: Math.round(hue2rgb(p, q, hn - 1 / 3) * 255),
  };
}

// ============================================================================
// HSL ↔ HSV
// ============================================================================

/** Convert HSL (h: 0-360, s: 0-100, l: 0-100) to HSV (h: 0-360, s: 0-100, v: 0-100). */
export function hslToHsv(h: number, s: number, l: number): { h: number; s: number; v: number } {
  const sn = s / 100;
  const ln = l / 100;
  const v = ln + sn * Math.min(ln, 1 - ln);
  const sv = v === 0 ? 0 : 2 * (1 - ln / v);
  return { h, s: Math.round(sv * 100), v: Math.round(v * 100) };
}

/** Convert HSV (h: 0-360, s: 0-100, v: 0-100) to HSL (h: 0-360, s: 0-100, l: 0-100). */
export function hsvToHsl(h: number, s: number, v: number): { h: number; s: number; l: number } {
  const sn = s / 100;
  const vn = v / 100;
  const l = vn * (1 - sn / 2);
  const sl = l === 0 || l === 1 ? 0 : (vn - l) / Math.min(l, 1 - l);
  return { h, s: Math.round(sl * 100), l: Math.round(l * 100) };
}

// ============================================================================
// Formatting
// ============================================================================

/**
 * Format HSLA values into the requested CSS color string format.
 * When withAlpha is true, the alpha channel is always included in the output.
 * When false, alpha is omitted entirely (treated as 1).
 */
export function formatColor(h: number, s: number, l: number, a: number, fmt: string, withAlpha = false): string {
  switch (fmt) {
    case 'hex': {
      const { r, g, b } = hslToRgb(h, s, l);
      return withAlpha ? rgbToHex(r, g, b, a) : rgbToHex(r, g, b);
    }
    case 'rgb': {
      const { r, g, b } = hslToRgb(h, s, l);
      if (withAlpha) {
        return `rgba(${r}, ${g}, ${b}, ${round2(a)})`;
      }
      return `rgb(${r}, ${g}, ${b})`;
    }
    case 'hsl':
      if (withAlpha) {
        return `hsla(${Math.round(h)}, ${Math.round(s)}%, ${Math.round(l)}%, ${round2(a)})`;
      }
      return `hsl(${Math.round(h)}, ${Math.round(s)}%, ${Math.round(l)}%)`;
    default:
      return formatColor(h, s, l, a, 'hex', withAlpha);
  }
}

// ============================================================================
// Helpers
// ============================================================================

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
