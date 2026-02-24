import type { FilterMatcher, SortComparator, NumberFilterValue } from '$lib/utils/table-utils';

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

/** Rating sort: simple numeric comparison. */
export const sort: SortComparator = (a, b) =>
  Number(a) - Number(b);
