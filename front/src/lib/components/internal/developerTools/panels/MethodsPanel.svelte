<!--
  MethodsPanel.svelte — Method executor with status indicators.

  Calls methods via svelteProps (the same mechanism StaticChild uses).
  Root methods go through child.methods; child methods go through
  Registry.instance.get(id).svelteProps.
  Shows root component and children in a collapsible tree.
-->
<script lang="ts">
	import type { StaticChild } from '$lib/types';
	import type { ComponentInfo, ChildComponentInfo, MethodInfo } from '../devtools-types';
	import Registry from '$lib/core/registry';

	let {
		child,
		componentInfo
	}: {
		child: StaticChild;
		componentInfo: ComponentInfo;
	} = $props();

	type MethodState = 'idle' | 'running' | 'success' | 'error';
	let states = $state<Record<string, MethodState>>({});

	/** Unique key for a method (root vs child) */
	function methodKey(cid: string | null, name: string): string {
		return cid ? `${cid}:${name}` : name;
	}

	/** Get the method function for root or child */
	function getMethodFn(cid: string | null, name: string): ((data?: unknown) => any) | undefined {
		if (cid === null) return child.methods[name];
		const comp = Registry.instance.get(cid) as any;
		return comp?.svelteProps?.[name];
	}

	async function executeMethod(method: MethodInfo, cid: string | null = null) {
		if (method.nInputs > 0) return;

		const key = methodKey(cid, method.name);
		states[key] = 'running';
		try {
			const fn = getMethodFn(cid, method.name);
			if (!fn) {
				states[key] = 'error';
			} else {
				const result = await fn();
				states[key] = result?.success !== false ? 'success' : 'error';
			}
		} catch {
			states[key] = 'error';
		}

		// Reset after 2 seconds
		setTimeout(() => {
			if (states[key] === 'success' || states[key] === 'error') {
				states[key] = 'idle';
			}
		}, 2000);
	}

	let rootExpanded = $state(true);
	let expandedChildren = $state<Record<string, boolean>>({});

	/** Short type label */
	function shortType(type: string): string {
		return type.split('.').pop() ?? type;
	}
</script>

