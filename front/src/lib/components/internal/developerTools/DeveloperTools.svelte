<!--
  DeveloperTools.svelte — Chrome DevTools-like inspector for IC components.

  Renders the inspected component on the left (static child "component")
  and an inspector panel on the right with tabs for Properties, Events,
  Methods, Styles, and DOM.

  Highlight overlay and picker are driven entirely by event handlers (no $effect).
  The single $effect is for the one-time async componentInfo fetch from MATLAB.
-->
<script lang="ts">
	import type { StaticChildrenMap, RequestFn } from '$lib/types';
	import type { ComponentInfo, TabId } from './devtools-types';
	import logger from '$lib/core/logger';
	import { showHighlight, hideHighlight } from './panels/dom/dom-utils';

	import PropertiesPanel from './panels/PropertiesPanel.svelte';
	import EventsPanel from './panels/EventsPanel.svelte';
	import MethodsPanel from './panels/MethodsPanel.svelte';
	import StylesPanel from './panels/StylesPanel.svelte';
	import DomPanel from './panels/DomPanel.svelte';

	let {
		staticChildren = new Map() as StaticChildrenMap,
		request
	}: {
		staticChildren?: StaticChildrenMap;
		request?: RequestFn;
	} = $props();

	// --- Static child access ---

	const childSlot = $derived(staticChildren.get('component') ?? []);
	const child = $derived(childSlot[0]);

	// --- Component metadata (fetched once from MATLAB) ---
	// This $effect is the only one — justified because it's a one-time async
	// fetch that can't be expressed as $derived.

	let componentInfo = $state<ComponentInfo | null>(null);
	let infoError = $state<string | null>(null);

	$effect(() => {
		if (!request || componentInfo) return;
		request('getComponentInfo', {}).then((res) => {
			if (res.success) {
				componentInfo = res.data as ComponentInfo;
				logger.debug('DevTools', 'Component info loaded', {
					type: componentInfo.componentType,
					props: componentInfo.properties.length,
					events: componentInfo.events.length,
					methods: componentInfo.methods.length,
					children: componentInfo.children.length
				});
			} else {
				infoError = String(res.data);
				logger.error('DevTools', 'Failed to load component info', { error: res.data });
			}
		});
	});

	// --- Tab state ---

	let activeTab = $state<TabId>('properties');

	const tabs: { id: TabId; label: string }[] = [
		{ id: 'properties', label: 'Properties' },
		{ id: 'events', label: 'Events' },
		{ id: 'methods', label: 'Methods' },
		{ id: 'styles', label: 'Styles' },
		{ id: 'dom', label: 'DOM' }
	];

	// --- Resizable split ---

	let containerEl: HTMLElement | undefined;
	let splitPercent = $state(50);
	let dragging = $state(false);

	function handleGutterDown(e: MouseEvent) {
		e.preventDefault();
		dragging = true;
		document.addEventListener('mousemove', handleGutterMove);
		document.addEventListener('mouseup', handleGutterUp);
	}

	function handleGutterMove(e: MouseEvent) {
		if (!dragging || !containerEl) return;
		const rect = containerEl.getBoundingClientRect();
		const pct = ((e.clientX - rect.left) / rect.width) * 100;
		splitPercent = Math.max(20, Math.min(80, pct));
	}

	function handleGutterUp() {
		dragging = false;
		document.removeEventListener('mousemove', handleGutterMove);
		document.removeEventListener('mouseup', handleGutterUp);
	}

	// --- DOM panel: picker + highlight (all imperative, no effects) ---

	let previewEl: HTMLElement | undefined;
	let pickerOverlayEl = $state<HTMLElement | undefined>();
	let pickerActive = $state(false);
	let pickerHoveredEl: Element | null = null; // not reactive — only used in handlers
	let domReveal = $state<(el: Element) => void>(() => {});

	/** Called by DomPanel tree hover and also by picker hover. */
	function handleDomHover(el: Element | null) {
		if (el && previewEl) {
			showHighlight(el, previewEl);
		} else {
			hideHighlight();
		}
	}

	// Picker: temporarily hide overlay to find the real element underneath
	function handlePickerHover(e: MouseEvent) {
		if (!componentInfo || !pickerOverlayEl) return;
		pickerOverlayEl.style.pointerEvents = 'none';
		const el = document.elementFromPoint(e.clientX, e.clientY);
		pickerOverlayEl.style.pointerEvents = '';
		if (!el) return;

		const wrapper = document.getElementById(componentInfo.componentId);
		if (!wrapper) return;
		if (wrapper.contains(el) && el !== wrapper) {
			pickerHoveredEl = el;
			showHighlight(el, previewEl!);
		}
	}

	function handlePickerClick(e: MouseEvent) {
		e.preventDefault();
		e.stopPropagation();
		if (pickerHoveredEl) {
			domReveal(pickerHoveredEl);
		}
		pickerActive = false;
		pickerHoveredEl = null;
		hideHighlight();
	}

	function handlePreviewLeave() {
		pickerHoveredEl = null;
		hideHighlight();
	}

</script>

<div
	class="ic-dt"
	class:ic-dt--dragging={dragging}
	bind:this={containerEl}
