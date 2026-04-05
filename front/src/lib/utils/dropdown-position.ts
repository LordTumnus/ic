/**
 * Dropdown positioning utility.
 *
 * Computes `position: fixed` coordinates for dropdowns/popups so they
 * escape ancestor `overflow` containers. Uses `getBoundingClientRect()`
 * on the trigger element and flips vertically when space is tight.
 */

export interface DropdownPosition {
  top: number;
  left: number;
  width: number;
}

export interface DropdownPositionOptions {
  /** Gap in px between trigger and dropdown (default: 4). */
  offset?: number;
  /** Estimated or measured dropdown height for flip calculation. */
  dropdownHeight?: number;
  /** Match trigger width exactly (default: true). */
  matchWidth?: boolean;
}

/**
 * Compute fixed-position coordinates for a dropdown below (or above) a trigger.
 *
 * @param triggerEl  The element the dropdown anchors to.
 * @param opts       Optional tuning parameters.
 * @returns Position object with `top`, `left`, `width` in viewport px.
 */
export function computeDropdownPosition(
  triggerEl: HTMLElement,
  opts: DropdownPositionOptions = {},
): DropdownPosition {
  const { offset = 4, dropdownHeight = 200, matchWidth = true } = opts;
  const rect = triggerEl.getBoundingClientRect();
  const vpH = window.innerHeight;

  const spaceBelow = vpH - rect.bottom;
  const flipUp = spaceBelow < dropdownHeight + offset && rect.top > dropdownHeight + offset;

  return {
    top: flipUp ? rect.top - dropdownHeight - offset : rect.bottom + offset,
    left: rect.left,
    width: matchWidth ? rect.width : -1,
  };
}

/**
 * Build a CSS `style` string from a DropdownPosition.
 */
export function dropdownStyle(pos: DropdownPosition, extra = ''): string {
  const parts = [`top: ${pos.top}px`, `left: ${pos.left}px`];
  if (pos.width > 0) parts.push(`width: ${pos.width}px`);
  if (extra) parts.push(extra);
  return parts.join('; ');
}
