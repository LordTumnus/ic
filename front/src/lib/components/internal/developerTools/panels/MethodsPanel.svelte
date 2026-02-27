<!--
  MethodsPanel.svelte — Method executor with status indicators.

  Calls methods via child.methods[name]() and shows spinner/tick/cross.
  Only 0-argument methods are executable; others are shown but disabled.
-->
<script lang="ts">
	import type { StaticChild } from '$lib/types';
	import type { ComponentInfo, MethodInfo } from '../devtools-types';

	let {
		child,
		componentInfo
	}: {
		child: StaticChild;
		componentInfo: ComponentInfo;
	} = $props();

	type MethodState = 'idle' | 'running' | 'success' | 'error';
	let states = $state<Record<string, MethodState>>({});

	async function executeMethod(method: MethodInfo) {
		if (method.nInputs > 0) return;

		states[method.name] = 'running';
		try {
			const fn = child.methods[method.name];
			if (!fn) {
				states[method.name] = 'error';
			} else {
				const result = await fn();
				states[method.name] = result?.success !== false ? 'success' : 'error';
			}
		} catch {
			states[method.name] = 'error';
		}

		// Reset after 2 seconds
		const name = method.name;
		setTimeout(() => {
			if (states[name] === 'success' || states[name] === 'error') {
				states[name] = 'idle';
			}
		}, 2000);
	}
</script>

<div class="ic-dt-mth">
	{#if componentInfo.methods.length === 0}
		<div class="ic-dt-mth__empty">No methods</div>
	{:else}
		{#each componentInfo.methods as method (method.name)}
			{@const state = states[method.name] ?? 'idle'}
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
					onclick={() => executeMethod(method)}
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
		{/each}
	{/if}
</div>

<style>
	.ic-dt-mth {
		padding: 4px 0;
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
</style>
