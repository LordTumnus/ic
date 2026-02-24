import type { FilterMatcher, SortComparator, DateFilterValue } from '$lib/utils/table-utils';
import { dateToEpoch } from '$lib/utils/table-utils';

/**
 * Date filter matcher: compares cell date against min/max ISO date bounds.
 * min is start-of-day inclusive, max is end-of-day inclusive.
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const fv = filterValue as DateFilterValue;
  const cellEpoch = dateToEpoch(cellValue);
  if (isNaN(cellEpoch)) return false;

  if (fv.min) {
    const minEpoch = new Date(fv.min + 'T00:00:00').getTime();
    if (cellEpoch < minEpoch) return false;
  }
  if (fv.max) {
    const maxEpoch = new Date(fv.max + 'T23:59:59.999').getTime();
    if (cellEpoch > maxEpoch) return false;
  }
  return true;
};

/** Date sort: chronological comparison via epoch milliseconds. */
export const sort: SortComparator = (a, b) => {
  const ea = dateToEpoch(a);
  const eb = dateToEpoch(b);
  // Push invalid dates to the end
  if (isNaN(ea) && isNaN(eb)) return 0;
  if (isNaN(ea)) return 1;
  if (isNaN(eb)) return -1;
  return ea - eb;
};
