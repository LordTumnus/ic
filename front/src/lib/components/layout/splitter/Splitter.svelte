<script lang="ts">
	import type { Snippet } from 'svelte';
	import { setContext } from 'svelte';
	import type { Resolution, Snippets } from '$lib/types';
	import type { PaneConfig, PaneHandle } from './splitter-types';
	import logger from '$lib/core/logger';

	let {
		direction = $bindable<'horizontal' | 'vertical'>('horizontal'),
		gutterSize = $bindable(5),
		disabled = $bindable(false),
		targets = $bindable<string[]>([]),
		collapsePane = $bindable((_data: { index: number; direction: string }): Resolution => ({ success: true, data: null })),
		resized,
		snippets = {} as Snippets
	}: {
		direction?: 'horizontal' | 'vertical';
		gutterSize?: number;
		disabled?: boolean;
		targets?: string[];
		collapsePane?: (data: { index: number; direction: string }) => Resolution;
		resized?: (data: { sizes: number[] }) => void;
		snippets?: Snippets;
	} = $props();

	// --- Container & measurement ---

	let containerEl: HTMLElement;
	let containerReady = $state(false);

	$effect(() => {
		if (containerEl && !containerReady) {
			requestAnimationFrame(() => {
				containerReady = true;
			});
		}
	});

	// --- Pane registration via context ---

	let paneConfigs = $state<PaneConfig[]>([]);
	let paneHandles: PaneHandle[] = [];

	setContext('ic-splitter', {
		register(handle: PaneHandle): number {
			const idx = paneHandles.length;
			paneHandles = [...paneHandles, handle];
			// Config will be set via the subsequent update() call from pane's $effect
			paneConfigs = [...paneConfigs, { size: null, minSize: 0, maxSize: 100, snapSize: 0 }];
			return idx;
		},
		update(idx: number, config: PaneConfig) {
			if (idx >= 0 && idx < paneConfigs.length) {
				paneConfigs[idx] = { ...config };
			}
		},
		deregister(idx: number) {
			paneConfigs = paneConfigs.filter((_, i) => i !== idx);
			paneHandles = paneHandles.filter((_, i) => i !== idx);
		}
	});

	// --- Local sizes (working state) ---

	let localSizes = $state<number[]>([]);
	let isDragging = $state(false);
	let dragGutterIndex = -1;
	let dragStartPos = 0;
	let dragStartSizes: number[] = [];
	let dragCachedAvailable = 0;

	// Equalize: compute effective sizes from pane configs
	function equalize(configs: PaneConfig[]): number[] {
		const n = configs.length;
		if (n === 0) return [];

		const sizes: number[] = new Array(n);
		let definedSum = 0;
		let autoCount = 0;

		for (let i = 0; i < n; i++) {
			const s = configs[i].size;
			if (s != null && !Number.isNaN(s)) {
				sizes[i] = s;
				definedSum += s;
			} else {
				sizes[i] = -1; // marker for auto
				autoCount++;
			}
		}

		if (autoCount > 0) {
			const remaining = Math.max(0, 100 - definedSum);
			const autoSize = remaining / autoCount;
			for (let i = 0; i < n; i++) {
				if (sizes[i] < 0) {
					sizes[i] = autoSize;
				}
			}
		}

		for (let i = 0; i < n; i++) {
			sizes[i] = Math.max(configs[i].minSize, Math.min(configs[i].maxSize, sizes[i]));
		}

		// Constraint-aware normalization: distribute deficit/surplus only to
		// panes that have room, iterating until stable (max 5 passes).
		for (let iter = 0; iter < 5; iter++) {
			const total = sizes.reduce((a, b) => a + b, 0);
			const deficit = 100 - total;
			if (Math.abs(deficit) <= 0.01) break;

			const adjustable: number[] = [];
			for (let i = 0; i < n; i++) {
				if (deficit > 0 && sizes[i] < configs[i].maxSize) adjustable.push(i);
				else if (deficit < 0 && sizes[i] > configs[i].minSize) adjustable.push(i);
			}
			if (adjustable.length === 0) break; // impossible to satisfy

			const share = deficit / adjustable.length;
			for (const i of adjustable) {
				sizes[i] = Math.max(configs[i].minSize, Math.min(configs[i].maxSize, sizes[i] + share));
			}
		}

		return sizes;
	}

	// Sync localSizes from pane configs when not dragging
	$effect(() => {
		// Read paneConfigs to establish dependency
		const configs = paneConfigs;
		if (!isDragging && configs.length > 0) {
			localSizes = equalize(configs);
		}
	});

	// --- Helpers ---

	function getPaneSnippet(index: number): Snippet | undefined {
		const target = `pane-${index}`;
		return snippets[target]?.[0];
	}

	function getAvailableSize(): number {
		if (!containerEl) return 0;
		const containerSize =
			direction === 'horizontal' ? containerEl.offsetWidth : containerEl.offsetHeight;
		const gutterTotal = Math.max(0, targets.length - 1) * gutterSize;
		return containerSize - gutterTotal;
	}

	// Write sizes back to pane components (flows to MATLAB via $bindable)
	function pushSizesToPanes(sizes: number[]) {
		for (let i = 0; i < sizes.length; i++) {
			paneHandles[i]?.setSize(sizes[i]);
		}
		// Also update local configs to prevent equalization from reverting
		for (let i = 0; i < sizes.length; i++) {
			if (i < paneConfigs.length) {
				paneConfigs[i] = { ...paneConfigs[i], size: sizes[i] };
			}
		}
	}

	// --- Drag handling ---

	function handleGutterMouseDown(e: MouseEvent, gutterIndex: number) {
		if (disabled) return;

		e.preventDefault();
		isDragging = true;
		dragGutterIndex = gutterIndex;
		dragStartPos = direction === 'horizontal' ? e.clientX : e.clientY;
		dragStartSizes = [...localSizes];
		dragCachedAvailable = getAvailableSize();

		logger.debug('Splitter', 'Drag started', {
			gutterIndex,
			position: dragStartPos,
			sizes: `[${dragStartSizes.map((s) => s.toFixed(1)).join(', ')}]`
		});

		document.addEventListener('mousemove', handleMouseMove);
		document.addEventListener('mouseup', handleMouseUp);
	}

	function handleMouseMove(e: MouseEvent) {
		if (!isDragging || dragGutterIndex < 0) return;

		if (e.buttons === 0) {
			handleMouseUp();
			return;
		}

		const currentPos = direction === 'horizontal' ? e.clientX : e.clientY;
		const availableSize = dragCachedAvailable;
		if (availableSize <= 0) return;

		const deltaPct = ((currentPos - dragStartPos) / availableSize) * 100;

		const leftIdx = dragGutterIndex;
		const rightIdx = dragGutterIndex + 1;

		const leftConfig = paneConfigs[leftIdx];
		const rightConfig = paneConfigs[rightIdx];
		if (!leftConfig || !rightConfig) return;

		const combinedSpace = dragStartSizes[leftIdx] + dragStartSizes[rightIdx];

		let newLeftSize = dragStartSizes[leftIdx] + deltaPct;

		// Snap left pane: if within minSize + snapSize, snap to minSize
		if (leftConfig.snapSize > 0 && newLeftSize < leftConfig.minSize + leftConfig.snapSize) {
			newLeftSize = leftConfig.minSize;
		}
		if (leftConfig.snapSize > 0 && newLeftSize > leftConfig.maxSize - leftConfig.snapSize) {
			newLeftSize = leftConfig.maxSize;
		}

		let newRightSize = combinedSpace - newLeftSize;

		if (rightConfig.snapSize > 0 && newRightSize < rightConfig.minSize + rightConfig.snapSize) {
			newRightSize = rightConfig.minSize;
			newLeftSize = combinedSpace - newRightSize;
		}
		if (rightConfig.snapSize > 0 && newRightSize > rightConfig.maxSize - rightConfig.snapSize) {
			newRightSize = rightConfig.maxSize;
			newLeftSize = combinedSpace - newRightSize;
		}

		// Clamp with combined-space constraint: left + right must always equal combinedSpace
		newLeftSize = Math.max(leftConfig.minSize, Math.min(leftConfig.maxSize, newLeftSize));
		newRightSize = combinedSpace - newLeftSize;
		newRightSize = Math.max(rightConfig.minSize, Math.min(rightConfig.maxSize, newRightSize));
		newLeftSize = combinedSpace - newRightSize;

		const newSizes = [...dragStartSizes];
		newSizes[leftIdx] = newLeftSize;
		newSizes[rightIdx] = newRightSize;
		localSizes = newSizes;
	}

	function handleMouseUp() {
		if (!isDragging) return;

		logger.debug('Splitter', 'Drag ended', {
			sizes: `[${localSizes.map((s) => s.toFixed(1)).join(', ')}]`
		});

		isDragging = false;
		dragGutterIndex = -1;

		// Push final sizes to pane components → auto-syncs to MATLAB
		pushSizesToPanes(localSizes);
		resized?.({ sizes: [...localSizes] });

		document.removeEventListener('mousemove', handleMouseMove);
		document.removeEventListener('mouseup', handleMouseUp);
	}

	// --- Pane styles ---

	const paneStyles = $derived.by(() => {
		const n = targets.length;
		if (n === 0) return [];

		const sizes = localSizes.length === n ? localSizes : Array(n).fill(100 / n);
		const gutterCount = Math.max(0, n - 1);
		const gutterTotal = gutterCount * gutterSize;

		// During drag: use cached pixel sizes to prevent non-adjacent pane jitter.
		// Otherwise: use calc() expressions which are inherently responsive to
		// container resize (no ResizeObserver needed).
		if (isDragging) {
			const available = dragCachedAvailable;
			return sizes.map((size) => {
				const pixels = (size / 100) * available;
				if (direction === 'horizontal') {
					return `width: ${pixels}px; flex-basis: ${pixels}px;`;
				} else {
					return `height: ${pixels}px; flex-basis: ${pixels}px;`;
				}
			});
		}

		return sizes.map((size) => {
			const calcExpr = `calc((100% - ${gutterTotal}px) * ${size} / 100)`;
			if (direction === 'horizontal') {
				return `width: ${calcExpr}; flex-basis: ${calcExpr};`;
			} else {
				return `height: ${calcExpr}; flex-basis: ${calcExpr};`;
			}
		});
	});

	// --- Collapse method ---

	$effect(() => {
		collapsePane = (data: { index: number; direction: string }): Resolution => {
			const { index, direction: dir } = data;
			const effectiveSizes =
				localSizes.length === targets.length ? localSizes : equalize(paneConfigs);

			if (index < 0 || index >= effectiveSizes.length) {
				logger.error('Splitter', 'Collapse index out of bounds', {
					index,
					numPanes: effectiveSizes.length
				});
				return {
					success: false,
					data: `Collapse index ${index} out of bounds (0-${effectiveSizes.length - 1})`
				};
			}

			logger.debug('Splitter', 'Collapsing pane', { index, direction: dir });

			const minPct = paneConfigs[index]?.minSize ?? 0;
			const currentSize = effectiveSizes[index];
			const freed = currentSize - minPct;

			const newSizes = [...effectiveSizes];
			newSizes[index] = minPct;

			// Distribute freed space to neighbors, respecting maxSize.
			// Direction controls which side is preferred.
			let remaining = freed;
			const order: number[] = [];
			if (dir === 'right') {
				for (let i = index + 1; i < newSizes.length; i++) order.push(i);
				for (let i = index - 1; i >= 0; i--) order.push(i);
			} else {
				for (let i = index - 1; i >= 0; i--) order.push(i);
				for (let i = index + 1; i < newSizes.length; i++) order.push(i);
			}
			for (const i of order) {
				if (remaining <= 0) break;
				const maxAvail = (paneConfigs[i]?.maxSize ?? 100) - newSizes[i];
				const give = Math.min(remaining, maxAvail);
				newSizes[i] += give;
				remaining -= give;
			}

			localSizes = newSizes;
			pushSizesToPanes(newSizes);
			resized?.({ sizes: [...newSizes] });

			return { success: true, data: null };
		};
	});
