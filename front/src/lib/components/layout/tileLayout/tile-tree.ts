/**
 * tile-tree.ts — Pure functions for manipulating the binary split tree.
 *
 * Every function returns a NEW tree (immutable-style) so Svelte's
 * reactivity picks up the change via reassignment.
 */

import type { TileNode, TileSplit, TileLeaf, DropZone } from './tile-types';

let nextId = 0;
export function genId(prefix = 'tl'): string {
	return `${prefix}-${nextId++}`;
}

/** Reset the ID counter (useful for tests). */
export function resetIdCounter(): void {
	nextId = 0;
}

// --- Finders ---

/** Find the leaf that contains a given tab target. */
export function findLeafByTab(node: TileNode, tabTarget: string): TileLeaf | null {
	if (node.type === 'leaf') {
		return node.tabs.includes(tabTarget) ? node : null;
	}
	return findLeafByTab(node.children[0], tabTarget) ?? findLeafByTab(node.children[1], tabTarget);
}

/** Find a leaf by its ID. */
export function findLeafById(node: TileNode, leafId: string): TileLeaf | null {
	if (node.type === 'leaf') {
		return node.id === leafId ? node : null;
	}
	return findLeafById(node.children[0], leafId) ?? findLeafById(node.children[1], leafId);
}

/** Find a split node by its ID. */
export function findSplitById(node: TileNode, splitId: string): TileSplit | null {
	if (node.type === 'leaf') return null;
	if (node.id === splitId) return node;
	return findSplitById(node.children[0], splitId) ?? findSplitById(node.children[1], splitId);
}

/** Collect all leaf nodes. */
export function collectLeaves(node: TileNode): TileLeaf[] {
	if (node.type === 'leaf') return [node];
	return [...collectLeaves(node.children[0]), ...collectLeaves(node.children[1])];
}

/** Collect all tab targets across the entire tree. */
export function collectAllTabs(node: TileNode): string[] {
	return collectLeaves(node).flatMap((leaf) => leaf.tabs);
}

// --- Mutators (return new tree) ---

/**
 * Add a tab to a leaf. Returns a new tree.
 * If `index` is omitted, appends to the end.
 */
export function addTabToLeaf(
	tree: TileNode,
	leafId: string,
	tabTarget: string,
	index?: number
): TileNode {
	return mapLeaf(tree, leafId, (leaf) => {
		const tabs = [...leaf.tabs];
		const i = index ?? tabs.length;
		tabs.splice(i, 0, tabTarget);
		return { ...leaf, tabs, selectedTab: tabTarget };
	});
}

/**
 * Remove a tab from a leaf. Returns a new tree.
 * Does NOT prune empty leaves — call prune() afterwards.
 */
export function removeTabFromLeaf(tree: TileNode, leafId: string, tabTarget: string): TileNode {
	return mapLeaf(tree, leafId, (leaf) => {
		const oldIndex = leaf.tabs.indexOf(tabTarget);
		const tabs = leaf.tabs.filter((t) => t !== tabTarget);
		// Select previous tab (or first if closing the first tab)
		const selectedTab =
			leaf.selectedTab === tabTarget
				? (tabs[Math.max(0, oldIndex - 1)] ?? '')
				: leaf.selectedTab;
		return { ...leaf, tabs, selectedTab };
	});
}

/**
 * Move a tab from one leaf to another. Returns a new tree.
 * Prunes the source leaf if it becomes empty.
 */
export function moveTab(
	tree: TileNode,
	fromLeafId: string,
	toLeafId: string,
	tabTarget: string,
	index?: number
): TileNode {
	let result = removeTabFromLeaf(tree, fromLeafId, tabTarget);
	result = addTabToLeaf(result, toLeafId, tabTarget, index);
	result = prune(result);
	return result;
}

/**
 * Split a leaf: replace it with a split node.
 * `position` determines where the new leaf goes relative to the existing one:
 *   top/left  → new leaf is first child
 *   bottom/right → new leaf is second child
 */
export function splitLeaf(
	tree: TileNode,
	leafId: string,
	zone: Exclude<DropZone, 'center'>,
	tabTargets: string[]
): TileNode {
	const direction: 'horizontal' | 'vertical' =
		zone === 'left' || zone === 'right' ? 'horizontal' : 'vertical';
	const newFirst = zone === 'left' || zone === 'top';

	const newLeaf: TileLeaf = {
		type: 'leaf',
		id: genId('leaf'),
		tabs: tabTargets,
		selectedTab: tabTargets[0] ?? ''
	};

	return mapNode(tree, leafId, (existing) => {
		const split: TileSplit = {
			type: 'split',
			id: genId('split'),
			direction,
			ratio: 0.5,
			children: newFirst ? [newLeaf, existing] : [existing, newLeaf]
		};
		return split;
	});
}

/** Update a split's ratio. Returns a new tree. */
export function resizeSplit(tree: TileNode, splitId: string, ratio: number): TileNode {
	if (tree.type === 'leaf') return tree;
	if (tree.id === splitId) {
		return { ...tree, ratio: Math.max(0.1, Math.min(0.9, ratio)) };
	}
	return {
		...tree,
		children: [
			resizeSplit(tree.children[0], splitId, ratio),
			resizeSplit(tree.children[1], splitId, ratio)
		] as [TileNode, TileNode]
	};
}

/**
 * Prune the tree: remove empty leaves and collapse single-child splits.
 * Returns the pruned tree, or null if the entire tree is empty.
 */
export function prune(tree: TileNode): TileNode {
	if (tree.type === 'leaf') return tree;

	const left = prune(tree.children[0]);
	const right = prune(tree.children[1]);

	const leftEmpty = left.type === 'leaf' && left.tabs.length === 0;
	const rightEmpty = right.type === 'leaf' && right.tabs.length === 0;

	if (leftEmpty && rightEmpty) {
		// Both empty — return empty leaf
		return { type: 'leaf', id: left.id, tabs: [], selectedTab: '' };
	}
	if (leftEmpty) return right;
	if (rightEmpty) return left;

	return { ...tree, children: [left, right] as [TileNode, TileNode] };
}

// --- Internal helpers ---

/** Map over a specific leaf by ID, returning a new tree. */
function mapLeaf(tree: TileNode, leafId: string, fn: (leaf: TileLeaf) => TileLeaf): TileNode {
	if (tree.type === 'leaf') {
		return tree.id === leafId ? fn(tree) : tree;
	}
	return {
		...tree,
		children: [
			mapLeaf(tree.children[0], leafId, fn),
			mapLeaf(tree.children[1], leafId, fn)
		] as [TileNode, TileNode]
	};
}

/** Map over any node by ID, allowing type change (leaf → split for splitting). */
function mapNode(tree: TileNode, nodeId: string, fn: (node: TileNode) => TileNode): TileNode {
	if (tree.id === nodeId) return fn(tree);
	if (tree.type === 'leaf') return tree;
	return {
		...tree,
		children: [
			mapNode(tree.children[0], nodeId, fn),
			mapNode(tree.children[1], nodeId, fn)
		] as [TileNode, TileNode]
	};
}
