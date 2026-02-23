import type { FilterMatcher, SortComparator } from '$lib/utils/table-utils';

/**
 * Boolean filter matcher: exact true/false match. null = all pass.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  if (filterValue == null) return true;
  return Boolean(cellValue) === filterValue;
};

/** Boolean sort: true before false. */
export const sort: SortComparator = (a, b) => {
  const ba = Boolean(a);
  const bb = Boolean(b);
  return ba === bb ? 0 : ba ? -1 : 1;
};
