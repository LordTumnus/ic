<!--
  PropertiesPanel.svelte — Type-aware property inspector.

  Reads live values from child.props (reactive proxy). All writes are
  routed through MATLAB via request('setNestedProp') so that property
  setters, PostSet listeners, and dependent recomputation fire correctly.
  Recursively displays child component properties in collapsible sections.
-->
<script lang="ts">
	import type { StaticChild, RequestFn } from '$lib/types';
	import type { ComponentInfo, ChildComponentInfo, PropInfo, PathSegment } from '../devtools-types';
	import Registry from '$lib/core/registry';
	import ValueTree from './ValueTree.svelte';
	import { addToast } from '$lib/components/overlay/toast/toast-registry.svelte';

	let {
		child,
		componentInfo,
		request
	}: {
		child: StaticChild;
		componentInfo: ComponentInfo;
		request?: RequestFn;
	} = $props();

	// Internal framework props that should never appear in the inspector
	const internalProps = new Set(['Targets']);

	// Separate visible and hidden props (excluding internals)
	const visibleProps = $derived(componentInfo.properties.filter((p) => !p.hidden && !internalProps.has(p.matlabName)));
	const hiddenProps = $derived(componentInfo.properties.filter((p) => p.hidden && !internalProps.has(p.matlabName)));
	let showHidden = $state(false);
	let rootExpanded = $state(true);

	// Track which property is being edited (skip reactive overwrite during typing)
	// Keys are "componentId:propName" for uniqueness across parent + children
	let editingProp = $state<string | null>(null);

	// Local edit buffer for text/number inputs
	let editBuffer = $state<Record<string, string>>({});

	// Child section collapse state (keyed by componentId) — empty = all expanded
	let collapsedChildren = $state<Record<string, boolean>>({});

	// Hidden-props expand state (keyed by componentId) — empty = all collapsed
	let expandedHidden = $state<Record<string, boolean>>({});

	// Complex property expand state (keyed by editKey)
	let expandedValues = $state<Record<string, boolean>>({});

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
		if (prop.readOnly) return false;
		const t = prop.type;
		return (
			t === 'string' ||
			t === 'char' ||
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

	/** Resolve the Component instance for silent prop writes (no @prop/ publish). */
	function resolveComponent(componentId: string | null) {
		const id = componentId ?? componentInfo.componentId;
		return Registry.instance.get(id);
	}

	/** Walk a nested path on a JS object and read the leaf value. */
	function getNestedValue(obj: unknown, path: PathSegment[]): unknown {
		let target = obj as any;
		for (const seg of path) {
			target = seg.key != null ? target[seg.key] : target[seg.index!];
			if (target == null) return target;
		}
		return target;
	}

	/** Walk a nested path on a JS object and set the leaf value in-place. */
	function applyNestedValue(obj: unknown, path: PathSegment[], value: unknown): void {
		let target = obj as any;
		for (let i = 0; i < path.length - 1; i++) {
			const seg = path[i];
			target = seg.key != null ? target[seg.key] : target[seg.index!];
			if (target == null) return;
		}
		const last = path[path.length - 1];
		if (last.key != null) target[last.key] = value;
		else target[last.index!] = value;
	}

	/** Write a property value via MATLAB request (MATLAB is the single source of truth).
	 *  Optimistically updates the UI via setPropSilently (bypasses the reactive @prop/
	 *  channel so invalid values don't reach MATLAB validators). On failure, rolls back
	 *  and shows a toast. */
	async function setPropValue(
		prop: PropInfo,
		componentId: string | null,
		value: unknown,
		path: PathSegment[] = []
	): Promise<void> {
		const current = getPropValue(componentId, prop.name);
		const comp = resolveComponent(componentId);

		// Snapshot old value for rollback.
		const oldValue =
			path.length > 0 && current != null && typeof current === 'object'
				? getNestedValue(current, path)
				: current;

		// Optimistic update — silent (no @prop/ publish to MATLAB).
		if (path.length === 0) {
			comp?.setPropSilently(prop.name, value);
		} else if (current != null && typeof current === 'object') {
			applyNestedValue(current, path, value);
		}

		if (!request) return;
		const res = await request('setNestedProp', {
			componentId: componentId ?? '',
			propName: prop.matlabName,
			path,
			value
		});

		if (!res.success) {
			// Rollback the optimistic update (also silent).
			if (path.length === 0) {
				comp?.setPropSilently(prop.name, oldValue);
			} else if (current != null && typeof current === 'object') {
				applyNestedValue(current, path, oldValue);
			}

			const msg = String(res.data).replace(/<[^>]*>/g, '');
			addToast({
				value: `${prop.matlabName}: ${msg}`,
				variant: 'destructive',
				duration: 5
			});
		}
	}

	function handleToggle(prop: PropInfo, componentId: string | null = null) {
		const newVal = !getBooleanValue(prop, componentId);
		if (prop.type === 'matlab.lang.OnOffSwitchState') {
			setPropValue(prop, componentId, newVal ? 'on' : 'off');
		} else {
			setPropValue(prop, componentId, newVal);
		}
	}

	function handleSelect(prop: PropInfo, e: Event, componentId: string | null = null) {
		const target = e.target as HTMLSelectElement;
		setPropValue(prop, componentId, target.value);
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
		delete editBuffer[key];
		if (val !== undefined && val !== getDisplayValue(prop, componentId)) {
			setPropValue(prop, componentId, isNumeric(prop) ? Number(val) : val);
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

	// --- Array editing support ---

	/** True when a property holds an array value.
	 *  Checks both the live value AND typeInfo.kind — the latter catches the case
	 *  where JSON serialization collapsed a single-element array [x] to scalar x. */
	function isArrayValue(prop: PropInfo, cid: string | null): boolean {
		if (prop.typeInfo?.kind === 'array') return true;
		return Array.isArray(getPropValue(cid, prop.name));
	}

	/** Get the comma-separated representation of the live array value.
	 *  Handles scalars (JSON-collapsed single-element arrays). */
	function getArrayDisplay(prop: PropInfo, cid: string | null): string {
		const val = getPropValue(cid, prop.name);
		if (Array.isArray(val)) return val.length === 0 ? '' : val.join(', ');
		// Scalar: JSON collapsed [x] to x — show as single entry
		if (val == null || val === '') return '';
		return String(val);
	}

	function startArrayEdit(prop: PropInfo, cid: string | null) {
		const key = editKey(prop, cid);
		editingProp = key;
		editBuffer[key] = getArrayDisplay(prop, cid);
	}

	function commitArrayEdit(prop: PropInfo, cid: string | null) {
		const key = editKey(prop, cid);
		editingProp = null;
		const raw = editBuffer[key];
		delete editBuffer[key];
		if (raw === undefined) return;
		const parsed = raw.trim() === ''
			? []
			: raw.split(',').map((s) => s.trim()).filter((s) => s !== '')
				.map((s) => isNumeric(prop) ? Number(s) : s);
		setPropValue(prop, cid, parsed);
		// Auto-expand the ValueTree so the user sees the result
		if (parsed.length > 0) expandedValues[key] = true;
	}

	function handleArrayKeydown(prop: PropInfo, e: KeyboardEvent, cid: string | null) {
		if (e.key === 'Enter') {
			commitArrayEdit(prop, cid);
			(e.target as HTMLElement)?.blur();
		} else if (e.key === 'Escape') {
			editingProp = null;
			(e.target as HTMLElement)?.blur();
		}
	}

	// --- Complex type support ---

	/** True when a property has structural type info that can be expanded. */
	function isComplex(prop: PropInfo): boolean {
		if (!prop.typeInfo) return false;
		const k = prop.typeInfo.kind;
		return (
			k === 'struct' || k === 'object' ||
			k === 'objectArray' || k === 'structArray' ||
			k === 'array' || k === 'cell'
		);
	}

	/** Whether the expanded tree should show an "add entry" button.
	 *  Only for non-readOnly primitive arrays (double[], string[], etc.) — not for
	 *  complex types like ic.table.Column[] or struct arrays. */
	function canAddElement(prop: PropInfo): boolean {
		if (prop.readOnly) return false;
		const ti = prop.typeInfo;
		if (!ti || ti.kind !== 'array') return false;
		const elClass = ti.elementTypeInfo?.className;
		return elClass === 'double' || elClass === 'single' ||
			elClass === 'string' || elClass === 'char' ||
			elClass === 'logical';
	}

	/** Coerce the live value to a JS array, handling JSON scalar collapse. */
	function toLiveArray(cid: string | null, propName: string): unknown[] {
		const val = getPropValue(cid, propName);
		if (Array.isArray(val)) return val;
		if (val != null) return [val]; // scalar from JSON collapse
		return [];
	}

	function addArrayElement(prop: PropInfo, cid: string | null) {
		const arr = [...toLiveArray(cid, prop.name)];
		const elClass = prop.typeInfo?.elementTypeInfo?.className;
		const defaultVal = (elClass === 'double' || elClass === 'single') ? 0
			: (elClass === 'logical') ? false
			: '';
		arr.push(defaultVal);
		setPropValue(prop, cid, arr);
	}

	function removeArrayElement(prop: PropInfo, cid: string | null, index: number) {
		const arr = toLiveArray(cid, prop.name).filter((_: unknown, i: number) => i !== index);
		setPropValue(prop, cid, arr);
	}

	/** Generate a compact summary string from typeInfo + live value. */
	function typeInfoSummary(prop: PropInfo, liveVal?: unknown): string {
		const ti = prop.typeInfo!;
		const total = ti.size[0] * ti.size[1];
		switch (ti.kind) {
			case 'struct': {
				const n = (liveVal != null && typeof liveVal === 'object')
					? Object.keys(liveVal as object).length
					: ti.children.length;
				return `{${n} field${n !== 1 ? 's' : ''}}`;
			}
			case 'structArray':  return `[${total} structs]`;
			case 'object':       return shortType(ti.className);
			case 'objectArray':  return `[${total} ${shortType(ti.className)}]`;
			case 'array':        return `[${total} ${ti.className}]`;
			case 'cell':         return `{${total} cells}`;
			default:             return '';
		}
	}
</script>

<div class="ic-dt-props">
	{#snippet propRow(prop: PropInfo, cid: string | null)}
		{@const key = editKey(prop, cid)}
		{@const complex = isComplex(prop)}
		<div class="ic-dt-props__row">
			<span class="ic-dt-props__name" title={prop.readOnly ? `${prop.matlabName} (read-only)` : prop.matlabName}>
				{#if complex}
					<!-- svelte-ignore a11y_click_events_have_key_events -->
					<span
						class="ic-dt-props__chevron ic-dt-props__chevron--inline"
						class:ic-dt-props__chevron--open={expandedValues[key]}
						onclick={() => (expandedValues[key] = !expandedValues[key])}
						role="button"
						tabindex="-1"
					>&#9654;</span>
				{/if}
				{prop.matlabName}
				{#if prop.readOnly}
					<span class="ic-dt-props__lock" title="Read-only (non-public SetAccess)">
						<!-- No-entry / stop sign icon -->
						<svg viewBox="0 0 16 16" width="11" height="11" fill="none">
							<circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1.5"/>
							<line x1="4" y1="8" x2="12" y2="8" stroke="currentColor" stroke-width="1.5"/>
						</svg>
					</span>
				{/if}
			</span>
			<div class="ic-dt-props__value">
				{#if isBoolean(prop) && !prop.readOnly}
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
				{:else if hasDropdown(prop) && !prop.readOnly}
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
				{:else if isEditable(prop) && isArrayValue(prop, cid)}
					<!-- Comma-separated array input -->
					<input
						class="ic-dt-props__input"
						type="text"
						placeholder="comma-separated"
						value={editingProp === key
							? editBuffer[key]
							: getArrayDisplay(prop, cid)}
						onfocus={() => startArrayEdit(prop, cid)}
						oninput={(e) => {
							editBuffer[key] = (e.target as HTMLInputElement).value;
						}}
						onblur={() => commitArrayEdit(prop, cid)}
						onkeydown={(e) => handleArrayKeydown(prop, e, cid)}
					/>
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
				{:else if complex}
					<!-- Complex type: clickable summary -->
					<button
						class="ic-dt-props__expand-btn"
						onclick={() => (expandedValues[key] = !expandedValues[key])}
					>
						{typeInfoSummary(prop, getPropValue(cid, prop.name))}
					</button>
				{:else}
					<!-- Read-only display -->
					<span class="ic-dt-props__readonly" title={getDisplayValue(prop, cid)}>
						{getDisplayValue(prop, cid)}
					</span>
				{/if}
			</div>
			<span class="ic-dt-props__type">{prop.type}</span>
		</div>
		<!-- Expanded value tree (below the row) -->
		{#if complex && expandedValues[key]}
			<div class="ic-dt-props__value-tree">
				<ValueTree
					value={getPropValue(cid, prop.name)}
					typeInfo={prop.typeInfo!}
					oncommit={(path, val) => setPropValue(prop, cid, val, path)}
					onremove={canAddElement(prop)
						? (index) => removeArrayElement(prop, cid, index)
						: undefined}
				/>
				{#if canAddElement(prop)}
					<button
						class="ic-dt-props__add-btn"
						onclick={() => addArrayElement(prop, cid)}
					>+ Add</button>
				{/if}
			</div>
		{/if}
	{/snippet}

	{#snippet childSection(info: ChildComponentInfo)}
		{@const cid = info.componentId}
		{@const vis = info.properties.filter((p: PropInfo) => !p.hidden && !internalProps.has(p.matlabName))}
		{@const hid = info.properties.filter((p: PropInfo) => p.hidden && !internalProps.has(p.matlabName))}
		<div class="ic-dt-props__child">
			<button
				class="ic-dt-props__child-header"
				onclick={() => (collapsedChildren[cid] = !collapsedChildren[cid])}
			>
				<span
					class="ic-dt-props__chevron"
					class:ic-dt-props__chevron--open={!collapsedChildren[cid]}
				>&#9654;</span>
				<span class="ic-dt-props__child-type">{shortType(info.componentType)}</span>
				<span class="ic-dt-props__child-target">({info.target})</span>
			</button>

			{#if !collapsedChildren[cid]}
				<div class="ic-dt-props__child-body">
					{#each vis as prop (prop.name)}
						{@render propRow(prop, cid)}
					{/each}
					{#if hid.length > 0}
						<button
							class="ic-dt-props__section-toggle"
							onclick={() => (expandedHidden[cid] = !expandedHidden[cid])}
						>
							<span
								class="ic-dt-props__chevron"
								class:ic-dt-props__chevron--open={expandedHidden[cid]}
							>&#9654;</span>
							Hidden ({hid.length})
						</button>
						{#if expandedHidden[cid]}
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
		grid-template-columns: minmax(80px, 1fr) minmax(60px, 1.5fr) 72px;
		align-items: center;
		gap: 4px;
		padding: 2px 8px;
		min-height: 22px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.06);
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

	/* --- Read-only indicator --- */

	.ic-dt-props__lock {
		display: inline-flex;
		align-items: center;
		margin-left: 3px;
		color: var(--ic-destructive);
		opacity: 0.6;
		vertical-align: baseline;
	}

	/* --- Type badge --- */

	.ic-dt-props__type {
		color: var(--ic-muted-foreground);
		font-size: 0.75em;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		opacity: 0.7;
		text-align: right;
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
		padding: 2px 8px;
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
		padding: 3px 8px;
		cursor: pointer;
		background: transparent;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		box-sizing: border-box;
	}

	.ic-dt-props__child-header:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	.ic-dt-props__child--root > .ic-dt-props__child-header {
		background: var(--ic-secondary);
	}

	.ic-dt-props__child--root > .ic-dt-props__child-header:hover {
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

	/* --- Complex property expand --- */

	.ic-dt-props__chevron--inline {
		cursor: pointer;
		margin-right: 2px;
		vertical-align: baseline;
	}

	.ic-dt-props__expand-btn {
		all: unset;
		display: block;
		cursor: pointer;
		padding: 1px 4px;
		border-radius: 2px;
		color: var(--ic-muted-foreground);
		font-style: italic;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		width: 100%;
		box-sizing: border-box;
	}

	.ic-dt-props__expand-btn:hover {
		background: rgba(128, 128, 128, 0.08);
		color: var(--ic-foreground);
	}

	.ic-dt-props__value-tree {
		border-left: 2px solid var(--ic-border);
		margin-left: 8px;
		padding: 2px 0;
		background: rgba(128, 128, 128, 0.02);
	}

	.ic-dt-props__add-btn {
		all: unset;
		display: block;
		cursor: pointer;
		padding: 1px 8px;
		margin-top: 1px;
		color: var(--ic-primary);
		font-family: var(--ic-font-family);
		font-size: 0.85em;
		opacity: 0.7;
	}

	.ic-dt-props__add-btn:hover {
		opacity: 1;
	}
</style>
