import type { SortComparator } from '$lib/utils/table-utils';
import { sort as textSort } from './text/utils';
import { sort as numberSort } from './number/utils';
import { sort as booleanSort } from './boolean/utils';
import { sort as progressbarSort } from './progressbar/utils';
import { sort as sparklineSort } from './sparkline/utils';
import { sort as imageSort } from './image/utils';
import { sort as enumSort } from './enum/utils';
import { sort as ratingSort } from './rating/utils';

/** Registry: column type → sort comparator. Adding a new cell type = add utils.ts + one entry here. */
export const sortComparators: Record<string, SortComparator> = {
  text: textSort,
  number: numberSort,
  boolean: booleanSort,
  progressbar: progressbarSort,
  sparkline: sparklineSort,
  image: imageSort,
  enum: enumSort,
  rating: ratingSort,
};
