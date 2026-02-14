/**
 * Shared filter-tree utilities for FilterTree and VirtualFilterTree.
 *
 * Provides filter-tag parsing, node matching, and tree pruning
 * using the prefix-based operator system (SearchBar IconTriggers).
 *
 * Operators:
 *   (none) = contains (AND)    | = OR    ~ = NOT
 *   : = folder-only    @ = leaf-only    = = exact
 *   / = ancestor path    ^ = starts-with
 */

import type { TreeNode } from '$lib/utils/tree-utils';

// --- Types ---

/** Grouped filters by operator for efficient matching. */
export interface FilterGroups {
  /** Plain "contains" tags (AND) */
  contains: string[];
  /** '|' OR tags (ANY must match) */
  or: string[];
  /** '~' NOT tags (NONE must match) */
  not: string[];
  /** ':' Folder-only tags (AND, substring) */
  folder: string[];
  /** '@' Leaf-only tags (AND, substring) */
  leaf: string[];
  /** '=' Exact name tags (AND) */
  exact: string[];
  /** '/' Path tags (AND, substring in ancestor path) */
  path: string[];
  /** '^' Starts-with tags (AND) */
  starts: string[];
}

// --- Constants ---

/** Hardcoded prefix-to-icon mapping for the filter language. */
export const FILTER_TRIGGERS: Record<string, string> = {
  '|': 'split',
  '~': 'ban',
  ':': 'folder',
  '@': 'file',
  '=': 'equal',
  '/': 'route',
  '^': 'text-cursor-input',
};

/** All known operator prefixes, sorted longest-first. */
const OPERATOR_PREFIXES = Object.keys(FILTER_TRIGGERS).sort(
  (a, b) => b.length - a.length
);

/** Map from prefix character to FilterGroups field name. */
const PREFIX_TO_GROUP: Record<string, keyof FilterGroups> = {
  '|': 'or',
  '~': 'not',
  ':': 'folder',
  '@': 'leaf',
  '=': 'exact',
  '/': 'path',
  '^': 'starts',
};

// --- Parsing ---

/**
 * Parse an array of tag strings into grouped filters.
 *
 * Each tag may start with an operator prefix (|, ~, :, @, =, /, ^).
 * Tags without a recognized prefix are plain "contains" filters.
 */
export function parseFilters(tags: string[]): FilterGroups {
  const groups: FilterGroups = {
    contains: [],
    or: [],
    not: [],
    folder: [],
    leaf: [],
    exact: [],
    path: [],
    starts: [],
  };

  for (const raw of tags) {
    let matched = false;
    for (const prefix of OPERATOR_PREFIXES) {
      if (raw.startsWith(prefix)) {
        const term = raw.slice(prefix.length).trim();
        if (!term) continue;
        const group = PREFIX_TO_GROUP[prefix];
        if (group) groups[group].push(term);
        matched = true;
        break;
      }
    }
    if (!matched) {
      const term = raw.trim();
      if (term) groups.contains.push(term);
    }
  }

  return groups;
}

/** Returns true if the FilterGroups has no active filters. */
export function isEmptyFilter(groups: FilterGroups): boolean {
  return (
    groups.contains.length === 0 &&
    groups.or.length === 0 &&
    groups.not.length === 0 &&
    groups.folder.length === 0 &&
    groups.leaf.length === 0 &&
    groups.exact.length === 0 &&
    groups.path.length === 0 &&
    groups.starts.length === 0
  );
}

// --- Node matching ---

/**
 * Test whether a single node matches the filter groups.
 *
 * @param name          The node's display name
 * @param isFolder      Whether the node has children
 * @param ancestorPath  Array of ancestor names from root to parent (exclusive of self)
 * @param groups        The parsed filter groups
 * @param caseSensitive Whether matching is case-sensitive
 */
export function matchNode(
  name: string,
  isFolder: boolean,
  ancestorPath: string[],
  groups: FilterGroups,
  caseSensitive: boolean
): boolean {
  const n = caseSensitive ? name : name.toLowerCase();
  const norm = (s: string) => (caseSensitive ? s : s.toLowerCase());

  // ALL plain tags must match (AND, substring)
  for (const t of groups.contains) {
    if (!n.includes(norm(t))) return false;
  }

  // ALL ':' tags: must be folder AND name contains term
  for (const t of groups.folder) {
    if (!isFolder || !n.includes(norm(t))) return false;
  }

  // ALL '@' tags: must be leaf AND name contains term
  for (const t of groups.leaf) {
    if (isFolder || !n.includes(norm(t))) return false;
  }

  // ALL '=' tags: name must exactly equal term
  for (const t of groups.exact) {
    if (n !== norm(t)) return false;
  }

  // ALL '^' tags: name must start with term
  for (const t of groups.starts) {
    if (!n.startsWith(norm(t))) return false;
  }

  // ALL '/' tags: ancestor path must contain term
  for (const t of groups.path) {
    const nt = norm(t);
    if (!ancestorPath.some((a) => (caseSensitive ? a : a.toLowerCase()).includes(nt))) {
      return false;
    }
  }

  // ANY '|' tag must match (OR, substring)
  if (groups.or.length > 0) {
    if (!groups.or.some((t) => n.includes(norm(t)))) return false;
  }

  // NO '~' tag must match (NOT, substring)
  for (const t of groups.not) {
    if (n.includes(norm(t))) return false;
  }

  return true;
}

