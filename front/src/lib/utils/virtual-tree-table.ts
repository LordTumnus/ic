/**
 * Virtual tree table utilities for VirtualTreeTable component.
 *
 * Combines VirtualTree's pull-based node stubs with TreeTable's column data.
 * Each leaf stub carries a `data` field with column values; folder stubs do not.
 *
 * MATLAB owns the full tree and performs sort/filter server-side.
 * The frontend requests chunks on demand and caches them per-folder.
 */

import type { IconSource } from '$lib/utils/icons';
import { normalizeIcon } from '$lib/utils/tree-utils';

// --- Types ---

/** Virtual tree table node stub — lightweight, no children array. */
export interface VirtualTreeTableNode {
  key: string;
  name: string;
  icon?: IconSource;
  isFolder: boolean;
  childCount: number;
  /** Column data for leaf nodes (folders have no data). */
  data?: Record<string, unknown>;
}

/** Per-folder child cache (loaded in chunks). */
export interface VttChildCache {
  nodes: VirtualTreeTableNode[];
  loaded: number;
  total: number;
}

/** A single row in the flattened visible list. */
export interface VttFlatRow {
  node: VirtualTreeTableNode;
  depth: number;
  isLast: boolean;
  parentLines: boolean[];
  isPlaceholder: boolean;
}

// --- Normalization ---

/** Normalize raw MATLAB stubs into VirtualTreeTableNode[]. */
export function normalizeVttNodes(raw: unknown): VirtualTreeTableNode[] {
  if (raw == null) return [];
  if (!Array.isArray(raw)) raw = [raw];
  return (raw as Record<string, unknown>[]).map((n) => ({
    key: String(n.key ?? ''),
    name: String(n.name ?? ''),
    icon: normalizeIcon(n.icon),
    isFolder: Boolean(n.isFolder),
    childCount: Number(n.childCount ?? 0),
    data:
      n.data != null && typeof n.data === 'object' && !Array.isArray(n.data)
        ? (n.data as Record<string, unknown>)
        : undefined,
  }));
}

// --- Placeholder factory ---

function makePlaceholder(
  key: string,
  depth: number,
  isLast: boolean,
  parentLines: boolean[]
): VttFlatRow {
  return {
    node: { key, name: '', icon: undefined, isFolder: false, childCount: 0 },
    depth,
    isLast,
    parentLines,
    isPlaceholder: true,
  };
}

// --- Flatten visible tree ---

/**
 * Flatten the expanded tree into VttFlatRow[] using cached children.
 *
 * DFS walk — only traverses expanded branches. Emits placeholder rows
 * for unloaded ranges. Collapsed folders are skipped entirely.
 *
 * Complexity: O(visible rows), not O(total tree size).
 */
export function flattenVisible(
  roots: VirtualTreeTableNode[],
  expandedKeys: Set<string>,
  childCaches: Map<string, VttChildCache>,
  showLine: boolean
): VttFlatRow[] {
  const rows: VttFlatRow[] = [];

  function walk(
    nodes: VirtualTreeTableNode[],
    depth: number,
    parentLines: boolean[]
  ) {
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      const isLast = i === nodes.length - 1;

      rows.push({
        node,
        depth,
        isLast,
        parentLines: [...parentLines],
        isPlaceholder: false,
      });

      if (node.isFolder && expandedKeys.has(node.key)) {
        const cache = childCaches.get(node.key);
        const childLines = showLine ? [...parentLines, !isLast] : [];

        if (cache && cache.loaded > 0) {
          const loaded = cache.nodes.slice(0, cache.loaded);
          walk(loaded, depth + 1, childLines);

          for (let j = cache.loaded; j < cache.total; j++) {
            const pKey = `${node.key}-${j + 1}`;
            const pIsLast = j === cache.total - 1;
            rows.push(makePlaceholder(pKey, depth + 1, pIsLast, childLines));
          }
        } else {
          for (let j = 0; j < node.childCount; j++) {
            const pKey = `${node.key}-${j + 1}`;
            const pIsLast = j === node.childCount - 1;
            rows.push(makePlaceholder(pKey, depth + 1, pIsLast, childLines));
          }
        }
      }
    }
  }

  walk(roots, 0, []);
  return rows;
}

// --- Total row count ---

/**
 * Compute total visible row count for scrollbar sizing.
 *
 * Each node = 1 row. Expanded folders additionally contribute their
 * children's subtree sizes (recursive). Unloaded children = 1 each.
 */
export function computeTotalRows(
  roots: VirtualTreeTableNode[],
  expandedKeys: Set<string>,
  childCaches: Map<string, VttChildCache>
): number {
  function countSubtree(nodes: VirtualTreeTableNode[]): number {
    let count = 0;
    for (const node of nodes) {
      count += 1;
      if (node.isFolder && expandedKeys.has(node.key)) {
        const cache = childCaches.get(node.key);
        if (cache && cache.loaded > 0) {
          count += countSubtree(cache.nodes.slice(0, cache.loaded));
          count += cache.total - cache.loaded;
        } else {
          count += node.childCount;
        }
      }
    }
    return count;
  }

  return countSubtree(roots);
}
