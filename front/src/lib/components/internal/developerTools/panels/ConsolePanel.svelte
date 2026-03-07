<!--
  ConsolePanel.svelte — Terminal-like REPL for DeveloperTools.

  Captures IC logger messages and lets users execute MATLAB commands
  against the inspected component via a pseudo-workspace where `comp`
  is always available.
-->
<script lang="ts">
	import type { RequestFn } from '$lib/types';
	import type { ConsoleEntry } from '../devtools-types';
	import type { LogEntry } from '$lib/core/logger';
	import logger from '$lib/core/logger';

	let {
		request
	}: {
		request?: RequestFn;
	} = $props();

	// --- State ---

	let entries = $state<ConsoleEntry[]>([]);
	let nextId = 0;
	let inputValue = $state('');
	let history: string[] = [];
	let historyIndex = -1;
	let executing = $state(false);
	let outputEl: HTMLElement | undefined;
	let inputEl: HTMLInputElement | undefined;

	// --- Filtering ---

	let minLevel = $state('debug');
	let filterText = $state('');

	const LEVEL_RANK: Record<string, number> = { debug: 0, info: 1, warn: 2, error: 3 };

	const filteredEntries = $derived(entries.filter(entry => {
		// Level filter applies only to log entries
		if (entry.kind === 'log') {
			if (minLevel === 'none') return false;
			if (entry.level && LEVEL_RANK[entry.level] < LEVEL_RANK[minLevel]) return false;
		}
		// Text filter applies to all entry kinds
		if (filterText) {
			const q = filterText.toLowerCase();
			return entry.text.toLowerCase().includes(q)
				|| (entry.source?.toLowerCase().includes(q) ?? false);
		}
		return true;
	}));

	// --- Logger listener (setup/teardown via $effect) ---

	$effect(() => {
		return logger.addListener((entry: LogEntry) => {
			addEntry({
				id: nextId++,
				kind: 'log',
				timestamp: entry.timestamp,
				text: entry.message,
				level: entry.level,
				source: entry.source
			});
		});
	});

	// --- Helpers ---

	const LEVEL_ICON: Record<string, string> = {
		debug: '\u00B7',
		info: '\u2139',
		warn: '\u26A0',
		error: '\u2715'
	};

	function addEntry(entry: ConsoleEntry) {
		entries = [...entries, entry];
		queueMicrotask(() => {
			if (outputEl) outputEl.scrollTop = outputEl.scrollHeight;
		});
	}

	function clearEntries() {
		entries = [];
	}

	// --- Command execution ---

	async function executeCommand() {
		const cmd = inputValue.trim();
		if (!cmd || !request) return;

		// Intercept clc — clear console locally instead of sending to MATLAB
		if (cmd === 'clc') {
			inputValue = '';
			clearEntries();
			return;
		}

		addEntry({ id: nextId++, kind: 'command', timestamp: Date.now(), text: cmd });

		history.push(cmd);
		historyIndex = -1;
		inputValue = '';
		executing = true;

		try {
			const res = await request('eval', { command: cmd });
			if (res.success) {
				const data = res.data as { output: string; isError: boolean };
				if (data.isError) {
					addEntry({ id: nextId++, kind: 'error', timestamp: Date.now(), text: data.output });
				} else if (data.output) {
					addEntry({ id: nextId++, kind: 'result', timestamp: Date.now(), text: data.output });
				}
			} else {
				addEntry({ id: nextId++, kind: 'error', timestamp: Date.now(), text: String(res.data) });
			}
		} catch (e) {
			addEntry({ id: nextId++, kind: 'error', timestamp: Date.now(), text: String(e) });
		} finally {
			executing = false;
			inputEl?.focus();
		}
	}

	// --- Input key handling ---

	function handleKeyDown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			executeCommand();
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			if (history.length === 0) return;
			if (historyIndex === -1) {
				historyIndex = history.length - 1;
			} else if (historyIndex > 0) {
				historyIndex--;
			}
			inputValue = history[historyIndex];
		} else if (e.key === 'ArrowDown') {
			e.preventDefault();
			if (historyIndex === -1) return;
			if (historyIndex < history.length - 1) {
				historyIndex++;
				inputValue = history[historyIndex];
			} else {
				historyIndex = -1;
				inputValue = '';
			}
		} else if (e.key === 'l' && e.ctrlKey) {
			e.preventDefault();
			clearEntries();
		} else if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
			e.preventDefault();
			clearEntries();
		}
	}
