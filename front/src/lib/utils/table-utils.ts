/**
 * Shared types and utilities for table components.
 */

// ============================================================================
// Types
// ============================================================================

/** Column definition as received from MATLAB (camelCase). */
export interface TableColumn {
  field: string;
  header: string;
  type: 'text' | 'number' | 'boolean';
  width: number | string;
  minWidth: number;
  sortable: boolean;
  filterable: boolean;
  resizable: boolean;
  align: 'left' | 'center' | 'right' | 'auto';
  pinned: 'none' | 'left' | 'right';
  hasAction: boolean;
  config: Record<string, unknown>;
}

/** Payload published to MATLAB when a cell fires its action. */
export interface CellActionPayload {
  field: string;
  rowIndex: number;
  data: unknown;
}

/** Number column config as received from MATLAB. */
export interface NumberConfig {
  decimals: number;    // -1 = auto (no rounding)
  prefix: string;
  suffix: string;
  thousandsSeparator: boolean;
  colorRules?: ColorRuleConfig[];
}

/** A single conditional color rule. */
export interface ColorRuleConfig {
  op: '>' | '>=' | '<' | '<=' | '==' | '~=' | 'between';
  value: number | number[];
  color: string;
}

/** Boolean column config as received from MATLAB. */
export interface BooleanConfig {
  displayMode: 'checkbox' | 'text' | 'numeric';
  colorRules?: ColorRuleConfig[];
}

/** Text column config as received from MATLAB. */
export interface TextConfig {
  richText?: boolean;
  placeholder?: string;
  transform?: 'none' | 'uppercase' | 'lowercase' | 'capitalize';
}

/** A single row of table data (field → value). */
export type TableRow = Record<string, unknown>;

/** Column-oriented data as received from MATLAB's jsonencode(table). */
export type ColumnOrientedData = Record<string, unknown[]>;

/** Sort state. */
export interface SortState {
  field: string;
  direction: 'none' | 'asc' | 'desc';
}

/** Filter state — field → filter value. */
export type FilterState = Record<string, unknown>;

/** Number range filter value. */
export interface NumberFilterValue {
  min?: number;
  max?: number;
}

/** Empty filter value — matches rows where cell is empty (null, undefined, or ""). */
export interface EmptyFilterValue {
  isEmpty: true;
}

/** Not-empty filter value — matches rows where cell has a value. */
export interface NotEmptyFilterValue {
  isNotEmpty: true;
}

/** A row paired with its original index in the unsorted/unfiltered data. */
export interface IndexedRow {
  data: TableRow;
  originalIndex: number;
}

/** Row size dimensions. */
export const ROW_HEIGHTS = {
  sm: 24,
  md: 28,
  lg: 36,
} as const;

/** Default column width when none specified. */
export const DEFAULT_COLUMN_WIDTH = 150;

/** Minimum column width for resize. */
export const MIN_RESIZE_WIDTH = 40;

// ============================================================================
// Data Transposition
// ============================================================================

/**
 * Normalize table data to row-oriented format.
 *
 * MATLAB's jsonencode(table) produces row-oriented JSON:
 *   [{"Name":"Alice","Age":30}, {"Name":"Bob","Age":25}]
 *
 * This function also handles column-oriented data (for manual use):
 *   { Name: ["Alice","Bob"], Age: [30,25] }
 *
 * Returns: [{ Name: "Alice", Age: 30 }, { Name: "Bob", Age: 25 }]
 */
export function normalizeTableData(data: unknown): TableRow[] {
  if (!data) return [];

  // Row-oriented (MATLAB jsonencode(table) output)
  if (Array.isArray(data)) {
    return data as TableRow[];
  }

  // Column-oriented (object of arrays)
  if (typeof data === 'object') {
    const columnData = data as ColumnOrientedData;
    const fields = Object.keys(columnData);
    if (fields.length === 0) return [];

    const firstCol = columnData[fields[0]];
    const rowCount = Array.isArray(firstCol) ? firstCol.length : 0;
    if (rowCount === 0) return [];

    const rows: TableRow[] = new Array(rowCount);
    for (let i = 0; i < rowCount; i++) {
      const row: TableRow = {};
      for (const field of fields) {
        row[field] = columnData[field][i];
      }
      rows[i] = row;
    }
    return rows;
  }

  return [];
}

// ============================================================================
// Column Utilities
// ============================================================================

/**
 * Resolve "auto" alignment based on column type.
 */
