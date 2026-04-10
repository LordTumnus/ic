/**
 * Built-in marker icon SVGs.
 * Each returns an SVG string that can be used as a data URI for L.Icon.
 * Icons use currentColor so they inherit the primary theme color.
 */

const ICONS: Record<string, string> = {
  pin: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 36">
    <path d="M12 0C5.4 0 0 5.4 0 12c0 9 12 24 12 24s12-15 12-24C24 5.4 18.6 0 12 0z" fill="#e74c3c"/>
    <circle cx="12" cy="12" r="5" fill="#fff"/>
  </svg>`,

  dot: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
    <circle cx="10" cy="10" r="9" fill="#3b82f6" stroke="#fff" stroke-width="2"/>
  </svg>`,

  square: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
    <rect x="2" y="2" width="16" height="16" rx="2" fill="#3b82f6" stroke="#fff" stroke-width="2"/>
  </svg>`,

  diamond: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
    <rect x="3" y="3" width="14" height="14" rx="2" fill="#3b82f6" stroke="#fff" stroke-width="2" transform="rotate(45 10 10)"/>
  </svg>`,

  star: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
    <path d="M12 2l2.9 8.9H24l-7.2 5.2 2.7 8.9L12 19.8 4.5 25l2.7-8.9L0 10.9h9.1z" fill="#f59e0b" stroke="#fff" stroke-width="1"/>
  </svg>`,

  flag: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 30">
    <line x1="3" y1="2" x2="3" y2="28" stroke="#333" stroke-width="2" stroke-linecap="round"/>
    <path d="M3 2h14l-4 6 4 6H3z" fill="#e74c3c"/>
  </svg>`,

  cross: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
    <circle cx="10" cy="10" r="9" fill="none" stroke="#e74c3c" stroke-width="1.5"/>
    <line x1="10" y1="2" x2="10" y2="18" stroke="#e74c3c" stroke-width="1.5"/>
    <line x1="2" y1="10" x2="18" y2="10" stroke="#e74c3c" stroke-width="1.5"/>
  </svg>`,

  triangle: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 20">
    <path d="M11 1L1 19h20z" fill="#3b82f6" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>
  </svg>`,
};

/** Default icon anchors (center-bottom unless specified) */
const ANCHORS: Record<string, [number, number]> = {
  pin: [0.5, 1],     // tip at bottom-center
  dot: [0.5, 0.5],   // center
  square: [0.5, 0.5],
  diamond: [0.5, 0.5],
  star: [0.5, 0.5],
  flag: [0.15, 1],   // flagpole base
  cross: [0.5, 0.5],
  triangle: [0.5, 0.9],
};

/**
 * Convert an SVG string to a data URI suitable for L.Icon.
 */
function svgToDataUri(svg: string): string {
  return 'data:image/svg+xml;base64,' + btoa(svg);
}

/**
 * Get a built-in marker icon data URI by name.
 * Returns undefined if the name is not recognized.
 */
export function getBuiltinIcon(name: string): string | undefined {
  const svg = ICONS[name];
  return svg ? svgToDataUri(svg) : undefined;
}

/**
 * Get the default anchor ratio for a built-in icon.
 * Returns [ratioX, ratioY] where 0,0 is top-left and 1,1 is bottom-right.
 */
export function getBuiltinAnchor(name: string): [number, number] {
  return ANCHORS[name] ?? [0.5, 1];
}

export const BUILTIN_ICON_NAMES = Object.keys(ICONS);
