import type { FilterMatcher, SortComparator, EnumConfig } from '$lib/utils/table-utils';

/**
 * Enum filter matcher.
 * Filter value is a string[] of selected (included) items.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const selected = filterValue as string[];
  if (!Array.isArray(selected) || selected.length === 0) return true;
  return selected.includes(String(cellValue ?? ''));
};

/**
 * Enum sort comparator.
 * Sorts by ordinal position in the Items array (first item = lowest).
 * Values not in Items sort after all known items.
 */
export const sort: SortComparator = (a, b, config) => {
  const items = (config as EnumConfig)?.items;
  if (!items) return String(a).localeCompare(String(b));
  const ia = items.indexOf(String(a));
  const ib = items.indexOf(String(b));
  return (ia === -1 ? Infinity : ia) - (ib === -1 ? Infinity : ib);
};
