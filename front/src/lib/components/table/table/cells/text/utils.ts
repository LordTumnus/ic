import type { FilterMatcher, SortComparator } from '$lib/utils/table-utils';

/**
 * Text filter matcher: case-insensitive "contains" search.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const sv = String(filterValue).toLowerCase();
  const cv = String(cellValue ?? '').toLowerCase();
  return cv.includes(sv);
};

/** Text sort: locale-aware string comparison. */
export const sort: SortComparator = (a, b) =>
  String(a).localeCompare(String(b));
