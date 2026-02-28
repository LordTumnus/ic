<!--
  DomTreeNode.svelte — Recursive DOM tree node renderer.

  Renders DOM nodes in Chrome DevTools Elements-panel style:
    ▼ <div class="ic-button">
        <span class="ic-button__label">
          "Click me"
        </span>
      </div>

  Color-coded: tag names (warm red), attr names (orange), attr values (teal).
  Supports expand/collapse, selection, and hover-to-highlight.
-->
<script lang="ts">
	import type { DomNode } from '../../devtools-types';
	import DomTreeNode from './DomTreeNode.svelte';

	let {
		node,
		depth = 0,
		expandedKeys,
		selectedNodeId,
		onexpand,
		onselect,
		onhover,
		onhoverend
	}: {
		node: DomNode;
		depth?: number;
		expandedKeys: Set<string>;
		selectedNodeId: string | null;
		onexpand: (id: string) => void;
		onselect: (node: DomNode) => void;
		onhover: (node: DomNode) => void;
		onhoverend: () => void;
	} = $props();

	const isExpanded = $derived(expandedKeys.has(node.id));
	const isSelected = $derived(selectedNodeId === node.id);
	const indent = $derived(depth * 16);

	/** Check if this element has a single text child only (render inline). */
	const inlineText = $derived.by(() => {
		if (node.nodeType !== 1) return null;
		if (node.children.length === 1 && node.children[0].nodeType === 3) {
			const text = node.children[0].textContent ?? '';
			if (text.length <= 80) return text;
		}
		return null;
	});

	function handleToggle(e: MouseEvent) {
		e.stopPropagation();
		onexpand(node.id);
	}

	function handleRowKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			onselect(node);
		} else if (e.key === 'ArrowRight' && node.hasChildren && !isExpanded) {
			onexpand(node.id);
		} else if (e.key === 'ArrowLeft' && isExpanded) {
			onexpand(node.id);
		}
	}
</script>

{#if node.nodeType === 3}
	<!-- Text node -->
	<div
		class="ic-dt-dom-n__row ic-dt-dom-n__text"
		style="padding-left: {indent}px"
	>
		"{node.textContent}"
	</div>
{:else}
	<!-- Element node: opening tag row -->
	<div
		class="ic-dt-dom-n__row"
		class:ic-dt-dom-n__row--selected={isSelected}
		style="padding-left: {indent}px"
		data-node-id={node.id}
		onclick={() => onselect(node)}
		onkeydown={handleRowKeydown}
		onmouseenter={() => onhover(node)}
		onmouseleave={onhoverend}
		role="treeitem"
		aria-expanded={node.hasChildren ? isExpanded : undefined}
		aria-selected={isSelected}
		tabindex="-1"
	>
		<!-- Expand/collapse toggle -->
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		{#if node.hasChildren && !inlineText}
			<span
				class="ic-dt-dom-n__toggle"
				class:ic-dt-dom-n__toggle--open={isExpanded}
				onclick={handleToggle}
				role="button"
				tabindex="-1"
			>&#9654;</span>
		{:else}
			<span class="ic-dt-dom-n__toggle-spacer"></span>
		{/if}

		<!-- Opening tag -->
		<span class="ic-dt-dom-n__bracket">&lt;</span><span class="ic-dt-dom-n__tag">{node.tagName}</span>{#if node.attributes}{#each node.attributes as attr (attr.name)}<span class="ic-dt-dom-n__attr-name">{attr.name}</span><span class="ic-dt-dom-n__attr-eq">=</span><span class="ic-dt-dom-n__attr-val">"{attr.value}"</span>{/each}{/if}<span class="ic-dt-dom-n__bracket">&gt;</span>

		<!-- Inline text + closing tag for single short text child -->
		{#if inlineText}
			<span class="ic-dt-dom-n__inline-text">{inlineText}</span><span class="ic-dt-dom-n__bracket">&lt;/</span><span class="ic-dt-dom-n__tag">{node.tagName}</span><span class="ic-dt-dom-n__bracket">&gt;</span>
		{:else if !node.hasChildren}
			<!-- Self-contained: empty element closing tag on same line -->
			<span class="ic-dt-dom-n__bracket">&lt;/</span><span class="ic-dt-dom-n__tag">{node.tagName}</span><span class="ic-dt-dom-n__bracket">&gt;</span>
		{/if}
	</div>

	<!-- Children (lazy: only rendered when expanded) -->
	{#if node.hasChildren && !inlineText && isExpanded}
		{#each node.children as child (child.id)}
			<DomTreeNode
				node={child}
				depth={depth + 1}
				{expandedKeys}
				{selectedNodeId}
				{onexpand}
				{onselect}
				{onhover}
				{onhoverend}
			/>
		{/each}
		<!-- Closing tag -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="ic-dt-dom-n__row ic-dt-dom-n__close"
			style="padding-left: {indent}px"
			onmouseenter={() => onhover(node)}
			onmouseleave={onhoverend}
		>
			<span class="ic-dt-dom-n__toggle-spacer"></span>
			<span class="ic-dt-dom-n__bracket">&lt;/</span><span class="ic-dt-dom-n__tag">{node.tagName}</span><span class="ic-dt-dom-n__bracket">&gt;</span>
		</div>
	{/if}
{/if}

<style>
	/* --- Row --- */

	.ic-dt-dom-n__row {
		display: flex;
		align-items: baseline;
		padding: 1px 8px 1px 0;
		font-family: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
		font-size: 11px;
		line-height: 18px;
		cursor: default;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.ic-dt-dom-n__row:hover {
		background: rgba(128, 128, 128, 0.08);
	}

	.ic-dt-dom-n__row--selected {
		background: rgba(66, 133, 244, 0.12);
	}

	.ic-dt-dom-n__row--selected:hover {
		background: rgba(66, 133, 244, 0.18);
	}

	/* --- Toggle --- */

	.ic-dt-dom-n__toggle {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 14px;
		flex-shrink: 0;
		font-size: 8px;
		color: var(--ic-muted-foreground);
		cursor: pointer;
		transition: transform 0.12s;
		user-select: none;
	}

	.ic-dt-dom-n__toggle--open {
		transform: rotate(90deg);
	}

	.ic-dt-dom-n__toggle:hover {
		color: var(--ic-foreground);
	}

	.ic-dt-dom-n__toggle-spacer {
		display: inline-block;
		width: 14px;
		flex-shrink: 0;
	}

	/* --- Syntax colors --- */

	.ic-dt-dom-n__tag {
		color: #e06c75;
	}

	.ic-dt-dom-n__attr-name {
		color: #d19a66;
		margin-left: 0.5ch;
	}

	.ic-dt-dom-n__attr-eq {
		color: var(--ic-muted-foreground);
	}

	.ic-dt-dom-n__attr-val {
		color: #56b6c2;
	}

	.ic-dt-dom-n__bracket {
		color: var(--ic-muted-foreground);
	}

	.ic-dt-dom-n__inline-text {
		color: var(--ic-foreground);
	}

	/* --- Text node --- */

	.ic-dt-dom-n__text {
		color: var(--ic-foreground);
		font-style: italic;
		opacity: 0.8;
	}

	/* --- Closing tag --- */

	.ic-dt-dom-n__close {
		color: var(--ic-muted-foreground);
	}
</style>
