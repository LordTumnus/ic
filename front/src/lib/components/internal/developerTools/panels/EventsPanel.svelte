<!--
  EventsPanel.svelte — Event monitor with counters and flash animations.

  Intercepts child events by setting handlers on child.events[name].
  Each event fire increments the counter and triggers a CSS flash.
-->
<script lang="ts">
	import type { StaticChild } from '$lib/types';
	import type { ComponentInfo } from '../devtools-types';

	let {
		child,
		componentInfo
	}: {
		child: StaticChild;
		componentInfo: ComponentInfo;
	} = $props();

	// Counter and flash state per event
	let counts = $state<Record<string, number>>({});
	let flashKeys = $state<Record<string, number>>({});
	let lastPayloads = $state<Record<string, string>>({});

	// Wire up event handlers on the static child
	$effect(() => {
		for (const evt of componentInfo.events) {
			child.events[evt.name] = (data?: unknown) => {
				counts[evt.name] = (counts[evt.name] ?? 0) + 1;
				flashKeys[evt.name] = (flashKeys[evt.name] ?? 0) + 1;
				if (data !== undefined) {
					try {
						lastPayloads[evt.name] = JSON.stringify(data);
					} catch {
						lastPayloads[evt.name] = String(data);
					}
				}
			};
		}
	});

	function resetCounters() {
		for (const evt of componentInfo.events) {
			counts[evt.name] = 0;
			lastPayloads[evt.name] = '';
		}
	}

	let expanded = $state<Record<string, boolean>>({});
</script>

<div class="ic-dt-evt">
	{#if componentInfo.events.length === 0}
		<div class="ic-dt-evt__empty">No events</div>
	{:else}
		<div class="ic-dt-evt__list">
			{#each componentInfo.events as evt (evt.name)}
				{@const count = counts[evt.name] ?? 0}
				{@const fk = flashKeys[evt.name] ?? 0}
				<div class="ic-dt-evt__row">
					<button
						class="ic-dt-evt__name-btn"
						onclick={() => (expanded[evt.name] = !expanded[evt.name])}
					>
						{#if lastPayloads[evt.name]}
							<span
								class="ic-dt-evt__chevron"
								class:ic-dt-evt__chevron--open={expanded[evt.name]}
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
				{#if expanded[evt.name] && lastPayloads[evt.name]}
					<div class="ic-dt-evt__payload">{lastPayloads[evt.name]}</div>
				{/if}
			{/each}
		</div>

		<div class="ic-dt-evt__footer">
			<button class="ic-dt-evt__reset" onclick={resetCounters}>Reset Counters</button>
		</div>
	{/if}
</div>

<style>
	.ic-dt-evt {
		padding: 4px 0;
		display: flex;
		flex-direction: column;
		height: 100%;
	}

	.ic-dt-evt__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}

	.ic-dt-evt__list {
		flex: 1;
		overflow: auto;
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
</style>
