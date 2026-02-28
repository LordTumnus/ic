<!--
  DomPanel.svelte — DOM inspector panel for DeveloperTools.

  Top: expandable/collapsible DOM tree with Chrome DevTools-style rendering.
  Bottom: CSS rules for the selected element.
  Toolbar: element picker toggle + refresh button.

  Zero $effect usage — everything is driven by event handlers and onMount.
  Communication with the preview pane uses:
    - onhover callback (parent shows/hides highlight overlay imperatively)
    - reveal bindable method (parent calls to reveal a picker-selected element)
    - pickerActive bindable (simple boolean toggle)
-->
<script lang="ts">
	import { onMount } from 'svelte';
	import type { ComponentInfo, DomNode } from '../devtools-types';
	import {
		buildDomTree,
		findAncestorIds,
		type DomTreeResult
	} from './dom/dom-utils';
	import DomTreeNode from './dom/DomTreeNode.svelte';
	import DomElementStyles from './dom/DomElementStyles.svelte';

	let {
		componentInfo,
		onhover,
		pickerActive = $bindable(false),
		reveal = $bindable(doReveal)
	}: {
		componentInfo: ComponentInfo;
		onhover?: (el: Element | null) => void;
		pickerActive?: boolean;
		reveal?: (el: Element) => void;
	} = $props();

	// --- DOM tree state ---

	let treeResult = $state<DomTreeResult>({ tree: [], elementMap: new Map() });
	let expandedKeys = $state(new Set<string>());
	let selectedNodeId = $state<string | null>(null);
	let selectedNodeElement = $state<Element | null>(null);

	// Build tree once on mount + push doReveal to parent via binding
	onMount(() => {
		reveal = doReveal;
		refresh();
	});

	function refresh() {
		const wrapper = document.getElementById(componentInfo.componentId);
		if (!wrapper) return;
		const result = buildDomTree(wrapper);
		const keys = new Set<string>();
		for (const node of result.tree) {
			keys.add(node.id);
		}
		treeResult = result;
		expandedKeys = keys;
	}

	/** Reveal a DOM element in the tree — called imperatively by parent (picker). */
	function doReveal(el: Element) {
		const node = treeResult.elementMap.get(el);
		if (!node) return;

		const ancestors = findAncestorIds(node.id);
		const newKeys = new Set(expandedKeys);
		for (const aid of ancestors) {
			newKeys.add(aid);
		}
		expandedKeys = newKeys;
		selectedNodeId = node.id;
		selectedNodeElement = el;

		requestAnimationFrame(() => {
			const row = treeEl?.querySelector(`[data-node-id="${node.id}"]`);
			row?.scrollIntoView({ block: 'nearest' });
		});
	}

	// --- Tree interaction callbacks ---

	function handleExpand(id: string) {
		if (expandedKeys.has(id)) {
			expandedKeys.delete(id);
		} else {
			expandedKeys.add(id);
		}
		expandedKeys = new Set(expandedKeys);
	}

	function handleSelect(node: DomNode) {
		selectedNodeId = node.id;
		selectedNodeElement = (node.element as Element) ?? null;
	}

	function handleNodeHover(node: DomNode) {
		if (node.element && node.nodeType === 1) {
			onhover?.(node.element as Element);
		}
	}

	function handleNodeHoverEnd() {
		onhover?.(null);
	}

	// --- Resizable vertical split ---

	let containerEl: HTMLElement | undefined;
	let treeEl: HTMLElement | undefined;
	let vertSplit = $state(60);
	let draggingGutter = $state(false);

	function handleGutterDown(e: MouseEvent) {
		e.preventDefault();
		draggingGutter = true;
		document.addEventListener('mousemove', handleGutterMove);
		document.addEventListener('mouseup', handleGutterUp);
	}

	function handleGutterMove(e: MouseEvent) {
		if (!draggingGutter || !containerEl) return;
		const rect = containerEl.getBoundingClientRect();
		const pct = ((e.clientY - rect.top) / rect.height) * 100;
		vertSplit = Math.max(20, Math.min(80, pct));
	}

	function handleGutterUp() {
		draggingGutter = false;
		document.removeEventListener('mousemove', handleGutterMove);
		document.removeEventListener('mouseup', handleGutterUp);
	}
</script>

<div
	class="ic-dt-dom"
	class:ic-dt-dom--dragging={draggingGutter}
