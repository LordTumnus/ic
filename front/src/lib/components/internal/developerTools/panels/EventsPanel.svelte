<!--
  EventsPanel.svelte — Event monitor with counters and flash animations.

  Intercepts events by setting handlers on svelteProps (the same mechanism
  StaticChild uses). Root events go through child.events; child events go
  through Registry.instance.get(id).svelteProps.
  Shows root component and children in a collapsible tree.
-->
<script lang="ts">
	import type { StaticChild } from '$lib/types';
	import type { ComponentInfo, ChildComponentInfo, EventInfo } from '../devtools-types';
	import Registry from '$lib/core/registry';

	let {
		child,
		componentInfo
	}: {
		child: StaticChild;
		componentInfo: ComponentInfo;
	} = $props();

	// Counter and flash state per event (keyed by "componentId:eventName" for children, plain name for root)
	let counts = $state<Record<string, number>>({});
	let flashKeys = $state<Record<string, number>>({});
	let lastPayloads = $state<Record<string, string>>({});

	/** Unique key for an event (root vs child) */
	function eventKey(cid: string | null, evtName: string): string {
		return cid ? `${cid}:${evtName}` : evtName;
	}

	/** Create a handler that increments counters and captures payloads */
	function makeHandler(key: string) {
		return (data?: unknown) => {
			counts[key] = (counts[key] ?? 0) + 1;
			flashKeys[key] = (flashKeys[key] ?? 0) + 1;
			if (data !== undefined) {
				try {
					lastPayloads[key] = JSON.stringify(data);
				} catch {
					lastPayloads[key] = String(data);
				}
			}
		};
	}

	// Wire up event handlers for root component (via StaticChild proxy)
	$effect(() => {
		for (const evt of componentInfo.events) {
			const key = eventKey(null, evt.name);
			child.events[evt.name] = makeHandler(key);
		}
	});

	// Wire up event handlers for all descendants (via Registry → svelteProps)
	function wireChildEvents(info: ChildComponentInfo) {
		const comp = Registry.instance.get(info.componentId) as any;
		if (comp) {
			for (const evt of info.events) {
				const key = eventKey(info.componentId, evt.name);
				comp.svelteProps[evt.name] = makeHandler(key);
			}
		}
		// Recurse
		for (const grandchild of info.children ?? []) {
			wireChildEvents(grandchild);
		}
	}

	$effect(() => {
		for (const childInfo of componentInfo.children ?? []) {
			wireChildEvents(childInfo);
		}
	});

	function resetCounters() {
		counts = {};
		flashKeys = {};
		lastPayloads = {};
	}

	let expanded = $state<Record<string, boolean>>({});
	let rootExpanded = $state(true);
	let expandedChildren = $state<Record<string, boolean>>({});

	/** Short type label */
	function shortType(type: string): string {
		return type.split('.').pop() ?? type;
	}
</script>

