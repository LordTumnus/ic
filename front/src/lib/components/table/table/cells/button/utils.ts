import type { FilterMatcher, SortComparator } from '$lib/utils/table-utils';

/** Button columns never participate in filtering — always pass. */
export const match: FilterMatcher = () => true;

/** Button columns never participate in sorting — stable order. */
export const sort: SortComparator = () => 0;