</script>

<div class="ic-dt-con">
	<!-- Toolbar -->
	<div class="ic-dt-con__toolbar">
		<select class="ic-dt-con__level-select" bind:value={minLevel}>
			<option value="debug">Debug</option>
			<option value="info">Info</option>
			<option value="warn">Warn</option>
			<option value="error">Error</option>
			<option value="none">None</option>
		</select>

		<input
			class="ic-dt-con__filter"
			type="text"
			bind:value={filterText}
			placeholder="Filter..."
			spellcheck="false"
		/>

		<button class="ic-dt-con__clear" onclick={clearEntries} title="Clear console">
			<!-- Lucide trash-2 -->
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<polyline points="3 6 5 6 21 6"></polyline>
				<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
				<line x1="10" y1="11" x2="10" y2="17"></line>
				<line x1="14" y1="11" x2="14" y2="17"></line>
			</svg>
		</button>
	</div>

	<!-- Output area -->
	<div class="ic-dt-con__output" bind:this={outputEl}>
		{#if entries.length === 0}
			<div class="ic-dt-con__welcome">
				Type MATLAB commands below. Use <code>comp</code> to access the inspected component.
			</div>
		{/if}

		{#each filteredEntries as entry (entry.id)}
			{#if entry.kind === 'log'}
				<div class="ic-dt-con__entry ic-dt-con__entry--log ic-dt-con__entry--{entry.level}">
					<span class="ic-dt-con__icon ic-dt-con__icon--{entry.level}">{LEVEL_ICON[entry.level ?? 'info']}</span>
					<span class="ic-dt-con__source">[{entry.source}]</span>
					<span class="ic-dt-con__text">{entry.text}</span>
				</div>
			{:else if entry.kind === 'command'}
				<div class="ic-dt-con__entry ic-dt-con__entry--cmd">
					<span class="ic-dt-con__prompt">&gt;&gt;</span>
					<span class="ic-dt-con__text">{entry.text}</span>
				</div>
			{:else if entry.kind === 'result'}
				<div class="ic-dt-con__entry ic-dt-con__entry--result">
					<pre class="ic-dt-con__pre">{entry.text}</pre>
				</div>
			{:else if entry.kind === 'error'}
				<div class="ic-dt-con__entry ic-dt-con__entry--error">
					<pre class="ic-dt-con__pre">{entry.text}</pre>
				</div>
			{/if}
		{/each}
	</div>

	<!-- Input line -->
	<div class="ic-dt-con__input-row">
		<span class="ic-dt-con__input-prompt">&gt;&gt;</span>
		<input
			class="ic-dt-con__input"
			type="text"
			bind:this={inputEl}
			bind:value={inputValue}
			onkeydown={handleKeyDown}
			placeholder="Enter MATLAB command..."
			disabled={executing}
			spellcheck="false"
			autocomplete="off"
		/>
	</div>
</div>

<style>
	.ic-dt-con {
		display: flex;
		flex-direction: column;
		height: 100%;
		font-family: 'Consolas', 'Menlo', 'Monaco', monospace;
		font-size: 12px;
	}

	/* --- Toolbar --- */

	.ic-dt-con__toolbar {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 4px 10px;
		background: var(--ic-secondary);
		border-bottom: 1px solid var(--ic-border);
		flex-shrink: 0;
	}

	.ic-dt-con__level-select {
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-muted-foreground);
		background: var(--ic-background);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		padding: 1px 4px 1px 6px;
		cursor: pointer;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
		-webkit-appearance: auto;
		appearance: auto;
	}

	.ic-dt-con__level-select:focus {
		border-color: var(--ic-primary);
		outline: none;
	}

	.ic-dt-con__filter {
		all: unset;
		flex: 1;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-foreground);
		background: var(--ic-background);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		padding: 1px 6px;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
	}

	.ic-dt-con__filter:focus {
		border-color: var(--ic-primary);
	}

	.ic-dt-con__filter::placeholder {
		color: var(--ic-muted-foreground);
		opacity: 0.6;
	}

	.ic-dt-con__clear {
		all: unset;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 3px;
		color: var(--ic-muted-foreground);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		background: var(--ic-secondary);
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
	}

	.ic-dt-con__clear:hover {
		color: var(--ic-foreground);
		border-color: var(--ic-muted-foreground);
	}

	/* --- Output area (recessed channel) --- */

	.ic-dt-con__output {
		flex: 1;
		overflow-y: auto;
		padding: 6px 0;
		background: var(--ic-background);
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.12);
	}

	.ic-dt-con__welcome {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
	}

	.ic-dt-con__welcome code {
		background: var(--ic-secondary);
		padding: 1px 4px;
		border-radius: 2px;
		font-family: 'Consolas', 'Menlo', 'Monaco', monospace;
	}

	/* --- Entry rows --- */

	.ic-dt-con__entry {
		padding: 1px 10px;
		line-height: 1.5;
		display: flex;
		align-items: baseline;
		gap: 6px;
	}

	/* Log entries: icon + subtle background tint for warn/error.
	   Uses pseudo-element + opacity because Chromium 104 lacks color-mix(). */

	.ic-dt-con__entry--warn,
	.ic-dt-con__entry--error.ic-dt-con__entry--log {
		position: relative;
	}

	.ic-dt-con__entry--warn::before,
	.ic-dt-con__entry--error.ic-dt-con__entry--log::before {
		content: '';
		position: absolute;
		inset: 0;
		opacity: 0.08;
		pointer-events: none;
	}

	.ic-dt-con__entry--warn::before {
		background: var(--ic-warning);
	}

	.ic-dt-con__entry--error.ic-dt-con__entry--log::before {
		background: var(--ic-destructive);
	}

	.ic-dt-con__icon {
		flex-shrink: 0;
		width: 14px;
		text-align: center;
		font-weight: 700;
	}

	.ic-dt-con__icon--debug {
		color: var(--ic-muted-foreground);
	}

	.ic-dt-con__icon--info {
		color: var(--ic-primary);
	}

	.ic-dt-con__icon--warn {
		color: var(--ic-warning);
	}

	.ic-dt-con__icon--error {
		color: var(--ic-destructive);
	}

	.ic-dt-con__source {
		color: var(--ic-muted-foreground);
		flex-shrink: 0;
	}

	.ic-dt-con__entry--debug .ic-dt-con__text {
		color: var(--ic-muted-foreground);
	}

	.ic-dt-con__entry--warn .ic-dt-con__text {
		color: var(--ic-warning);
	}

	.ic-dt-con__entry--error.ic-dt-con__entry--log .ic-dt-con__text {
		color: var(--ic-destructive);
	}

	/* Command echo */

	.ic-dt-con__entry--cmd {
		color: var(--ic-foreground);
		font-weight: 500;
	}

	.ic-dt-con__prompt {
		color: var(--ic-primary);
		font-weight: 700;
		flex-shrink: 0;
	}

	/* Result output */

	.ic-dt-con__entry--result {
		padding-left: 26px;
	}

	.ic-dt-con__pre {
		margin: 0;
		white-space: pre-wrap;
		word-break: break-word;
		color: var(--ic-muted-foreground);
		font-family: inherit;
		font-size: inherit;
	}

	/* Error output from eval */

	.ic-dt-con__entry--error:not(.ic-dt-con__entry--log) {
		padding-left: 26px;
	}

	.ic-dt-con__entry--error:not(.ic-dt-con__entry--log) .ic-dt-con__pre {
		color: var(--ic-destructive);
	}

	/* --- Input row --- */

	.ic-dt-con__input-row {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 4px 10px;
		border-top: 1px solid var(--ic-border);
		background: var(--ic-secondary);
		flex-shrink: 0;
	}

	.ic-dt-con__input-prompt {
		color: var(--ic-primary);
		font-weight: 700;
		flex-shrink: 0;
	}

	.ic-dt-con__input {
		all: unset;
		flex: 1;
		font-family: inherit;
		font-size: inherit;
		color: var(--ic-foreground);
		caret-color: var(--ic-primary);
	}

	.ic-dt-con__input::placeholder {
		color: var(--ic-muted-foreground);
		opacity: 0.6;
	}

	.ic-dt-con__input:disabled {
		opacity: 0.5;
	}
</style>