<div class="ic-dt-evt">
	{#snippet eventRow(evt: EventInfo, cid: string | null)}
		{@const key = eventKey(cid, evt.name)}
		{@const count = counts[key] ?? 0}
		{@const fk = flashKeys[key] ?? 0}
		{@const payload = lastPayloads[key]}
		<div class="ic-dt-evt__row">
			<button
				class="ic-dt-evt__name-btn"
				onclick={() => (expanded[key] = !expanded[key])}
			>
				{#if payload}
					<span
						class="ic-dt-evt__chevron"
						class:ic-dt-evt__chevron--open={expanded[key]}
					>
						&#9654;
					</span>
				{/if}
				<span class="ic-dt-evt__name">{evt.matlabName}</span>
			</button>
			{#key fk}
				<span class="ic-dt-evt__count" class:ic-dt-evt__count--flash={count > 0}>
					{count}
				</span>
			{/key}
		</div>
		{#if expanded[key] && payload}
			<div class="ic-dt-evt__payload">{payload}</div>
		{/if}
	{/snippet}

	{#snippet childSection(info: ChildComponentInfo)}
		{@const cid = info.componentId}
		<div class="ic-dt-evt__child">
			<button
				class="ic-dt-evt__child-header"
				onclick={() => (expandedChildren[cid] = !expandedChildren[cid])}
			>
				<span
					class="ic-dt-evt__tree-chevron"
					class:ic-dt-evt__tree-chevron--open={expandedChildren[cid]}
				>&#9654;</span>
				<span class="ic-dt-evt__child-type">{shortType(info.componentType)}</span>
				<span class="ic-dt-evt__child-target">({info.target})</span>
			</button>

			{#if expandedChildren[cid]}
				<div class="ic-dt-evt__child-body">
					{#if info.events.length === 0}
						<div class="ic-dt-evt__empty">No events</div>
					{:else}
						{#each info.events as evt (evt.name)}
							{@render eventRow(evt, cid)}
						{/each}
					{/if}
					{#if info.children && info.children.length > 0}
						{#each info.children as grandchild (grandchild.componentId)}
							{@render childSection(grandchild)}
						{/each}
					{/if}
				</div>
			{/if}
		</div>
	{/snippet}

	<!-- Root component tree -->
	<div class="ic-dt-evt__child ic-dt-evt__child--root">
		<button
			class="ic-dt-evt__child-header"
			onclick={() => (rootExpanded = !rootExpanded)}
		>
			<span
				class="ic-dt-evt__tree-chevron"
				class:ic-dt-evt__tree-chevron--open={rootExpanded}
			>&#9654;</span>
			<span class="ic-dt-evt__child-type">{componentInfo.componentType}</span>
			<span class="ic-dt-evt__child-target">{componentInfo.componentId}</span>
		</button>

		{#if rootExpanded}
			<div class="ic-dt-evt__child-body">
				{#if componentInfo.events.length === 0}
					<div class="ic-dt-evt__empty">No events</div>
				{:else}
					{#each componentInfo.events as evt (evt.name)}
						{@render eventRow(evt, null)}
					{/each}
				{/if}

				{#if componentInfo.children && componentInfo.children.length > 0}
					{#each componentInfo.children as childInfo (childInfo.componentId)}
						{@render childSection(childInfo)}
					{/each}
				{/if}
			</div>
		{/if}
	</div>

	<div class="ic-dt-evt__footer">
		<button class="ic-dt-evt__reset" onclick={resetCounters}>Reset</button>
	</div>
</div>

<style>
	.ic-dt-evt {
		padding: 0;
		display: flex;
		flex-direction: column;
		height: 100%;
	}

	.ic-dt-evt__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}

	/* --- Row --- */

	.ic-dt-evt__row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 4px 10px;
		min-height: 26px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.08);
	}

	.ic-dt-evt__row:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	.ic-dt-evt__name-btn {
		all: unset;
		display: flex;
		align-items: center;
		gap: 6px;
		cursor: pointer;
		min-width: 0;
		flex: 1;
	}

	.ic-dt-evt__chevron {
		font-size: 0.6em;
		transition: transform 0.15s;
		display: inline-block;
		color: var(--ic-muted-foreground);
	}

	.ic-dt-evt__chevron--open {
		transform: rotate(90deg);
	}

	.ic-dt-evt__name {
		font-weight: 500;
		white-space: nowrap;
	}

	/* --- Counter badge --- */

	.ic-dt-evt__count {
		min-width: 28px;
		text-align: center;
		padding: 1px 6px;
		font-size: 0.85em;
		font-variant-numeric: tabular-nums;
		background: var(--ic-secondary);
		border-radius: 2px;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
	}

	.ic-dt-evt__count--flash {
		animation: ic-dt-evt-flash 0.5s ease-out;
	}

	@keyframes ic-dt-evt-flash {
		0% {
			background: var(--ic-primary);
			color: var(--ic-primary-foreground);
			font-weight: 700;
		}
		100% {
			background: var(--ic-secondary);
			color: var(--ic-foreground);
			font-weight: 400;
		}
	}

	/* --- Payload preview --- */

	.ic-dt-evt__payload {
		padding: 2px 10px 4px 28px;
		font-size: 0.85em;
		color: var(--ic-muted-foreground);
		word-break: break-all;
		background: rgba(128, 128, 128, 0.04);
		border-bottom: 1px solid rgba(128, 128, 128, 0.08);
	}

	/* --- Footer --- */

	.ic-dt-evt__footer {
		padding: 6px 10px;
		border-top: 1px solid var(--ic-border);
		display: flex;
		justify-content: flex-end;
		margin-top: auto;
	}

	.ic-dt-evt__reset {
		all: unset;
		cursor: pointer;
		padding: 3px 10px;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-muted-foreground);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		background: var(--ic-secondary);
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
	}

	.ic-dt-evt__reset:hover {
		color: var(--ic-foreground);
		border-color: var(--ic-muted-foreground);
	}

	/* --- Tree structure --- */

	.ic-dt-evt__child {
		border-top: 1px solid var(--ic-border);
		margin-top: 2px;
	}

	.ic-dt-evt__child--root {
		border-top: none;
		margin-top: 0;
	}

	.ic-dt-evt__child-header {
		all: unset;
		display: flex;
		align-items: center;
		gap: 6px;
		width: 100%;
		padding: 5px 10px;
		cursor: pointer;
		background: var(--ic-secondary);
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		box-sizing: border-box;
	}

	.ic-dt-evt__child-header:hover {
		background: rgba(128, 128, 128, 0.1);
	}

	.ic-dt-evt__child-type {
		font-weight: 600;
		color: var(--ic-foreground);
	}

	.ic-dt-evt__child-target {
		color: var(--ic-muted-foreground);
		font-size: 0.85em;
	}

	.ic-dt-evt__child-body {
		border-left: 2px solid var(--ic-primary);
		margin-left: 6px;
		background: rgba(128, 128, 128, 0.03);
	}

	.ic-dt-evt__tree-chevron {
		font-size: 0.7em;
		transition: transform 0.15s;
		display: inline-block;
	}

	.ic-dt-evt__tree-chevron--open {
		transform: rotate(90deg);
	}
</style>
