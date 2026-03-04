import type { FilterMatcher, ToComparable, DateFilterValue } from '$lib/utils/table-utils';
import { dateToEpoch, numericSort } from '$lib/utils/table-utils';

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

/** Convert a raw date value (ISO string or epoch number) to epoch milliseconds. */
export const toComparable: ToComparable = (v) => dateToEpoch(v);

/** Date sort: derived from toComparable (NaN-to-end handled by numericSort). */
export const sort = numericSort(toComparable);