<div class="ic-dt-mth">
	{#snippet methodRow(method: MethodInfo, cid: string | null)}
		{@const key = methodKey(cid, method.name)}
		{@const state = states[key] ?? 'idle'}
		{@const canExecute = method.nInputs === 0}
		<div class="ic-dt-mth__row" class:ic-dt-mth__row--disabled={!canExecute}>
			<div class="ic-dt-mth__info">
				<span class="ic-dt-mth__name">{method.matlabName}</span>
				{#if method.nInputs > 0}
					<span class="ic-dt-mth__args">({method.nInputs} arg{method.nInputs > 1 ? 's' : ''})</span>
				{/if}
			</div>
			<button
				class="ic-dt-mth__btn"
				class:ic-dt-mth__btn--running={state === 'running'}
				class:ic-dt-mth__btn--success={state === 'success'}
				class:ic-dt-mth__btn--error={state === 'error'}
				disabled={!canExecute || state === 'running'}
				title={canExecute ? `Execute ${method.matlabName}()` : 'Requires arguments'}
				onclick={() => executeMethod(method, cid)}
			>
				{#if state === 'running'}
					<span class="ic-dt-mth__spinner"></span>
				{:else if state === 'success'}
					&#10003;
				{:else if state === 'error'}
					&#10007;
				{:else}
					&#9654; Run
				{/if}
			</button>
		</div>
	{/snippet}

	{#snippet childSection(info: ChildComponentInfo)}
		{@const cid = info.componentId}
		<div class="ic-dt-mth__child">
			<button
				class="ic-dt-mth__child-header"
				onclick={() => (expandedChildren[cid] = !expandedChildren[cid])}
			>
				<span
					class="ic-dt-mth__tree-chevron"
					class:ic-dt-mth__tree-chevron--open={expandedChildren[cid]}
				>&#9654;</span>
				<span class="ic-dt-mth__child-type">{shortType(info.componentType)}</span>
				<span class="ic-dt-mth__child-target">({info.target})</span>
			</button>

			{#if expandedChildren[cid]}
				<div class="ic-dt-mth__child-body">
					{#if info.methods.length === 0}
						<div class="ic-dt-mth__empty">No methods</div>
					{:else}
						{#each info.methods as method (method.name)}
							{@render methodRow(method, cid)}
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
	<div class="ic-dt-mth__child ic-dt-mth__child--root">
		<button
			class="ic-dt-mth__child-header"
			onclick={() => (rootExpanded = !rootExpanded)}
		>
			<span
				class="ic-dt-mth__tree-chevron"
				class:ic-dt-mth__tree-chevron--open={rootExpanded}
			>&#9654;</span>
			<span class="ic-dt-mth__child-type">{componentInfo.componentType}</span>
			<span class="ic-dt-mth__child-target">{componentInfo.componentId}</span>
		</button>

		{#if rootExpanded}
			<div class="ic-dt-mth__child-body">
				{#if componentInfo.methods.length === 0}
					<div class="ic-dt-mth__empty">No methods</div>
				{:else}
					{#each componentInfo.methods as method (method.name)}
						{@render methodRow(method, null)}
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
</div>

<style>
	.ic-dt-mth {
		padding: 0;
	}

	.ic-dt-mth__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}

	/* --- Row --- */

	.ic-dt-mth__row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 4px 10px;
		min-height: 28px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.08);
	}

	.ic-dt-mth__row:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	.ic-dt-mth__row--disabled {
		opacity: 0.5;
	}

	.ic-dt-mth__info {
		display: flex;
		align-items: center;
		gap: 6px;
		min-width: 0;
		flex: 1;
	}

	.ic-dt-mth__name {
		font-weight: 500;
		white-space: nowrap;
	}

	.ic-dt-mth__args {
		color: var(--ic-muted-foreground);
		font-size: 0.8em;
		font-style: italic;
	}

	/* --- Execute button --- */

	.ic-dt-mth__btn {
		all: unset;
		cursor: pointer;
		padding: 2px 10px;
		min-width: 52px;
		text-align: center;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-foreground);
		background: var(--ic-secondary);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
		transition: background 0.15s, border-color 0.15s;
		white-space: nowrap;
	}

	.ic-dt-mth__btn:hover:not(:disabled) {
		border-color: var(--ic-muted-foreground);
	}

	.ic-dt-mth__btn:disabled {
		cursor: default;
		opacity: 0.5;
	}

	.ic-dt-mth__btn--success {
		color: var(--ic-success);
		border-color: var(--ic-success);
	}

	.ic-dt-mth__btn--error {
		color: var(--ic-destructive);
		border-color: var(--ic-destructive);
	}

	/* --- Spinner --- */

	.ic-dt-mth__spinner {
		display: inline-block;
		width: 12px;
		height: 12px;
		border: 2px solid var(--ic-muted-foreground);
		border-top-color: var(--ic-primary);
		border-radius: 50%;
		animation: ic-dt-spin 0.6s linear infinite;
	}

	@keyframes ic-dt-spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* --- Tree structure --- */

	.ic-dt-mth__child {
		border-top: 1px solid var(--ic-border);
		margin-top: 2px;
	}

	.ic-dt-mth__child--root {
		border-top: none;
		margin-top: 0;
	}

	.ic-dt-mth__child-header {
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

	.ic-dt-mth__child-header:hover {
		background: rgba(128, 128, 128, 0.1);
	}

	.ic-dt-mth__child-type {
		font-weight: 600;
		color: var(--ic-foreground);
	}

	.ic-dt-mth__child-target {
		color: var(--ic-muted-foreground);
		font-size: 0.85em;
	}

	.ic-dt-mth__child-body {
		border-left: 2px solid var(--ic-primary);
		margin-left: 6px;
		background: rgba(128, 128, 128, 0.03);
	}

	.ic-dt-mth__tree-chevron {
		font-size: 0.7em;
		transition: transform 0.15s;
		display: inline-block;
	}

	.ic-dt-mth__tree-chevron--open {
		transform: rotate(90deg);
	}
</style>
