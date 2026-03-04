/**
 * Popover positioning utilities.
 *
 * Pure functions that compute panel position relative to a trigger element,
 * with optional viewport collision avoidance.
 *
 * All positions are in pixels, relative to the popover root element
 * (which wraps the trigger with `position: relative`).
 */

// ── Types ──────────────────────────────────────────────────────

export type Side = 'top' | 'right' | 'bottom' | 'left';
export type PopoverAlign = 'start' | 'center' | 'end';

export interface PopoverPosition {
  top: number;
  left: number;
  /** Effective side after collision resolution (may differ from requested). */
  side: Side;
  /** Effective align after collision resolution. */
  align: PopoverAlign;
}

export interface PopoverConfig {
  side: Side;
  align: PopoverAlign;
  offset: number;
  avoidCollisions: boolean;
}

// ── Constants ──────────────────────────────────────────────────

const OPPOSITE_SIDE: Record<Side, Side> = {
  top: 'bottom',
  bottom: 'top',
  left: 'right',
  right: 'left',
};

const OPPOSITE_ALIGN: Record<PopoverAlign, PopoverAlign> = {
  start: 'end',
  end: 'start',
  center: 'center',
};

// ── Raw position (no collision logic) ──────────────────────────

/**
 * Compute (top, left) in px relative to the popover root element.
 *
 * The root element wraps the trigger with `display: inline-flex`,
 * so rootW/rootH match the trigger's layout dimensions.
 */
function computeRawPosition(
  side: Side,
  align: PopoverAlign,
  rootW: number,
  rootH: number,
  panelW: number,
  panelH: number,
  offset: number,
): { top: number; left: number } {
  let top = 0;
  let left = 0;

  // ── Side axis (which edge the panel sits on) ──
  switch (side) {
    case 'bottom':
      top = rootH + offset;
      break;
    case 'top':
      top = -(panelH + offset);
      break;
    case 'right':
      left = rootW + offset;
      break;
    case 'left':
      left = -(panelW + offset);
      break;
  }

  // ── Align axis (perpendicular to side) ──
  if (side === 'top' || side === 'bottom') {
    // Align is horizontal
    switch (align) {
      case 'start':
        left = 0;
        break;
      case 'center':
        left = (rootW - panelW) / 2;
        break;
      case 'end':
        left = rootW - panelW;
        break;
    }
  } else {
    // side is left/right → align is vertical
    switch (align) {
      case 'start':
        top = 0;
        break;
      case 'center':
        top = (rootH - panelH) / 2;
        break;
      case 'end':
        top = rootH - panelH;
        break;
    }
  }

  return { top, left };
}

// ── Overflow detection ─────────────────────────────────────────

/** Positive values = overflow beyond that viewport edge. */
interface Overflow {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

function getOverflow(
  top: number,
  left: number,
  panelW: number,
  panelH: number,
  triggerRect: DOMRect,
  vpW: number,
  vpH: number,
): Overflow {
  // Convert root-relative coords to viewport coords
  const vpTop = triggerRect.top + top;
  const vpLeft = triggerRect.left + left;

  return {
    top: Math.max(0, -vpTop),
    left: Math.max(0, -vpLeft),
    bottom: Math.max(0, vpTop + panelH - vpH),
    right: Math.max(0, vpLeft + panelW - vpW),
  };
}

function totalOverflow(o: Overflow): number {
  return o.top + o.right + o.bottom + o.left;
}

// ── Collision resolution ───────────────────────────────────────

function resolveCollisions(
  side: Side,
  align: PopoverAlign,
  rootW: number,
  rootH: number,
  panelW: number,
  panelH: number,
  offset: number,
  triggerRect: DOMRect,
  vpW: number,
  vpH: number,
): { side: Side; align: PopoverAlign } {
  // Build candidates in priority order
  const oppSide = OPPOSITE_SIDE[side];
  const oppAlign = OPPOSITE_ALIGN[align];
  const aligns: PopoverAlign[] = ['start', 'center', 'end'];

  const candidates: Array<[Side, PopoverAlign]> = [
    [side, align], // 1. Preferred
    [oppSide, align], // 2. Flip side
  ];

  if (align !== 'center') {
    candidates.push(
      [side, oppAlign], // 3. Flip align
      [oppSide, oppAlign], // 4. Flip both
    );
  }

  // 5. All remaining aligns on preferred side, then opposite
  for (const a of aligns) {
    candidates.push([side, a]);
    candidates.push([oppSide, a]);
  }

  let bestSide = side;
  let bestAlign = align;
  let bestOverflow = Infinity;

  for (const [s, a] of candidates) {
    const pos = computeRawPosition(s, a, rootW, rootH, panelW, panelH, offset);
    const overflow = getOverflow(pos.top, pos.left, panelW, panelH, triggerRect, vpW, vpH);
    const total = totalOverflow(overflow);

    if (total === 0) {
      return { side: s, align: a };
    }
    if (total < bestOverflow) {
      bestOverflow = total;
      bestSide = s;
      bestAlign = a;
    }
  }

  return { side: bestSide, align: bestAlign };
}

// ── Public API ─────────────────────────────────────────────────

/**
 * Compute the panel position for a popover.
 *
 * @param triggerRect - `rootEl.getBoundingClientRect()` (viewport coords of the root/trigger)
 * @param panelW     - `panelEl.offsetWidth` (unaffected by CSS transforms)
 * @param panelH     - `panelEl.offsetHeight`
 * @param vpW        - `window.innerWidth`
 * @param vpH        - `window.innerHeight`
 * @param config     - Side, align, offset, avoidCollisions
 */
export function computePosition(
  triggerRect: DOMRect,
  panelW: number,
  panelH: number,
  vpW: number,
  vpH: number,
  config: PopoverConfig,
): PopoverPosition {
  const rootW = triggerRect.width;
  const rootH = triggerRect.height;
  const { side, align, offset, avoidCollisions } = config;

  let effectiveSide = side;
  let effectiveAlign = align;

  if (avoidCollisions) {
    const resolved = resolveCollisions(
      side,
      align,
      rootW,
      rootH,
      panelW,
      panelH,
      offset,
      triggerRect,
      vpW,
      vpH,
    );
    effectiveSide = resolved.side;
    effectiveAlign = resolved.align;
  }

  const { top, left } = computeRawPosition(
    effectiveSide,
    effectiveAlign,
    rootW,
    rootH,
    panelW,
    panelH,
    offset,
  );

  return { top, left, side: effectiveSide, align: effectiveAlign };
}
