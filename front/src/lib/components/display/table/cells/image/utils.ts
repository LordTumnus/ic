import type { FilterMatcher, SortComparator } from '$lib/utils/table-utils';

/**
 * Image filter matcher.
 * Empty/not-empty is handled generically by filterRows.
 * No type-specific filtering — always passes.
 */
export const match: FilterMatcher = () => true;

/** Image sort: images present sort before empty. */
export const sort: SortComparator = (a, b) => {
  const ha = a != null && a !== '' ? 1 : 0;
  const hb = b != null && b !== '' ? 1 : 0;
  return hb - ha;
};