export function resolveAlign(col: TableColumn): 'left' | 'center' | 'right' {
  if (col.align !== 'auto') return col.align;
  switch (col.type) {
    case 'number':
      return 'right';
    case 'boolean':
      return 'center';
    default:
      return 'left';
  }
}

/**
 * Compute initial column widths from column definitions.
 * Returns array of pixel widths. A value of 0 means "auto" (use flex:1).
 */
export function computeColumnWidths(
  columns: TableColumn[],
  containerWidth: number,
): number[] {
  const widths: number[] = [];
  let fixedTotal = 0;
  let autoCount = 0;

  for (const col of columns) {
    if (typeof col.width === 'number' && col.width > 0) {
      widths.push(col.width);
      fixedTotal += col.width;
    } else if (typeof col.width === 'string' && col.width.endsWith('%')) {
      const pct = parseFloat(col.width) / 100;
      const w = Math.max(containerWidth * pct, col.minWidth || MIN_RESIZE_WIDTH);
      widths.push(w);
      fixedTotal += w;
    } else {
      widths.push(0); // auto — resolved below for pinned columns
      autoCount++;
    }
  }

  // Pinned auto-width columns need a concrete pixel width for sticky offsets.
  // Give them equal share of remaining space; unpinned auto columns stay 0 (flex).
  if (autoCount > 0) {
    const remaining = Math.max(0, containerWidth - fixedTotal);
    const autoWidth = Math.max(remaining / autoCount, MIN_RESIZE_WIDTH);
    for (let i = 0; i < widths.length; i++) {
      if (widths[i] === 0 && columns[i].pinned) {
        widths[i] = autoWidth;
      }
    }
  }

  return widths;
}

// ============================================================================
// Pinned Columns
// ============================================================================

/** Pinned offset info for a single column. */
export interface PinnedInfo {
  side: 'left' | 'right';
  offset: number; // px offset from the pinned edge
}

/**
 * Compute sticky offsets for pinned columns.
 * Returns a map from column field → PinnedInfo.
 * Only columns with pinned != "none" are included.
 *
 * @param baseLeftOffset - extra left offset before the first pinned column
 *   (e.g. row number gutter width)
 */
export function computePinnedOffsets(
  columns: TableColumn[],
  columnWidths: number[],
  baseLeftOffset: number = 0,
): Map<string, PinnedInfo> {
  const result = new Map<string, PinnedInfo>();

  // Left-pinned: accumulate from left
  let leftOffset = baseLeftOffset;
  for (let i = 0; i < columns.length; i++) {
    const col = columns[i];
    const w = columnWidths[i] ?? 0;
    if (col.pinned === 'left') {
      result.set(col.field, { side: 'left', offset: leftOffset });
      leftOffset += w;
    }
  }

  // Right-pinned: accumulate from right
  let rightOffset = 0;
  for (let i = columns.length - 1; i >= 0; i--) {
    const col = columns[i];
    const w = columnWidths[i] ?? 0;
    if (col.pinned === 'right') {
      result.set(col.field, { side: 'right', offset: rightOffset });
      rightOffset += w;
    }
  }

  return result;
}

// ============================================================================
// Sorting
// ============================================================================

/**
 * Sort indexed rows client-side by a column field.
 * Returns a NEW sorted array (does not mutate input).
 */
export function sortRows(
  rows: IndexedRow[],
  field: string,
  direction: 'asc' | 'desc' | 'none',
): IndexedRow[] {
  if (!field || direction === 'none') return rows;

  return [...rows].sort((a, b) => {
    const va = a.data[field];
    const vb = b.data[field];

    // Handle nulls/undefined — push to end
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;

    let cmp: number;
    if (typeof va === 'number' && typeof vb === 'number') {
      cmp = va - vb;
    } else if (typeof va === 'boolean' && typeof vb === 'boolean') {
      cmp = (va === vb) ? 0 : va ? -1 : 1;
    } else {
      cmp = String(va).localeCompare(String(vb));
    }

    return direction === 'asc' ? cmp : -cmp;
  });
}

// ============================================================================
// Filtering
// ============================================================================

/**
 * Filter indexed rows client-side by active filters.
 * Returns a NEW filtered array.
 */
