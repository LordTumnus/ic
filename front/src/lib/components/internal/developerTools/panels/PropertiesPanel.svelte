<!--
  PropertiesPanel.svelte — Type-aware property inspector.

  Reads live values from child.props (reactive proxy), writes back via
  request('setPropertyValue') for MATLAB-side type coercion.
-->
<script lang="ts">
	import type { StaticChild, RequestFn } from '$lib/types';
	import type { ComponentInfo, PropInfo } from '../devtools-types';

	let {
		child,
		componentInfo,
		request
	}: {
		child: StaticChild;
		componentInfo: ComponentInfo;
		request?: RequestFn;
	} = $props();

	// Separate visible and hidden props
	const visibleProps = $derived(componentInfo.properties.filter((p) => !p.hidden));
	const hiddenProps = $derived(componentInfo.properties.filter((p) => p.hidden));
	let showHidden = $state(false);

	// Track which property is being edited (skip reactive overwrite during typing)
	let editingProp = $state<string | null>(null);

	// Local edit buffer for text/number inputs
	let editBuffer = $state<Record<string, string>>({});

	function getDisplayValue(prop: PropInfo): string {
		const val = child.props[prop.name];
		if (val === null || val === undefined) return '';
		if (typeof val === 'object') return summarize(val, prop.type);
		return String(val);
	}

	function summarize(val: unknown, type: string): string {
		if (Array.isArray(val)) {
			if (val.length === 0) return '[]';
			if (val.length <= 3 && val.every((v) => typeof v === 'string'))
				return `["${val.join('", "')}"]`;
			return `[${val.length} items]`;
		}
		if (type.startsWith('ic.table.Column')) return `[${(val as any[]).length} columns]`;
		if (type.startsWith('ic.tree.Node')) return `[tree nodes]`;
		if (type.startsWith('ic.menu.Entry')) return `[menu entries]`;
		if (type === 'table') {
			const t = val as any;
			if (t.nRows !== undefined) return `${t.nRows}x${t.nCols} table`;
		}
		try {
			const json = JSON.stringify(val);
			return json.length > 60 ? json.slice(0, 57) + '...' : json;
		} catch {
			return '[object]';
		}
	}

	function isEditable(prop: PropInfo): boolean {
		const t = prop.type;
		return (
			t === 'string' ||
			t === 'double' ||
			t === 'single' ||
			t === 'logical' ||
			t === 'matlab.lang.OnOffSwitchState' ||
			t === 'ic.Asset' ||
			t === 'ic.asset.Icon'
		);
	}

	function isBoolean(prop: PropInfo): boolean {
		return prop.type === 'logical' || prop.type === 'matlab.lang.OnOffSwitchState';
	}

	function hasDropdown(prop: PropInfo): boolean {
		return !!prop.validation?.mustBeMember && prop.validation.mustBeMember.length > 0;
	}

	function isNumeric(prop: PropInfo): boolean {
		return prop.type === 'double' || prop.type === 'single';
	}

	function getBooleanValue(prop: PropInfo): boolean {
		const val = child.props[prop.name];
		if (prop.type === 'matlab.lang.OnOffSwitchState') return val === 'on';
		return !!val;
	}

	// --- Handlers ---

	async function setProperty(prop: PropInfo, value: unknown) {
		if (!request) return;
		await request('setPropertyValue', { matlabName: prop.matlabName, value });
	}

	function handleToggle(prop: PropInfo) {
		const newVal = !getBooleanValue(prop);
		if (prop.type === 'matlab.lang.OnOffSwitchState') {
			setProperty(prop, newVal ? 'on' : 'off');
		} else {
			setProperty(prop, newVal);
		}
	}

	function handleSelect(prop: PropInfo, e: Event) {
		const target = e.target as HTMLSelectElement;
		setProperty(prop, target.value);
	}

	function startEdit(prop: PropInfo) {
		editingProp = prop.name;
		editBuffer[prop.name] = getDisplayValue(prop);
	}

	function commitEdit(prop: PropInfo) {
		editingProp = null;
		const val = editBuffer[prop.name];
		if (val !== undefined && val !== getDisplayValue(prop)) {
			setProperty(prop, isNumeric(prop) ? Number(val) : val);
		}
	}

	function handleKeydown(prop: PropInfo, e: KeyboardEvent) {
		if (e.key === 'Enter') {
			commitEdit(prop);
			(e.target as HTMLElement)?.blur();
		} else if (e.key === 'Escape') {
			editingProp = null;
			(e.target as HTMLElement)?.blur();
		}
	}
</script>

