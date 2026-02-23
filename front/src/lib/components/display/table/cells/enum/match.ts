import type { FilterMatcher } from '$lib/utils/table-utils';

/**
 * Enum filter matcher.
 * Filter value is a string[] of selected (included) items.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const selected = filterValue as string[];
  if (!Array.isArray(selected) || selected.length === 0) return true;
  return selected.includes(String(cellValue ?? ''));
};
