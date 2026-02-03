<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { Resolution, Snippets } from '$lib/types';
	import logger from '$lib/core/logger';

	let {
		sizes = $bindable([50, 50]),
		targets = $bindable(['pane-0', 'pane-1']),
		minSize = $bindable<number | number[]>(100),
		maxSize = $bindable<number | number[]>(Infinity),
		gutterSize = $bindable(10),
		direction = $bindable<'horizontal' | 'vertical'>('horizontal'),
		disabled = $bindable(false),
		snapOffset = $bindable(30),
		sizesChanged,
		collapse = $bindable((_index: number): Resolution => ({ success: true, data: null })),
		snippets = {} as Snippets
	}: {
		sizes?: number[];
		targets?: string[];
		minSize?: number | number[];
		maxSize?: number | number[];
		gutterSize?: number;
		direction?: 'horizontal' | 'vertical';
		disabled?: boolean;
		snapOffset?: number;
		sizesChanged?: (data: { sizes: number[] }) => void;
		collapse?: (index: number) => Resolution;
		snippets?: Snippets;
	} = $props();

	// Container element reference
	let containerEl: HTMLElement;
	let containerReady = $state(false);

	// Trigger re-render once container is measured
	$effect(() => {
		if (containerEl && !containerReady) {
			// Use requestAnimationFrame to ensure layout is complete
			requestAnimationFrame(() => {
				containerReady = true;
			});
		}
	});

	// Drag state (reactive for UI updates)
	let isDragging = $state(false);
	let dragGutterIndex = -1;
	let dragStartPos = 0;
	let dragStartSizes: number[] = [];
	// Local sizes during drag - avoids flooding MATLAB with updates
	let localSizes = $state<number[] | null>(null);

	// Effective sizes: use localSizes during drag, otherwise actual sizes
	const effectiveSizes = $derived(localSizes ?? sizes);

	// Get snippet for a pane by index (using indexed target)
	function getPaneSnippet(index: number): Snippet | undefined {
		const target = `pane-${index}`;
		const paneSnippets = snippets[target];
		return paneSnippets?.[0]; // First child in this pane slot
	}

	// Get min size for a pane (handles scalar or array)
	function getMinSize(index: number): number {
		if (Array.isArray(minSize)) {
			return minSize[index] ?? minSize[0] ?? 100;
		}
		return minSize;
	}

	// Get max size for a pane (handles scalar, array, null, or Infinity)
	function getMaxSize(index: number): number {
		// Handle null (from MATLAB Inf serialization) as no limit
		if (maxSize === null || maxSize === undefined) {
			return Infinity;
		}
		if (Array.isArray(maxSize)) {
			const val = maxSize[index] ?? maxSize[0];
			return val === null || val === undefined ? Infinity : val;
		}
		return maxSize;
	}

	// Calculate available size (container minus gutters)
	function getAvailableSize(): number {
		if (!containerEl) return 0;
		const containerSize =
			direction === 'horizontal' ? containerEl.offsetWidth : containerEl.offsetHeight;
		const gutterTotal = (sizes.length - 1) * gutterSize;
		return containerSize - gutterTotal;
	}

	// Convert pixels to percentage
	function pixelsToPct(pixels: number): number {
		const available = getAvailableSize();
		return available > 0 ? (pixels / available) * 100 : 0;
	}

	// Handle gutter mousedown - start drag
	function handleGutterMouseDown(e: MouseEvent, gutterIndex: number) {
		if (disabled) return;

		e.preventDefault();
		isDragging = true;
		dragGutterIndex = gutterIndex;
		dragStartPos = direction === 'horizontal' ? e.clientX : e.clientY;
		dragStartSizes = [...sizes];
		// Initialize local sizes for drag (avoids syncing to MATLAB on every move)
		localSizes = [...sizes];

		logger.debug('Splitter', 'Drag started', {
			gutterIndex,
			position: dragStartPos,
			sizes: `[${dragStartSizes.map((s) => s.toFixed(1)).join(', ')}]`
		});

		// Add document-level listeners for drag
		document.addEventListener('mousemove', handleMouseMove);
		document.addEventListener('mouseup', handleMouseUp);
	}

	// Handle mouse move during drag
	function handleMouseMove(e: MouseEvent) {
		if (!isDragging || dragGutterIndex < 0) return;

		// If no buttons are pressed, user released outside the window - end drag
		if (e.buttons === 0) {
			handleMouseUp();
			return;
		}

		const currentPos = direction === 'horizontal' ? e.clientX : e.clientY;
		const delta = currentPos - dragStartPos;
		const availableSize = getAvailableSize();
		if (availableSize <= 0) return;

		const deltaPct = pixelsToPct(delta);
		const snapPct = (snapOffset / availableSize) * 100;

		const leftIndex = dragGutterIndex;
		const rightIndex = dragGutterIndex + 1;

		// Get constraints as percentages
		const leftMinPct = (getMinSize(leftIndex) / availableSize) * 100;
		const rightMinPct = (getMinSize(rightIndex) / availableSize) * 100;
		const leftMaxPct = (getMaxSize(leftIndex) / availableSize) * 100;
		const rightMaxPct = (getMaxSize(rightIndex) / availableSize) * 100;

		// Calculate the combined space of both panes (this stays constant)
		const combinedSpace = dragStartSizes[leftIndex] + dragStartSizes[rightIndex];

		// Calculate new left size with delta
		let newLeftSize = dragStartSizes[leftIndex] + deltaPct;

		// Snap left pane to min/max if within snapOffset
		if (newLeftSize < leftMinPct + snapPct) {
			newLeftSize = leftMinPct;
		} else if (newLeftSize > leftMaxPct - snapPct) {
			newLeftSize = leftMaxPct;
		}

		// Calculate right size from remaining combined space
		let newRightSize = combinedSpace - newLeftSize;

		// Snap right pane to min/max if within snapOffset
		if (newRightSize < rightMinPct + snapPct) {
			newRightSize = rightMinPct;
			newLeftSize = combinedSpace - newRightSize;
		} else if (newRightSize > rightMaxPct - snapPct) {
			newRightSize = rightMaxPct;
			newLeftSize = combinedSpace - newRightSize;
		}

		// Final clamp (safety net)
		newLeftSize = Math.max(leftMinPct, Math.min(leftMaxPct, newLeftSize));
		newRightSize = Math.max(rightMinPct, Math.min(rightMaxPct, newRightSize));

		// Build new sizes array (only modify the two adjacent panes)
		const newSizes = [...dragStartSizes];
		newSizes[leftIndex] = newLeftSize;
		newSizes[rightIndex] = newRightSize;

		// Update local sizes only (no MATLAB sync during drag)
		localSizes = newSizes;
	}

	// Handle mouse up - end drag
	function handleMouseUp() {
		if (!isDragging) return;

		// Commit local sizes to actual sizes (single sync to MATLAB)
		const finalSizes = localSizes ?? sizes;

		logger.debug('Splitter', 'Drag ended', {
			sizes: `[${finalSizes.map((s) => s.toFixed(1)).join(', ')}]`
		});

		// Update the bindable prop (syncs to MATLAB once)
		sizes = finalSizes;
		localSizes = null;

		isDragging = false;
		dragGutterIndex = -1;

		// Notify MATLAB of size change via event
		sizesChanged?.({ sizes: finalSizes });

		// Remove document-level listeners
		document.removeEventListener('mousemove', handleMouseMove);
		document.removeEventListener('mouseup', handleMouseUp);
	}

	// Derived pane styles - reactive to effectiveSizes, containerReady, direction, gutterSize
	const paneStyles = $derived.by(() => {
		const available = containerReady ? getAvailableSize() : 0;
		const gutterCount = effectiveSizes.length - 1;
		const gutterTotal = gutterCount * gutterSize;

		return effectiveSizes.map((size) => {
			// Before container is measured, use percentage-based sizing with calc()
			if (available <= 0) {
				const calcExpr = `calc((100% - ${gutterTotal}px) * ${size} / 100)`;
				if (direction === 'horizontal') {
					return `width: ${calcExpr}; flex-basis: ${calcExpr};`;
				} else {
					return `height: ${calcExpr}; flex-basis: ${calcExpr};`;
				}
			}

			// After measurement, use precise pixel values
			const pixels = (size / 100) * available;
			if (direction === 'horizontal') {
				return `width: ${pixels}px; flex-basis: ${pixels}px;`;
			} else {
				return `height: ${pixels}px; flex-basis: ${pixels}px;`;
			}
		});
	});

	// Initialize collapse method
	$effect(() => {
		collapse = (index: number): Resolution => {
			// Validate index (0-based from MATLAB)
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

			logger.debug('Splitter', 'Collapsing pane', { index });
			const availableSize = getAvailableSize();
			const minPct = (getMinSize(index) / availableSize) * 100;

			const newSizes = [...effectiveSizes];
			const currentSize = newSizes[index];
			const delta = currentSize - minPct;

			// Collapse to minimum
			newSizes[index] = minPct;

			// Distribute the freed space to adjacent panes
			if (index > 0) {
				newSizes[index - 1] += delta;
			} else if (index < newSizes.length - 1) {
				newSizes[index + 1] += delta;
			}

			sizes = newSizes;
			sizesChanged?.({ sizes: newSizes });

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
	{#each effectiveSizes as _, i (i)}
		{@const paneSnippet = getPaneSnippet(i)}
		<!-- Pane (renders child if available, otherwise empty) -->
		<div class="ic-splitter-pane" style={paneStyles[i]}>
			{#if paneSnippet}
				{@render paneSnippet()}
			{/if}
		</div>
		<!-- Gutter (between panes, not after last) -->
		{#if i < effectiveSizes.length - 1}
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
				aria-valuenow={effectiveSizes[i]}
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

	.ic-splitter-gutter {
		flex-grow: 0;
		flex-shrink: 0;
		background-color: var(--ic-border);
		transition: background-color 0.15s ease;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	/* Dot pattern indicator */
	.ic-splitter-gutter::before {
		content: '';
		position: absolute;
		border-radius: 1px;
		background-color: var(--ic-muted-foreground);
		opacity: 0.5;
		transition: opacity 0.15s ease;
	}

	/* Horizontal gutter: vertical dots */
	.ic-splitter-gutter-horizontal::before {
		width: 3px;
		height: 20px;
		background-image: radial-gradient(
			circle,
			var(--ic-muted-foreground) 1px,
			transparent 1px
		);
		background-size: 3px 4px;
		background-position: center;
	}

	/* Vertical gutter: horizontal dots */
	.ic-splitter-gutter-vertical::before {
		width: 20px;
		height: 3px;
		background-image: radial-gradient(
			circle,
			var(--ic-muted-foreground) 1px,
			transparent 1px
		);
		background-size: 4px 3px;
		background-position: center;
	}

	.ic-splitter-gutter:hover:not(.ic-splitter-gutter-disabled)::before {
		opacity: 1;
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
		opacity: 0.2;
	}
</style>
