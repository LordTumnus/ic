import type { FilterMatcher } from '$lib/utils/table-utils';

/**
 * Image filter matcher.
 * Empty/not-empty is handled generically by filterRows.
 * No type-specific filtering — always passes.
 */
export const match: FilterMatcher = () => true;
