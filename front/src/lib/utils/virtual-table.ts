/**
 * Shared types and utilities for VirtualTable.
 */
import type { TableRow } from './table-utils';

/** A cached row entry: row data + its 1-based original index in MATLAB Data. */
export interface CachedRow {
  data: TableRow;
  originalIndex: number; // 1-based (as returned by MATLAB)
}

/** A visible row to render — either loaded data or a placeholder. */
export interface VisibleRow {
  viewIndex: number;
  cached: CachedRow | null;
}

/** Response from the MATLAB getRows request handler. */
export interface GetRowsResponse {
  rows: TableRow[];
  indices: number[]; // 1-based original indices
}

/**
 * Normalize the raw getRows response from MATLAB.
 *
 * MATLAB's `table2struct` + `jsonencode` has a quirk: a single-row result
 * produces a plain object `{A:1}` instead of an array `[{A:1}]`.
 * This function ensures `rows` is always an array.
 */
export function normalizeGetRowsResponse(raw: unknown): GetRowsResponse {
  if (!raw || typeof raw !== 'object') return { rows: [], indices: [] };
  const obj = raw as Record<string, unknown>;

  let rows: TableRow[];
  if (Array.isArray(obj.rows)) {
    rows = obj.rows as TableRow[];
  } else if (obj.rows && typeof obj.rows === 'object') {
    // Single-row struct → wrap in array
    rows = [obj.rows as TableRow];
  } else {
    rows = [];
  }

  let indices: number[];
  if (Array.isArray(obj.indices)) {
    indices = obj.indices as number[];
  } else if (typeof obj.indices === 'number') {
    indices = [obj.indices];
  } else {
    indices = [];
  }

  return { rows, indices };
}
