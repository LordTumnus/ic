import type { FilterMatcher } from '$lib/utils/table-utils';
import { match as textMatch } from './text/utils';
import { match as numberMatch } from './number/utils';
import { match as booleanMatch } from './boolean/utils';
import { match as progressbarMatch } from './progressbar/utils';
import { match as sparklineMatch } from './sparkline/utils';
import { match as imageMatch } from './image/utils';
import { match as enumMatch } from './enum/utils';
import { match as ratingMatch } from './rating/utils';

/** Registry: column type → filter matcher. Adding a new cell type = add utils.ts + one entry here. */
export const filterMatchers: Record<string, FilterMatcher> = {
  text: textMatch,
  number: numberMatch,
  boolean: booleanMatch,
  progressbar: progressbarMatch,
  sparkline: sparklineMatch,
  image: imageMatch,
  enum: enumMatch,
  rating: ratingMatch,
};
