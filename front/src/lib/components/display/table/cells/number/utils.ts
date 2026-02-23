import type { FilterMatcher, SortComparator, NumberFilterValue } from '$lib/utils/table-utils';

/**
 * Numeric range matcher: checks min/max bounds.
 * Also used by progressbar (same filter value shape).
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const range = filterValue as NumberFilterValue;
  const num = Number(cellValue);
  if (range.min != null && num < range.min) return false;
  if (range.max != null && num > range.max) return false;
  return true;
};

/** Numeric sort: arithmetic comparison. */
export const sort: SortComparator = (a, b) =>
  Number(a) - Number(b);