</script>

<div
	class="ic-splitter"
	class:ic-splitter-vertical={direction === 'vertical'}
	class:ic-splitter-dragging={isDragging}
	bind:this={containerEl}
>
	{#each targets as target, i (target)}
		{@const paneSnippet = getPaneSnippet(i)}
		<!-- Pane -->
		<div class="ic-splitter-pane" style={paneStyles[i] ?? ''}>
			{#if paneSnippet}
				{@render paneSnippet()}
			{/if}
		</div>
		<!-- Gutter (between panes, not after last) -->
		{#if i < targets.length - 1}
			<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
			<div
				class="ic-splitter-gutter"
				class:ic-splitter-gutter-horizontal={direction === 'horizontal'}
				class:ic-splitter-gutter-vertical={direction === 'vertical'}
				class:ic-splitter-gutter-disabled={disabled}
				style={direction === 'horizontal'
					? `width: ${gutterSize}px;`
					: `height: ${gutterSize}px;`}
				onmousedown={(e) => handleGutterMouseDown(e, i)}
				role="separator"
				aria-orientation={direction}
				aria-valuenow={localSizes[i] ?? 0}
			></div>
		{/if}
	{/each}
</div>

<style>
	.ic-splitter {
		display: flex;
		width: 100%;
		height: 100%;
		overflow: hidden;
	}

	.ic-splitter-vertical {
		flex-direction: column;
	}

	.ic-splitter-dragging {
		cursor: col-resize;
		user-select: none;
	}

	.ic-splitter-vertical.ic-splitter-dragging {
		cursor: row-resize;
	}

	.ic-splitter-pane {
		overflow: auto;
		flex-grow: 0;
		flex-shrink: 0;
		min-width: 0;
		min-height: 0;
	}

	/* Recessed channel */
	.ic-splitter-gutter {
		flex-grow: 0;
		flex-shrink: 0;
		background-color: var(--ic-secondary);
		box-shadow:
			inset 0 1px 2px rgba(0, 0, 0, 0.12),
			inset 0 -1px 0 rgba(255, 255, 255, 0.06);
		transition: box-shadow 0.15s ease;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	/* Knurl grip pattern */
	.ic-splitter-gutter::before {
		content: '';
		position: absolute;
		opacity: 0.4;
		transition: opacity 0.15s ease;
	}

	/* Horizontal gutter: horizontal knurl lines */
	.ic-splitter-gutter-horizontal::before {
		width: 60%;
		height: 24px;
		background-image: repeating-linear-gradient(
			to bottom,
			var(--ic-muted-foreground) 0px,
			var(--ic-muted-foreground) 1px,
			transparent 1px,
			transparent 4px
		);
	}

	/* Vertical gutter: vertical knurl lines */
	.ic-splitter-gutter-vertical::before {
		width: 24px;
		height: 60%;
		background-image: repeating-linear-gradient(
			to right,
			var(--ic-muted-foreground) 0px,
			var(--ic-muted-foreground) 1px,
			transparent 1px,
			transparent 4px
		);
	}

	.ic-splitter-gutter:hover:not(.ic-splitter-gutter-disabled) {
		box-shadow:
			inset 0 1px 3px rgba(0, 0, 0, 0.2),
			inset 0 -1px 0 rgba(255, 255, 255, 0.08);
	}

	.ic-splitter-gutter:hover:not(.ic-splitter-gutter-disabled)::before {
		opacity: 0.6;
	}

	.ic-splitter-gutter-horizontal {
		cursor: col-resize;
	}

	.ic-splitter-gutter-vertical {
		cursor: row-resize;
	}

	.ic-splitter-gutter-disabled {
		cursor: default;
		pointer-events: none;
	}

	.ic-splitter-gutter-disabled::before {
		opacity: 0.15;
	}
</style>
