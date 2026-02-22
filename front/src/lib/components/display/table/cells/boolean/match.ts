import type { FilterMatcher } from '$lib/utils/table-utils';

/**
 * Boolean filter matcher: exact true/false match. null = all pass.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  if (filterValue == null) return true;
  return Boolean(cellValue) === filterValue;
};