>
	<!-- Left: inspected component -->
	<div
		class="ic-dt__preview"
		style="width: {splitPercent}%;"
		bind:this={previewEl}
		role="presentation"
	>
		{#if child}
			{@render child.snippet()}
		{:else}
			<div class="ic-dt__empty">No component</div>
		{/if}

		<!-- Picker overlay: sits on top of everything when active, captures all mouse events -->
		{#if pickerActive}
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<div
				class="ic-dt__picker-overlay"
				bind:this={pickerOverlayEl}
				onmousemove={handlePickerHover}
				onclick={handlePickerClick}
				onmouseleave={handlePreviewLeave}
			></div>
		{/if}
	</div>

	<!-- Gutter -->
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div
		class="ic-dt__gutter"
		onmousedown={handleGutterDown}
		role="separator"
		aria-orientation="horizontal"
	></div>

	<!-- Right: inspector -->
	<div class="ic-dt__inspector" style="width: {100 - splitPercent}%;">
		<!-- Tab bar -->
		<div class="ic-dt__tabs">
			{#each tabs as tab (tab.id)}
				<button
					class="ic-dt__tab"
					class:ic-dt__tab--active={activeTab === tab.id}
					onclick={() => (activeTab = tab.id)}
				>
					{tab.label}
				</button>
			{/each}

			{#if infoError}
				<span class="ic-dt__error">{infoError}</span>
			{:else if !componentInfo}
				<span class="ic-dt__loading">Loading...</span>
			{/if}
		</div>

		<!-- Tab content -->
		<div class="ic-dt__content">
			{#if componentInfo && child}
				{#if activeTab === 'properties'}
					<PropertiesPanel {child} {componentInfo} />
				{:else if activeTab === 'events'}
					<EventsPanel {child} {componentInfo} />
				{:else if activeTab === 'methods'}
					<MethodsPanel {child} {componentInfo} />
				{:else if activeTab === 'styles'}
					<StylesPanel {componentInfo} />
				{:else if activeTab === 'dom'}
					<DomPanel
						{componentInfo}
						bind:pickerActive
						bind:reveal={domReveal}
						onhover={handleDomHover}
					/>
				{/if}
			{/if}
		</div>
	</div>
</div>

<style>
	.ic-dt {
		display: flex;
		position: fixed;
		inset: 0;
		overflow: clip;
		background: var(--ic-background);
		color: var(--ic-foreground);
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
	}

	.ic-dt--dragging {
		cursor: col-resize;
		user-select: none;
	}

	/* --- Preview pane --- */

	.ic-dt__preview {
		overflow: auto;
		padding: 12px;
		min-width: 0;
		position: relative;
	}

	.ic-dt__picker-overlay {
		position: absolute;
		inset: 0;
		cursor: crosshair;
		z-index: 10000;
	}

	.ic-dt__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 24px;
	}

	/* --- Gutter --- */

	.ic-dt__gutter {
		flex: 0 0 5px;
		background: var(--ic-secondary);
		cursor: col-resize;
		position: relative;
		box-shadow:
			inset 1px 0 0 rgba(255, 255, 255, 0.04),
			inset -1px 0 0 rgba(0, 0, 0, 0.15);
	}

	.ic-dt__gutter::before {
		content: '';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 60%;
		height: 24px;
		opacity: 0.35;
		background-image: repeating-linear-gradient(
			to bottom,
			var(--ic-muted-foreground) 0px,
			var(--ic-muted-foreground) 1px,
			transparent 1px,
			transparent 4px
		);
	}

	.ic-dt__gutter:hover::before {
		opacity: 0.55;
	}

	/* --- Inspector pane --- */

	.ic-dt__inspector {
		display: flex;
		flex-direction: column;
		min-width: 0;
		min-height: 0;
		overflow: clip;
		border-left: 1px solid var(--ic-border);
	}

	.ic-dt__error {
		color: var(--ic-destructive);
		margin-left: auto;
		font-size: 0.85em;
	}

	.ic-dt__loading {
		color: var(--ic-muted-foreground);
		font-style: italic;
		margin-left: auto;
		font-size: 0.85em;
	}

	/* --- Tab bar --- */

	.ic-dt__tabs {
		display: flex;
		background: var(--ic-secondary);
		border-bottom: 1px solid var(--ic-border);
		padding: 0 4px;
		gap: 0;
	}

	.ic-dt__tab {
		all: unset;
		padding: 5px 12px;
		cursor: pointer;
		color: var(--ic-muted-foreground);
		font-size: var(--ic-font-size);
		font-family: var(--ic-font-family);
		border-bottom: 2px solid transparent;
		transition: color 0.15s, border-color 0.15s;
		white-space: nowrap;
	}

	.ic-dt__tab:hover {
		color: var(--ic-foreground);
	}

	.ic-dt__tab--active {
		color: var(--ic-primary);
		border-bottom-color: var(--ic-primary);
	}

	/* --- Content area --- */

	.ic-dt__content {
		flex: 1;
		min-height: 0;
		overflow: auto;
		padding: 0;
	}
</style>
