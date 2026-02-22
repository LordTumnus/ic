import type { FilterMatcher } from '$lib/utils/table-utils';

/**
 * Text filter matcher: case-insensitive "contains" search.
 * Handles isEmpty / isNotEmpty universally.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const sv = String(filterValue).toLowerCase();
  const cv = String(cellValue ?? '').toLowerCase();
  return cv.includes(sv);
};