// --- Tree filtering ---

/**
 * Filter a normalized tree, preserving keys and ancestor chains.
 *
 * DFS walk: a node is included if it matches OR if any descendant matches
 * (to preserve tree structure). Keys are preserved from the input.
 *
 * @returns A new tree containing only matching nodes + their ancestors.
 */
export function filterTree(
  nodes: TreeNode[],
  groups: FilterGroups,
  caseSensitive: boolean,
  ancestorPath: string[] = []
): TreeNode[] {
  const result: TreeNode[] = [];

  for (const node of nodes) {
    const isFolder = node.children.length > 0;

    const selfMatches = matchNode(
      node.name,
      isFolder,
      ancestorPath,
      groups,
      caseSensitive
    );

    // When a folder self-matches, keep ALL its children (user searched for this folder).
    // When it doesn't, recurse to find matching descendants.
    const childrenToKeep = isFolder
      ? selfMatches
        ? node.children
        : filterTree(node.children, groups, caseSensitive, [
            ...ancestorPath,
            node.name,
          ])
      : [];

    // Include node if it matches OR if any child survived filtering
    if (selfMatches || childrenToKeep.length > 0) {
      result.push({
        key: node.key,
        name: node.name,
        icon: node.icon,
        children: childrenToKeep,
      });
    }
  }

  return result;
}

/**
 * Collect the keys of all folder ancestors that lead to matching nodes.
 * Used for auto-expanding when a filter is active.
 */
export function getMatchingAncestorKeys(
  nodes: TreeNode[],
  groups: FilterGroups,
  caseSensitive: boolean,
  ancestorPath: string[] = [],
  ancestorKeys: string[] = []
): Set<string> {
  const result = new Set<string>();

  for (const node of nodes) {
    const isFolder = node.children.length > 0;
    const selfMatches = matchNode(
      node.name,
      isFolder,
      ancestorPath,
      groups,
      caseSensitive
    );

    if (selfMatches) {
      for (const ak of ancestorKeys) result.add(ak);
    }

    if (isFolder) {
      const childResult = getMatchingAncestorKeys(
        node.children,
        groups,
        caseSensitive,
        [...ancestorPath, node.name],
        [...ancestorKeys, node.key]
      );
      for (const k of childResult) result.add(k);
    }
  }

  return result;
}

// --- Highlight helpers ---

/** A text segment — either plain or highlighted. */
export interface HighlightSegment {
  text: string;
  highlight: boolean;
}

const escRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Build a position-aware highlight regex from filter groups.
 *
 * - contains / or → plain substring match
 * - starts → anchored to start of label (`^term`)
 * - exact → anchored to full label (`^term$`)
 * - folder / leaf → excluded (structural filters, not text searches)
 * - path / not → excluded (path matches ancestors, not matches exclusions)
 */
export function buildHighlightRegex(
  groups: FilterGroups,
  caseSensitive: boolean
): RegExp | null {
  const patterns: string[] = [];

  // Substring operators — match anywhere in the label
  for (const t of [...groups.contains, ...groups.or]) {
    if (t) patterns.push(escRe(t));
  }

  // Starts-with — anchor to start
  for (const t of groups.starts) {
    if (t) patterns.push(`^${escRe(t)}`);
  }

  // Exact — anchor to full label
  for (const t of groups.exact) {
    if (t) patterns.push(`^${escRe(t)}$`);
  }

  if (!patterns.length) return null;

  const flags = caseSensitive ? 'g' : 'gi';
  return new RegExp(`(${patterns.join('|')})`, flags);
}

/**
 * Split a label into highlighted and plain segments.
 *
 * @param label  The node's display name
 * @param re     A highlight regex (from buildHighlightRegex)
 * @returns Array of segments; if no matches, returns a single plain segment
 */
export function highlightLabel(
  label: string,
  re: RegExp
): HighlightSegment[] {
  if (!label) return [{ text: label, highlight: false }];

  // Reset lastIndex in case the regex was used before
  re.lastIndex = 0;

  const segments: HighlightSegment[] = [];
  let lastIndex = 0;

  for (const m of label.matchAll(re)) {
    const start = m.index!;
    if (start > lastIndex) {
      segments.push({ text: label.slice(lastIndex, start), highlight: false });
    }
    segments.push({ text: m[0], highlight: true });
    lastIndex = start + m[0].length;
  }

  if (lastIndex < label.length) {
    segments.push({ text: label.slice(lastIndex), highlight: false });
  }

  return segments.length > 0 ? segments : [{ text: label, highlight: false }];
}
