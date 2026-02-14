/**
 * Shared tree utilities used by TreeSelect, Tree, and future tree-based components.
 *
 * Handles positional key normalization (1, 1-1, 1-2, ...),
 * key-map building, node operations (add/remove/update), and value remapping.
 */

import type { IconTypeData } from '$lib/utils/icons';

// --- Types ---

export interface TreeNode {
  key: string;
  name: string;
  icon?: string | IconTypeData;
  children: TreeNode[];
}

export interface FlatNode {
  key: string;
  name: string;
  icon?: string | IconTypeData;
  path: string[];
}

// --- Normalization ---

/** Normalize raw MATLAB ic.tree.Node serialization into TreeNode[] with positional keys.
 *  If nodes already carry a `key` property (e.g. from filterTree), it is preserved. */
export function normalizeNodes(raw: unknown, prefix = ''): TreeNode[] {
  if (raw == null) return [];
  if (!Array.isArray(raw)) raw = [raw];
  return (raw as Record<string, unknown>[]).map((n, i) => {
    const hasKey = n.key != null && n.key !== '';
    const key = hasKey ? String(n.key) : (prefix ? `${prefix}-${i + 1}` : `${i + 1}`);
    return {
      key,
      name: String(n.label ?? n.name ?? ''),
      icon: normalizeIcon(n.icon),
      children: normalizeNodes(n.children, key),
    };
  });
}

export function normalizeIcon(raw: unknown): string | IconTypeData | undefined {
  if (raw == null) return undefined;
  if (typeof raw === 'string') return raw || undefined;
  if (typeof raw === 'object' && 'type' in (raw as object))
    return raw as IconTypeData;
  return undefined;
}

// --- Key map ---

/** Build a Map<key, {name, icon}> for O(1) label/icon lookup from positional key. */
export function buildKeyMap(
  nodes: TreeNode[]
): Map<string, { name: string; icon?: string | IconTypeData }> {
  const map = new Map<string, { name: string; icon?: string | IconTypeData }>();
  function walk(list: TreeNode[]) {
    for (const n of list) {
      map.set(n.key, { name: n.name, icon: n.icon });
      if (n.children.length > 0) walk(n.children);
    }
  }
  walk(nodes);
  return map;
}

// --- Flatten ---

/** Flatten tree to leaf nodes only (folders excluded), with breadcrumb path. */
export function flattenLeaves(nodes: TreeNode[], path: string[] = []): FlatNode[] {
  const out: FlatNode[] = [];
  for (const n of nodes) {
    if (n.children.length > 0) {
      out.push(...flattenLeaves(n.children, [...path, n.name]));
    } else {
      out.push({ key: n.key, name: n.name, icon: n.icon, path });
    }
  }
  return out;
}

// --- Node lookup ---

/** Find a node by positional key in a tree. */
export function findNodeByKey(nodes: TreeNode[], key: string): TreeNode | null {
  for (const n of nodes) {
    if (n.key === key) return n;
    const found = findNodeByKey(n.children, key);
    if (found) return found;
  }
  return null;
}

/** Collect all keys (self + descendants) for a node. */
export function collectAllKeys(node: TreeNode): string[] {
  const keys = [node.key];
  for (const c of node.children) keys.push(...collectAllKeys(c));
  return keys;
}

/** Collect all keys of folder nodes (nodes with children). */
export function collectAllFolderKeys(nodes: TreeNode[]): string[] {
  const keys: string[] = [];
  for (const n of nodes) {
    if (n.children.length > 0) {
      keys.push(n.key);
      keys.push(...collectAllFolderKeys(n.children));
    }
  }
  return keys;
}

/** Get all leaf keys under a node. */
export function getAllLeaves(node: TreeNode): string[] {
  if (!node.children?.length) return [node.key];
  return node.children.flatMap((c) => getAllLeaves(c));
}

// --- Reindexing ---

/** Reindex a subtree after removal (assign new positional key to node + children). */
export function reindexSubtree(node: TreeNode, newKey: string): TreeNode {
  return {
    ...node,
    key: newKey,
    children: node.children.map((c, i) =>
      reindexSubtree(c, `${newKey}-${i + 1}`)
    ),
  };
}

/** Map old keys to new keys for shifted siblings after removal. */
export function mapShiftedKeys(
  oldNode: TreeNode,
  newNode: TreeNode,
  mapping: Map<string, string>
) {
  if (oldNode.key !== newNode.key) mapping.set(oldNode.key, newNode.key);
  for (let i = 0; i < oldNode.children.length; i++) {
    mapShiftedKeys(oldNode.children[i], newNode.children[i], mapping);
  }
}

/** Remove a node by key and reindex remaining siblings. */
export function removeAndReindex(
  nodes: TreeNode[],
  key: string
): { updated: TreeNode[]; removedKeys: Set<string>; keyMapping: Map<string, string> } {
  const parts = key.split('-');
  const removedKeys = new Set<string>();
  const keyMapping = new Map<string, string>();

  function recurse(list: TreeNode[], depth: number, prefix: string): TreeNode[] {
    const targetIdx = parseInt(parts[depth], 10) - 1;
    if (depth === parts.length - 1) {
      const removed = list[targetIdx];
      if (removed) {
        for (const k of collectAllKeys(removed)) removedKeys.add(k);
      }
      const after = [...list.slice(0, targetIdx), ...list.slice(targetIdx + 1)];
      return after.map((n, i) => {
        const newKey = prefix ? `${prefix}-${i + 1}` : `${i + 1}`;
        if (n.key !== newKey) {
          const reindexed = reindexSubtree(n, newKey);
          mapShiftedKeys(n, reindexed, keyMapping);
          return reindexed;
        }
        return n;
      });
    }
    return list.map((n, i) => {
      if (i === targetIdx) {
        return { ...n, children: recurse(n.children, depth + 1, n.key) };
      }
      return n;
    });
  }

  const updated = recurse(nodes, 0, '');
  return { updated, removedKeys, keyMapping };
}

/** Remap value keys after a node removal (filter removed + remap shifted). */
export function remapValues(
  vals: string[],
  removedKeys: Set<string>,
  keyMapping: Map<string, string>
): string[] {
  return vals
    .filter((v) => !removedKeys.has(v))
    .map((v) => keyMapping.get(v) ?? v);
}