>
	<!-- Toolbar -->
	<div class="ic-dt-dom__toolbar">
		<button
			class="ic-dt-dom__pick-btn"
			class:ic-dt-dom__pick-btn--active={pickerActive}
			onclick={() => (pickerActive = !pickerActive)}
			title="Pick an element from the preview"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<circle cx="12" cy="12" r="10" />
				<line x1="12" y1="2" x2="12" y2="6" />
				<line x1="12" y1="18" x2="12" y2="22" />
				<line x1="2" y1="12" x2="6" y2="12" />
				<line x1="18" y1="12" x2="22" y2="12" />
			</svg>
		</button>

		<button class="ic-dt-dom__refresh-btn" onclick={refresh} title="Refresh DOM tree">
			Refresh
		</button>
	</div>

	<!-- Resizable area (flex:1 fills space after toolbar) -->
	<div class="ic-dt-dom__split" bind:this={containerEl}>
		<!-- Top: DOM tree -->
		<div class="ic-dt-dom__tree" style="height: {vertSplit}%;" bind:this={treeEl}>
			<div class="ic-dt-dom__tree-scroll" role="tree">
				{#if treeResult.tree.length > 0}
					{#each treeResult.tree as node (node.id)}
						<DomTreeNode
							{node}
							depth={0}
							{expandedKeys}
							{selectedNodeId}
							onexpand={handleExpand}
							onselect={handleSelect}
							onhover={handleNodeHover}
							onhoverend={handleNodeHoverEnd}
						/>
					{/each}
				{:else}
					<div class="ic-dt-dom__empty">No DOM nodes found</div>
				{/if}
			</div>
		</div>

		<!-- Horizontal gutter -->
		<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
		<div
			class="ic-dt-dom__gutter"
			onmousedown={handleGutterDown}
			role="separator"
			aria-orientation="vertical"
		></div>

		<!-- Bottom: Selected element styles -->
		<div class="ic-dt-dom__styles" style="height: {100 - vertSplit}%;">
			{#if selectedNodeElement}
				<DomElementStyles element={selectedNodeElement} />
			{:else}
				<div class="ic-dt-dom__no-selection">Select an element to view its styles</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.ic-dt-dom {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
		font-family: var(--ic-font-family);
	}

	.ic-dt-dom--dragging {
		cursor: row-resize;
		user-select: none;
	}

	/* --- Toolbar --- */

	.ic-dt-dom__toolbar {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 4px 10px;
		border-bottom: 1px solid var(--ic-border);
		background: var(--ic-secondary);
		flex-shrink: 0;
	}

	.ic-dt-dom__pick-btn {
		all: unset;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		border-radius: 2px;
		color: var(--ic-muted-foreground);
		border: 1px solid transparent;
	}

	.ic-dt-dom__pick-btn:hover {
		color: var(--ic-foreground);
		background: rgba(128, 128, 128, 0.1);
	}

	.ic-dt-dom__pick-btn--active {
		color: var(--ic-primary);
		background: rgba(66, 133, 244, 0.12);
		border-color: var(--ic-primary);
	}

	.ic-dt-dom__refresh-btn {
		all: unset;
		cursor: pointer;
		padding: 2px 8px;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-muted-foreground);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		background: var(--ic-secondary);
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
	}

	.ic-dt-dom__refresh-btn:hover {
		color: var(--ic-foreground);
		border-color: var(--ic-muted-foreground);
	}

	/* --- Split area (fills space after toolbar) --- */

	.ic-dt-dom__split {
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	/* --- Tree pane --- */

	.ic-dt-dom__tree {
		overflow: auto;
		flex-shrink: 0;
	}

	.ic-dt-dom__tree-scroll {
		padding: 4px 0;
		min-width: max-content;
	}

	.ic-dt-dom__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}

	/* --- Horizontal gutter --- */

	.ic-dt-dom__gutter {
		flex: 0 0 4px;
		background: var(--ic-secondary);
		cursor: row-resize;
		position: relative;
		box-shadow:
			inset 0 1px 0 rgba(255, 255, 255, 0.04),
			inset 0 -1px 0 rgba(0, 0, 0, 0.15);
	}

	.ic-dt-dom__gutter::before {
		content: '';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		height: 60%;
		width: 24px;
		opacity: 0.35;
		background-image: repeating-linear-gradient(
			to right,
			var(--ic-muted-foreground) 0px,
			var(--ic-muted-foreground) 1px,
			transparent 1px,
			transparent 4px
		);
	}

	.ic-dt-dom__gutter:hover::before {
		opacity: 0.55;
	}

	/* --- Styles pane --- */

	.ic-dt-dom__styles {
		overflow: auto;
		flex-shrink: 0;
		border-top: 1px solid var(--ic-border);
	}

	.ic-dt-dom__no-selection {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}
</style>
