import type { FilterMatcher, ToComparable, NumberFilterValue } from '$lib/utils/table-utils';
import { numericSort } from '$lib/utils/table-utils';

/**
 * Rating filter matcher: numeric range check (same logic as number).
 * The star-selector filter emits { min: N }, but we support max too for robustness.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const range = filterValue as NumberFilterValue;
  const num = Number(cellValue);
  if (range.min != null && num < range.min) return false;
  if (range.max != null && num > range.max) return false;
  return true;
};

/** Convert a raw rating value to a comparable number. */
export const toComparable: ToComparable = (v) => Number(v);

/** Rating sort: derived from toComparable. */
export const sort = numericSort(toComparable);