<div class="ic-dt-props">
	{#snippet propRow(prop: PropInfo)}
		<div class="ic-dt-props__row">
			<span class="ic-dt-props__name">{prop.matlabName}</span>
			<div class="ic-dt-props__value">
				{#if isBoolean(prop)}
					<!-- Toggle checkbox -->
					<label class="ic-dt-props__toggle">
						<input
							type="checkbox"
							checked={getBooleanValue(prop)}
							onchange={() => handleToggle(prop)}
						/>
						<span class="ic-dt-props__toggle-track">
							<span class="ic-dt-props__toggle-thumb"></span>
						</span>
					</label>
				{:else if hasDropdown(prop)}
					<!-- Dropdown select -->
					<select
						class="ic-dt-props__select"
						value={String(child.props[prop.name] ?? '')}
						onchange={(e) => handleSelect(prop, e)}
					>
						{#each prop.validation.mustBeMember! as option (option)}
							<option value={option}>{option}</option>
						{/each}
					</select>
				{:else if isEditable(prop)}
					<!-- Text / number input -->
					<input
						class="ic-dt-props__input"
						type={isNumeric(prop) ? 'number' : 'text'}
						value={editingProp === prop.name
							? editBuffer[prop.name]
							: getDisplayValue(prop)}
						onfocus={() => startEdit(prop)}
						oninput={(e) => {
							editBuffer[prop.name] = (e.target as HTMLInputElement).value;
						}}
						onblur={() => commitEdit(prop)}
						onkeydown={(e) => handleKeydown(prop, e)}
					/>
				{:else}
					<!-- Read-only display -->
					<span class="ic-dt-props__readonly" title={getDisplayValue(prop)}>
						{getDisplayValue(prop)}
					</span>
				{/if}
			</div>
			<span class="ic-dt-props__type">{prop.type}</span>
		</div>
	{/snippet}

	<!-- Visible properties -->
	{#each visibleProps as prop (prop.name)}
		{@render propRow(prop)}
	{/each}

	<!-- Hidden properties (collapsed) -->
	{#if hiddenProps.length > 0}
		<button class="ic-dt-props__section-toggle" onclick={() => (showHidden = !showHidden)}>
			<span class="ic-dt-props__chevron" class:ic-dt-props__chevron--open={showHidden}>
				&#9654;
			</span>
			Hidden ({hiddenProps.length})
		</button>
		{#if showHidden}
			{#each hiddenProps as prop (prop.name)}
				{@render propRow(prop)}
			{/each}
		{/if}
	{/if}
</div>

<style>
	.ic-dt-props {
		padding: 4px 0;
	}

	/* --- Row --- */

	.ic-dt-props__row {
		display: grid;
		grid-template-columns: minmax(90px, 1fr) minmax(80px, 1.5fr) auto;
		align-items: center;
		gap: 6px;
		padding: 3px 10px;
		min-height: 26px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.08);
	}

	.ic-dt-props__row:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	/* --- Name column --- */

	.ic-dt-props__name {
		color: var(--ic-primary);
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* --- Type badge --- */

	.ic-dt-props__type {
		color: var(--ic-muted-foreground);
		font-size: 0.8em;
		white-space: nowrap;
		opacity: 0.7;
	}

	/* --- Value editors --- */

	.ic-dt-props__value {
		min-width: 0;
	}

	.ic-dt-props__input,
	.ic-dt-props__select {
		all: unset;
		width: 100%;
		box-sizing: border-box;
		padding: 2px 6px;
		background: var(--ic-background);
		border: 1px solid transparent;
		border-radius: 2px;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-foreground);
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
	}

	.ic-dt-props__input:focus,
	.ic-dt-props__select:focus {
		border-color: var(--ic-primary);
		box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
	}

	.ic-dt-props__select {
		cursor: pointer;
		appearance: auto;
	}

	.ic-dt-props__readonly {
		color: var(--ic-muted-foreground);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		display: block;
		padding: 2px 6px;
		font-style: italic;
	}

	/* --- Toggle switch (industrial) --- */

	.ic-dt-props__toggle {
		display: inline-flex;
		cursor: pointer;
	}

	.ic-dt-props__toggle input {
		position: absolute;
		opacity: 0;
		pointer-events: none;
	}

	.ic-dt-props__toggle-track {
		width: 28px;
		height: 14px;
		background: var(--ic-muted);
		border-radius: 2px;
		position: relative;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.15);
		transition: background 0.15s;
	}

	.ic-dt-props__toggle input:checked + .ic-dt-props__toggle-track {
		background: var(--ic-primary);
	}

	.ic-dt-props__toggle-thumb {
		position: absolute;
		top: 2px;
		left: 2px;
		width: 10px;
		height: 10px;
		background: var(--ic-foreground);
		border-radius: 1px;
		transition: left 0.15s;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.ic-dt-props__toggle input:checked + .ic-dt-props__toggle-track .ic-dt-props__toggle-thumb {
		left: 16px;
		background: var(--ic-primary-foreground);
	}

	/* --- Section toggle (hidden props) --- */

	.ic-dt-props__section-toggle {
		all: unset;
		display: flex;
		align-items: center;
		gap: 6px;
		width: 100%;
		padding: 4px 10px;
		cursor: pointer;
		color: var(--ic-muted-foreground);
		font-size: 0.85em;
		font-family: var(--ic-font-family);
		border-top: 1px solid var(--ic-border);
		margin-top: 2px;
	}

	.ic-dt-props__section-toggle:hover {
		color: var(--ic-foreground);
	}

	.ic-dt-props__chevron {
		font-size: 0.7em;
		transition: transform 0.15s;
		display: inline-block;
	}

	.ic-dt-props__chevron--open {
		transform: rotate(90deg);
	}
</style>
