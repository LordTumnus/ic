import type { FilterMatcher, NumberFilterValue } from '$lib/utils/table-utils';

/** Extended filter value that carries the metric mode alongside the numeric range. */
export interface SparklineFilterValue extends NumberFilterValue {
  metric?: 'total' | 'relative';
}

/**
 * Sparkline filter matcher.
 *
 * metric = "total"    → compares the LAST value in the array (default)
 * metric = "relative" → compares the % change from first to last
 */
export const match: FilterMatcher = (cellValue, filterValue) => {
  const fv = filterValue as SparklineFilterValue;
  const arr = Array.isArray(cellValue) ? cellValue : [];
  if (arr.length === 0) return false;

  let target: number;
  if (fv.metric === 'relative') {
    if (arr.length < 2) return false;
    const first = Number(arr[0]);
    const last = Number(arr[arr.length - 1]);
    if (first === 0) return false; // can't compute % change from zero
    target = ((last - first) / Math.abs(first)) * 100;
  } else {
    target = Number(arr[arr.length - 1]);
  }

  if (!isFinite(target)) return false;
  if (fv.min != null && target < fv.min) return false;
  if (fv.max != null && target > fv.max) return false;
  return true;
};
