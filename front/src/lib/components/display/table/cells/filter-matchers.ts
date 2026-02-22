import type { FilterMatcher } from '$lib/utils/table-utils';
import { match as textMatch } from './text/match';
import { match as numberMatch } from './number/match';
import { match as booleanMatch } from './boolean/match';
import { match as progressbarMatch } from './progressbar/match';
import { match as sparklineMatch } from './sparkline/match';

/** Registry: column type → filter matcher. Adding a new cell type = add match.ts + one entry here. */
export const filterMatchers: Record<string, FilterMatcher> = {
  text: textMatch,
  number: numberMatch,
  boolean: booleanMatch,
  progressbar: progressbarMatch,
  sparkline: sparklineMatch,
};
