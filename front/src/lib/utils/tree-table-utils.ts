/**
 * Utilities for TreeTable component.
 *
 * Extends tree-utils with column data, flat rendering, per-level sorting,
 * and tree-aware column filtering.
 */

import type { IconSource } from '$lib/utils/icons';
import type { TreeNode } from '$lib/utils/tree-utils';
import type {
  TableColumn,
  FilterState,
  FilterMatcher,
  SortComparator,
} from '$lib/utils/table-utils';
import { normalizeIcon } from '$lib/utils/tree-utils';
import { defaultSortComparator } from '$lib/utils/table-utils';

// ============================================================================
// Types
// ============================================================================

/** Tree node with optional column data (extends base TreeNode). */
export interface TreeTableNode extends TreeNode {
  data?: Record<string, unknown>;
  children: TreeTableNode[];
}

/** A single flattened row for rendering in the table body. */
export interface FlatTreeRow {
  key: string;
  node: TreeTableNode;
  depth: number;
  isFolder: boolean;
  isExpanded: boolean;
  isLast: boolean;
  /** For each ancestor depth, whether a vertical pipe line should be drawn. */
  parentLines: boolean[];
}

// ============================================================================
// Normalization
// ============================================================================

/**
 * Normalize raw MATLAB ic.tree.Node serialization into TreeTableNode[].
 * Like tree-utils normalizeNodes but preserves the `.data` field.
 */
export function normalizeTreeTableNodes(
  raw: unknown,
  prefix = '',
): TreeTableNode[] {
  if (raw == null) return [];
  if (!Array.isArray(raw)) raw = [raw];
  return (raw as Record<string, unknown>[]).map((n, i) => {
    const hasKey = n.key != null && n.key !== '';
    const key = hasKey
      ? String(n.key)
      : prefix
        ? `${prefix}-${i + 1}`
        : `${i + 1}`;
    return {
      key,
      name: String(n.label ?? n.name ?? ''),
      icon: normalizeIcon(n.icon) as IconSource,
      children: normalizeTreeTableNodes(n.children, key),
      data: (n.data != null && typeof n.data === 'object' && !Array.isArray(n.data))
        ? (n.data as Record<string, unknown>)
        : undefined,
    };
  });
}

// ============================================================================
// Flatten visible tree → flat row array
// ============================================================================

/**
 * Flatten a tree into a list of visible rows based on expand state.
 * Folders are always included; their children appear only if expanded.
 */
export function flattenVisible(
  nodes: TreeTableNode[],
  expandedKeys: Set<string>,
  depth = 0,
  parentLines: boolean[] = [],
): FlatTreeRow[] {
  const result: FlatTreeRow[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const node = nodes[i];
    const isLast = i === nodes.length - 1;
    const isFolder = node.children.length > 0;
    const isExpanded = isFolder && expandedKeys.has(node.key);

    result.push({
      key: node.key,
      node,
      depth,
      isFolder,
      isExpanded,
      isLast,
      parentLines: [...parentLines],
    });

    if (isExpanded) {
      const childLines = [...parentLines, !isLast];
      result.push(
        ...flattenVisible(node.children, expandedKeys, depth + 1, childLines),
      );
    }
  }
  return result;
}

// ============================================================================
// Sorting (recursive per-level)
// ============================================================================

/**
 * Get the sortable value for a node given a column field.
 * The expander column uses node.name (Node.Label); other columns use node.data.
 */
function getNodeValue(
  node: TreeTableNode,
  field: string,
  expanderField: string,
): unknown {
  if (field === expanderField) return node.name;
  return node.data?.[field] ?? null;
}

/**
 * Recursively sort children at every level by the given column.
 * Returns a new tree (does not mutate input).
 */
