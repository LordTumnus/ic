import type { FilterMatcher, SortComparator, ToComparable } from '$lib/utils/table-utils';

/**
 * Boolean filter matcher: exact true/false match. null = all pass.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  if (filterValue == null) return true;
  return Boolean(cellValue) === filterValue;
};

/** Convert a boolean-ish value to 1 (truthy) or 0 (falsy). */
export const toComparable: ToComparable = (v) =>
  typeof v === 'boolean' ? (v ? 1 : 0) : Number(v);

/** Boolean sort: true before false (custom — not derivable from toComparable). */
export const sort: SortComparator = (a, b) => {
  const ba = Boolean(a);
  const bb = Boolean(b);
  return ba === bb ? 0 : ba ? -1 : 1;
};