export function filterRows(
  rows: IndexedRow[],
  filters: FilterState,
  columns: TableColumn[],
): IndexedRow[] {
  const activeFields = Object.keys(filters).filter(f => {
    const v = filters[f];
    return v != null && v !== '' && !(typeof v === 'object' && 'min' in (v as NumberFilterValue) && (v as NumberFilterValue).min == null && (v as NumberFilterValue).max == null);
  });
  if (activeFields.length === 0) return rows;

  // Build column lookup
  const colMap = new Map<string, TableColumn>();
  for (const col of columns) colMap.set(col.field, col);

  return rows.filter(irow => {
    const row = irow.data;
    for (const field of activeFields) {
      const filterVal = filters[field];
      const cellVal = row[field];
      const col = colMap.get(field);

      if (!col) continue;

      // "Is empty" / "Is not empty" filters (text + number types)
      if (typeof filterVal === 'object' && filterVal !== null && !Array.isArray(filterVal)) {
        if ('isEmpty' in (filterVal as Record<string, unknown>)) {
          if (cellVal != null && cellVal !== '') return false;
          continue;
        }
        if ('isNotEmpty' in (filterVal as Record<string, unknown>)) {
          if (cellVal == null || cellVal === '') return false;
          continue;
        }
      }

      if (col.type === 'number') {
        const range = filterVal as NumberFilterValue;
        const num = Number(cellVal);
        if (range.min != null && num < range.min) return false;
        if (range.max != null && num > range.max) return false;
      } else if (col.type === 'boolean') {
        // filterVal: true, false, or null (all)
        if (filterVal != null && Boolean(cellVal) !== filterVal) return false;
      } else {
        // Text-based: contains search (case-insensitive)
        const sv = String(filterVal).toLowerCase();
        const cv = String(cellVal ?? '').toLowerCase();
        if (!cv.includes(sv)) return false;
      }
    }
    return true;
  });
}

// ============================================================================
// Number Formatting
// ============================================================================

/**
 * Format a number using config properties (decimals, prefix, suffix, thousands).
 */
export function formatNumberWithConfig(value: number, cfg: NumberConfig): string {
  let str: string;
  if (cfg.decimals >= 0) {
    str = value.toFixed(cfg.decimals);
  } else {
    str = String(value);
  }

  if (cfg.thousandsSeparator) {
    const [intPart, decPart] = str.split('.');
    const withCommas = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    str = decPart != null ? `${withCommas}.${decPart}` : withCommas;
  }

  return `${cfg.prefix}${str}${cfg.suffix}`;
}

/**
 * Evaluate color rules against a value. Returns the first matching color or null.
 */
export function evaluateColorRules(value: number, rules: ColorRuleConfig[]): string | null {
  for (const rule of rules) {
    const v = rule.value;
    switch (rule.op) {
      case '>':       if (value > (v as number))  return rule.color; break;
      case '>=':      if (value >= (v as number)) return rule.color; break;
      case '<':       if (value < (v as number))  return rule.color; break;
      case '<=':      if (value <= (v as number)) return rule.color; break;
      case '==':      if (value === (v as number)) return rule.color; break;
      case '~=':      if (value !== (v as number)) return rule.color; break;
      case 'between': {
        const [lo, hi] = v as number[];
        if (value >= lo && value <= hi) return rule.color;
        break;
      }
    }
  }
  return null;
}

/**
 * Format a number using a printf-style format string (legacy).
 */
export function formatNumber(value: number, format: string): string {
  if (!format) return String(value);

  return format.replace(/%([0-9]*\.?[0-9]*)([df])/, (_match, spec, type) => {
    if (type === 'd') {
      return Math.round(value).toString();
    }
    if (spec && spec.includes('.')) {
      const decimals = parseInt(spec.split('.')[1], 10);
      return value.toFixed(decimals);
    }
    return value.toFixed(6);
  });
}

// ============================================================================
// Cycle Sort Direction
// ============================================================================

/**
 * Cycle sort direction: none → asc → desc → none.
 */
export function cycleSortDirection(current: 'none' | 'asc' | 'desc'): 'none' | 'asc' | 'desc' {
  switch (current) {
    case 'none': return 'asc';
    case 'asc': return 'desc';
    case 'desc': return 'none';
  }
}

// ============================================================================
// Rich Text (inline bold/italic)
// ============================================================================

/**
 * Convert **bold** and *italic* markers to <strong>/<em> HTML.
 * Escapes HTML entities first to prevent XSS via cell values.
 */
export function parseInlineRichText(text: string): string {
  let s = text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  // **bold** (must come before *italic* to avoid partial match)
  s = s.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  // *italic*
  s = s.replace(/\*(.+?)\*/g, '<em>$1</em>');
  return s;
}