export function sortTreeRecursive(
  nodes: TreeTableNode[],
  field: string,
  direction: 'asc' | 'desc',
  expanderField: string,
  columns: TableColumn[],
  comparators: Record<string, SortComparator>,
): TreeTableNode[] {
  if (!field || direction === 'none') return nodes;

  const col = columns.find((c) => c.field === field);
  const cmpFn = col ? comparators[col.type] ?? null : null;
  const config = col?.config ?? {};

  return nodes
    .map((n) => ({
      ...n,
      children:
        n.children.length > 0
          ? sortTreeRecursive(
              n.children,
              field,
              direction,
              expanderField,
              columns,
              comparators,
            )
          : n.children,
    }))
    .sort((a, b) => {
      const va = getNodeValue(a, field, expanderField);
      const vb = getNodeValue(b, field, expanderField);

      // Nulls to end
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;

      const cmp = cmpFn
        ? cmpFn(va, vb, config)
        : defaultSortComparator(va, vb);
      return direction === 'asc' ? cmp : -cmp;
    });
}

// ============================================================================
// Filtering (tree-aware, bottom-up)
// ============================================================================

/** Test whether a single cell value passes a single filter. */
function cellPassesFilter(
  cellVal: unknown,
  filterVal: unknown,
  col: TableColumn,
  matchers: Record<string, FilterMatcher>,
): boolean {
  // Universal: isEmpty / isNotEmpty
  if (
    typeof filterVal === 'object' &&
    filterVal !== null &&
    !Array.isArray(filterVal)
  ) {
    if ('isEmpty' in (filterVal as Record<string, unknown>))
      return cellVal == null || cellVal === '';
    if ('isNotEmpty' in (filterVal as Record<string, unknown>))
      return cellVal != null && cellVal !== '';
  }
  const matcher = matchers[col.type];
  return !matcher || matcher(cellVal, filterVal);
}

/** Get active filter fields (non-null, non-empty). */
function getActiveFilterFields(filters: FilterState): string[] {
  return Object.keys(filters).filter((f) => {
    const v = filters[f];
    if (v == null || v === '') return false;
    if (
      typeof v === 'object' &&
      'min' in (v as Record<string, unknown>) &&
      (v as Record<string, unknown>).min == null &&
      (v as Record<string, unknown>).max == null
    )
      return false;
    return true;
  });
}

export interface TreeFilterResult {
  /** Filtered tree (only matching leaves + their ancestor folders). */
  filtered: TreeTableNode[];
  /** Per-column match count (how many leaves match each individual filter). */
  matchCounts: Record<string, number>;
  /** Keys of folders that should be auto-expanded to reveal matches. */
  expandKeys: string[];
}

/**
 * Filter a tree by column values. Bottom-up pruning:
 * - Leaf passes if it matches ALL active filters
 * - Folder passes if any descendant passes
 * - Folder keys with matching descendants are collected for auto-expand
 */
export function filterTree(
  nodes: TreeTableNode[],
  filters: FilterState,
  columns: TableColumn[],
  matchers: Record<string, FilterMatcher>,
  expanderField: string,
): TreeFilterResult {
  const activeFields = getActiveFilterFields(filters);
  if (activeFields.length === 0) {
    return { filtered: nodes, matchCounts: {}, expandKeys: [] };
  }

  const colMap = new Map<string, TableColumn>();
  for (const col of columns) colMap.set(col.field, col);

  const counts: Record<string, number> = {};
  for (const f of activeFields) counts[f] = 0;
  const expandKeys: string[] = [];

  function recurse(nodeList: TreeTableNode[]): TreeTableNode[] {
    const kept: TreeTableNode[] = [];

    for (const node of nodeList) {
      const isFolder = node.children.length > 0;

      if (isFolder) {
        // Recurse into children first
        const filteredChildren = recurse(node.children);
        if (filteredChildren.length > 0) {
          kept.push({ ...node, children: filteredChildren });
          expandKeys.push(node.key);
        }
      } else {
        // Leaf: test all active filters
        let passesAll = true;
        for (const field of activeFields) {
          const col = colMap.get(field);
          if (!col) continue;
          const cellVal = getNodeValue(node, field, expanderField);
          const passes = cellPassesFilter(
            cellVal,
            filters[field],
            col,
            matchers,
          );
          if (passes) counts[field]++;
          if (!passes) passesAll = false;
        }
        if (passesAll) {
          kept.push(node);
        }
      }
    }

    return kept;
  }

  const filtered = recurse(nodes);
  return { filtered, matchCounts: counts, expandKeys };
}
