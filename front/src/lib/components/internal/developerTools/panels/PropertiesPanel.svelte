<!--
  PropertiesPanel.svelte — Type-aware property inspector.

  Reads live values from child.props (reactive proxy), writes back via
  request('setPropertyValue') for MATLAB-side type coercion.
  Recursively displays child component properties in collapsible sections.
-->
<script lang="ts">
	import type { StaticChild, RequestFn } from '$lib/types';
	import type { ComponentInfo, ChildComponentInfo, PropInfo } from '../devtools-types';
	import Registry from '$lib/core/registry';

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
	let rootExpanded = $state(true);

	// Track which property is being edited (skip reactive overwrite during typing)
	// Keys are "componentId:propName" for uniqueness across parent + children
	let editingProp = $state<string | null>(null);

	// Local edit buffer for text/number inputs
	let editBuffer = $state<Record<string, string>>({});

	// Child section expand state (keyed by componentId)
	let expandedChildren = $state<Record<string, boolean>>({});

	// --- Value access (parameterized by componentId) ---

	/** Read a prop value. null componentId = parent, string = child via Registry. */
	function getPropValue(componentId: string | null, propName: string): unknown {
		if (componentId === null) return child.props[propName];
		const comp = Registry.instance.get(componentId) as any;
		return comp?.svelteProps?.[propName];
	}

	function getDisplayValue(prop: PropInfo, componentId: string | null = null): string {
		const val = getPropValue(componentId, prop.name);
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

	function getBooleanValue(prop: PropInfo, componentId: string | null = null): boolean {
		const val = getPropValue(componentId, prop.name);
		if (prop.type === 'matlab.lang.OnOffSwitchState') return val === 'on';
		return !!val;
	}

	/** Edit key: unique across parent + children */
	function editKey(prop: PropInfo, componentId: string | null): string {
		return componentId ? `${componentId}:${prop.name}` : prop.name;
	}

	/** Short type label: "ic.Button" → "Button" */
	function shortType(type: string): string {
		return type.split('.').pop() ?? type;
	}

	// --- Handlers (parameterized by componentId) ---

	async function setProperty(
		prop: PropInfo,
		value: unknown,
		componentId: string | null = null
	) {
		if (!request) return;
		const payload: Record<string, unknown> = { matlabName: prop.matlabName, value };
		if (componentId) payload.componentId = componentId;
		await request('setPropertyValue', payload);
	}

	function handleToggle(prop: PropInfo, componentId: string | null = null) {
		const newVal = !getBooleanValue(prop, componentId);
		if (prop.type === 'matlab.lang.OnOffSwitchState') {
			setProperty(prop, newVal ? 'on' : 'off', componentId);
		} else {
			setProperty(prop, newVal, componentId);
		}
	}

	function handleSelect(prop: PropInfo, e: Event, componentId: string | null = null) {
		const target = e.target as HTMLSelectElement;
		setProperty(prop, target.value, componentId);
	}

	function startEdit(prop: PropInfo, componentId: string | null = null) {
		const key = editKey(prop, componentId);
		editingProp = key;
		editBuffer[key] = getDisplayValue(prop, componentId);
	}

	function commitEdit(prop: PropInfo, componentId: string | null = null) {
		const key = editKey(prop, componentId);
		editingProp = null;
		const val = editBuffer[key];
		if (val !== undefined && val !== getDisplayValue(prop, componentId)) {
			setProperty(prop, isNumeric(prop) ? Number(val) : val, componentId);
		}
	}

	function handleKeydown(prop: PropInfo, e: KeyboardEvent, componentId: string | null = null) {
		if (e.key === 'Enter') {
			commitEdit(prop, componentId);
			(e.target as HTMLElement)?.blur();
		} else if (e.key === 'Escape') {
			editingProp = null;
			(e.target as HTMLElement)?.blur();
		}
	}
</script>

<div class="ic-dt-props">
	{#snippet propRow(prop: PropInfo, cid: string | null)}
		{@const key = editKey(prop, cid)}
		<div class="ic-dt-props__row">
			<span class="ic-dt-props__name">{prop.matlabName}</span>
			<div class="ic-dt-props__value">
				{#if isBoolean(prop)}
					<!-- Toggle checkbox -->
					<label class="ic-dt-props__toggle">
						<input
							type="checkbox"
							checked={getBooleanValue(prop, cid)}
							onchange={() => handleToggle(prop, cid)}
						/>
						<span class="ic-dt-props__toggle-track">
							<span class="ic-dt-props__toggle-thumb"></span>
						</span>
					</label>
				{:else if hasDropdown(prop)}
					<!-- Dropdown select -->
					<select
						class="ic-dt-props__select"
						value={String(getPropValue(cid, prop.name) ?? '')}
						onchange={(e) => handleSelect(prop, e, cid)}
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
						value={editingProp === key
							? editBuffer[key]
							: getDisplayValue(prop, cid)}
						onfocus={() => startEdit(prop, cid)}
						oninput={(e) => {
							editBuffer[key] = (e.target as HTMLInputElement).value;
						}}
						onblur={() => commitEdit(prop, cid)}
						onkeydown={(e) => handleKeydown(prop, e, cid)}
					/>
				{:else}
					<!-- Read-only display -->
					<span class="ic-dt-props__readonly" title={getDisplayValue(prop, cid)}>
						{getDisplayValue(prop, cid)}
					</span>
				{/if}
			</div>
			<span class="ic-dt-props__type">{prop.type}</span>
		</div>
	{/snippet}

	{#snippet childSection(info: ChildComponentInfo)}
		{@const cid = info.componentId}
		{@const vis = info.properties.filter((p: PropInfo) => !p.hidden)}
		{@const hid = info.properties.filter((p: PropInfo) => p.hidden)}
		<div class="ic-dt-props__child">
			<button
				class="ic-dt-props__child-header"
				onclick={() => (expandedChildren[cid] = !expandedChildren[cid])}
			>
				<span
					class="ic-dt-props__chevron"
					class:ic-dt-props__chevron--open={expandedChildren[cid]}
				>&#9654;</span>
				<span class="ic-dt-props__child-type">{shortType(info.componentType)}</span>
				<span class="ic-dt-props__child-target">({info.target})</span>
			</button>

			{#if expandedChildren[cid]}
				<div class="ic-dt-props__child-body">
					{#each vis as prop (prop.name)}
						{@render propRow(prop, cid)}
					{/each}
					{#if hid.length > 0}
						<button
							class="ic-dt-props__section-toggle"
							onclick={() => (expandedChildren[cid + ':hidden'] = !expandedChildren[cid + ':hidden'])}
						>
							<span
								class="ic-dt-props__chevron"
								class:ic-dt-props__chevron--open={expandedChildren[cid + ':hidden']}
							>&#9654;</span>
							Hidden ({hid.length})
						</button>
						{#if expandedChildren[cid + ':hidden']}
							{#each hid as prop (prop.name)}
								{@render propRow(prop, cid)}
							{/each}
						{/if}
					{/if}
					<!-- Recursive: child's own children -->
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
	<div class="ic-dt-props__child ic-dt-props__child--root">
		<button
			class="ic-dt-props__child-header"
			onclick={() => (rootExpanded = !rootExpanded)}
		>
			<span
				class="ic-dt-props__chevron"
				class:ic-dt-props__chevron--open={rootExpanded}
			>&#9654;</span>
			<span class="ic-dt-props__child-type">{componentInfo.componentType}</span>
			<span class="ic-dt-props__child-target">{componentInfo.componentId}</span>
		</button>

		{#if rootExpanded}
			<div class="ic-dt-props__child-body">
				<!-- Visible properties -->
				{#each visibleProps as prop (prop.name)}
					{@render propRow(prop, null)}
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
							{@render propRow(prop, null)}
						{/each}
					{/if}
				{/if}

				<!-- Child components -->
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

	/* --- Child component sections --- */

	.ic-dt-props__child {
		border-top: 1px solid var(--ic-border);
		margin-top: 2px;
	}

	.ic-dt-props__child--root {
		border-top: none;
		margin-top: 0;
	}

	.ic-dt-props__child-header {
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

	.ic-dt-props__child-header:hover {
		background: rgba(128, 128, 128, 0.1);
	}

	.ic-dt-props__child-type {
		font-weight: 600;
		color: var(--ic-foreground);
	}

	.ic-dt-props__child-target {
		color: var(--ic-muted-foreground);
		font-size: 0.85em;
	}

	.ic-dt-props__child-body {
		border-left: 2px solid var(--ic-primary);
		margin-left: 6px;
		background: rgba(128, 128, 128, 0.03);
	}
</style>
