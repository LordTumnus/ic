/**
 * Virtual tree utilities for VirtualTree component.
 *
 * Handles lightweight node stubs (VirtualNode), per-folder child caching,
 * and flattening an expanded tree into a visible FlatRow[] for virtual scrolling.
 *
 * Key design: MATLAB owns the full tree; the frontend only stores stubs
 * (no children arrays). Children are fetched on demand into ChildCache entries.
 */

import type { IconSource } from '$lib/utils/icons';
import { normalizeIcon } from '$lib/utils/tree-utils';

// --- Types ---

/** Lightweight node stub — no children array, just metadata. */
export interface VirtualNode {
  key: string;
  name: string;
  icon?: IconSource;
  isFolder: boolean;
  childCount: number;
}

/** Per-folder child cache (loaded in chunks). */
export interface ChildCache {
  nodes: VirtualNode[];
  loaded: number;
  total: number;
}

/** A single row in the flattened visible list. */
export interface FlatRow {
  node: VirtualNode;
  depth: number;
  isLast: boolean;
  parentLines: boolean[];
  isPlaceholder: boolean;
}

// --- Normalization ---

/** Normalize raw MATLAB VirtualNode serialization into VirtualNode[]. */
export function normalizeVirtualNodes(raw: unknown): VirtualNode[] {
  if (raw == null) return [];
  if (!Array.isArray(raw)) raw = [raw];
  return (raw as Record<string, unknown>[]).map((n) => ({
    key: String(n.key ?? ''),
    name: String(n.name ?? ''),
    icon: normalizeIcon(n.icon),
    isFolder: Boolean(n.isFolder),
    childCount: Number(n.childCount ?? 0),
  }));
}

// --- Placeholder factory ---

function makePlaceholder(key: string, depth: number, isLast: boolean, parentLines: boolean[]): FlatRow {
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
 * Flatten the expanded tree into FlatRow[] using cached children.
 *
 * DFS walk — only traverses expanded branches. For expanded folders whose
 * children haven't been fully loaded, emits placeholder rows for the
 * unloaded range. Collapsed folders are skipped entirely.
 *
 * Complexity: O(visible rows), not O(total tree size).
 */
export function flattenVisible(
  roots: VirtualNode[],
  expandedKeys: Set<string>,
  childCaches: Map<string, ChildCache>,
  showLine: boolean
): FlatRow[] {
  const rows: FlatRow[] = [];

  function walk(
    nodes: VirtualNode[],
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

      // If expanded folder, walk its cached children
      if (node.isFolder && expandedKeys.has(node.key)) {
        const cache = childCaches.get(node.key);
        const childLines = showLine ? [...parentLines, !isLast] : [];

        if (cache && cache.loaded > 0) {
          // Walk loaded children
          const loaded = cache.nodes.slice(0, cache.loaded);
          walk(loaded, depth + 1, childLines);

          // Emit placeholders for unloaded children
          for (let j = cache.loaded; j < cache.total; j++) {
            const pKey = `${node.key}-${j + 1}`;
            const pIsLast = j === cache.total - 1;
            rows.push(makePlaceholder(pKey, depth + 1, pIsLast, childLines));
          }
        } else {
          // No cache yet — emit placeholders for all children
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
 * Each node contributes 1 row. Expanded folders additionally contribute
 * their children's subtree sizes (recursive). Collapsed folders contribute
 * just 1 row regardless of how many descendants they have.
 *
 * For expanded folders with unloaded children, each unloaded child
 * contributes 1 (leaf assumption since we don't know their subtree).
 */
export function computeTotalRows(
  roots: VirtualNode[],
  expandedKeys: Set<string>,
  childCaches: Map<string, ChildCache>
): number {
  function countSubtree(nodes: VirtualNode[]): number {
    let count = 0;
    for (const node of nodes) {
      count += 1; // the node itself
      if (node.isFolder && expandedKeys.has(node.key)) {
        const cache = childCaches.get(node.key);
        if (cache && cache.loaded > 0) {
          // Loaded children: recurse
          count += countSubtree(cache.nodes.slice(0, cache.loaded));
          // Unloaded children: 1 each (leaf assumption)
          count += cache.total - cache.loaded;
        } else {
          // No cache: all children as placeholders
          count += node.childCount;
        }
      }
    }
    return count;
  }

  return countSubtree(roots);
}
