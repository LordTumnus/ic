import type { FilterMatcher, ToComparable, NumberFilterValue } from '$lib/utils/table-utils';
import { numericSort } from '$lib/utils/table-utils';

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

/** Convert a raw value to a comparable number. */
export const toComparable: ToComparable = (v) => Number(v);

/** Numeric sort: derived from toComparable. */
export const sort = numericSort(toComparable);
