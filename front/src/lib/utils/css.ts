/**
 * CSS utilities for converting MATLAB values to CSS strings.
 *
 * MATLAB sends flexible types (number, number[], string) that need
 * to be converted to valid CSS values on the frontend.
 */

// ============================================================================
// Types
// ============================================================================

/** Single CSS size value: number (pixels) or string (any CSS unit) */
export type CssSize = number | string;

/** CSS spacing value: number, array (shorthand), or string */
export type CssSpacing = number | number[] | string;

/** CSS grid template value: number, array (pixels), or string (CSS syntax) */
export type CssGridTemplate = number | number[] | string;

// ============================================================================
// Conversion Functions
// ============================================================================

/**
 * Convert a size value to CSS string.
 *   - number → "Npx"
 *   - string → as-is
 *
 * @example
 * toSize(16)      // "16px"
 * toSize("1.5rem") // "1.5rem"
 */
export function toSize(value: CssSize): string {
  if (typeof value === 'number') {
    return `${value}px`;
  }
  return value;
}

/**
 * Convert a spacing value to CSS string.
 *   - number   → "Npx"
 *   - number[] → "Npx Npx..." (CSS shorthand)
 *   - string   → as-is
 *
 * @example
 * toSpacing(16)           // "16px"
 * toSpacing([10, 20])     // "10px 20px"
 * toSpacing([1, 2, 3, 4]) // "1px 2px 3px 4px"
 * toSpacing("1rem")       // "1rem"
 */
export function toSpacing(value: CssSpacing): string {
  if (typeof value === 'number') {
    return `${value}px`;
  }
  if (Array.isArray(value)) {
    return value.map((n) => `${n}px`).join(' ');
  }
  return value;
}

/**
 * Convert a grid template value to CSS string.
 *   - number   → "Npx" (single track)
 *   - number[] → "Npx Npx..." (multiple tracks)
 *   - string   → as-is (CSS grid syntax)
 *
 * @example
 * toGridTemplate(200)           // "200px"
 * toGridTemplate([100, 200])    // "100px 200px"
 * toGridTemplate("1fr 2fr")     // "1fr 2fr"
 * toGridTemplate("repeat(3, 1fr)") // "repeat(3, 1fr)"
 */
export function toGridTemplate(value: CssGridTemplate): string {
  if (typeof value === 'number') {
    return `${value}px`;
  }
  if (Array.isArray(value)) {
    return value.map((n) => `${n}px`).join(' ');
  }
  return value;
}

/**
 * Extract numeric value from a size (for SVG attributes that need numbers).
 * Returns default if value is a string.
 *
 * @example
 * toNumericSize(24)        // 24
 * toNumericSize("1.5rem")  // 24 (default)
 * toNumericSize("1.5rem", 16) // 16 (custom default)
 */
export function toNumericSize(value: CssSize, defaultValue = 24): number {
  if (typeof value === 'number') {
    return value;
  }
  return defaultValue;
}
