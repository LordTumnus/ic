<!--
  ValueTree.svelte — Recursive expandable tree for complex property values.

  Renders the children of a complex MATLAB value (struct fields, object
  properties, array elements) in a debugger-style indented tree.
  Leaf primitives are editable inline; complex sub-values are expandable.

  Pattern follows DomTreeNode.svelte: recursive self-import, depth-based
  indentation, expand/collapse with chevrons.
-->
<script lang="ts">
	import type { TypeInfo, TypeInfoChild, PathSegment, PropValidation } from '../devtools-types';
	import ValueTree from './ValueTree.svelte';

	let {
		value,
		typeInfo,
		path = [] as PathSegment[],
		depth = 0,
		oncommit
	}: {
		/** Live JS value for this node (from reactive proxy) */
		value: unknown;
		/** Structural metadata from MATLAB introspectType */
		typeInfo: TypeInfo;
		/** Path segments from root property to this node (for nested writes) */
		path?: PathSegment[];
		/** Indentation depth */
		depth?: number;
		/** Callback to commit a leaf edit: (fullPath, newValue) */
		oncommit: (path: PathSegment[], value: unknown) => void;
	} = $props();

	const INDENT = 14;
	const PAGE_SIZE = 20;

	// --- Expand/collapse state for children ---
	let expandedIds = $state<Record<string, boolean>>({});
	let showCount = $state(PAGE_SIZE);

	// --- Derived: build the list of child entries ---

	interface Entry {
		id: string;
		label: string;
		value: unknown;
		typeInfo: TypeInfo;
		path: PathSegment[];
		validation?: PropValidation;
	}

	/** Total number of indexed elements (for array kinds) */
	const totalElements = $derived(
		typeInfo.size[0] * typeInfo.size[1]
	);

	/** Whether this typeInfo represents an indexed collection */
	const isIndexed = $derived(
		typeInfo.kind === 'array' ||
		typeInfo.kind === 'objectArray' ||
		typeInfo.kind === 'structArray'
	);

	/** Whether this typeInfo represents a named collection (struct/object) */
	const isNamed = $derived(
		typeInfo.kind === 'struct' || typeInfo.kind === 'object'
	);

	/** Build entries from typeInfo + live value.
	 *  For structs, typeInfo.children may be stale (snapshot from initial introspection).
	 *  We merge with the live value's keys so dynamic fields (e.g. Filters) appear. */
	const entries = $derived.by((): Entry[] => {
		if (isNamed) {
			const knownKeys = new Set(typeInfo.children.map((c: TypeInfoChild) => c.key));
			const known: Entry[] = typeInfo.children.map((child: TypeInfoChild) => ({
				id: child.key,
				label: child.key,
				value: resolveNamedValue(child.key),
				typeInfo: child.typeInfo,
				path: [...path, { key: child.key }],
				validation: child.validation
			}));
			// Add any live keys missing from typeInfo (dynamic struct fields)
			if (typeInfo.kind === 'struct' && value != null && typeof value === 'object') {
				for (const key of Object.keys(value as Record<string, unknown>)) {
					if (!knownKeys.has(key)) {
						const v = (value as Record<string, unknown>)[key];
						known.push({
							id: key,
							label: key,
							value: v,
							typeInfo: inferTypeInfo(v),
							path: [...path, { key }]
						});
					}
				}
			}
			return known;
		}

		// Indexed collection with per-element children (heterogeneous objectArray)
		if (isIndexed && typeInfo.children.length > 0) {
			const arr = Array.isArray(value) ? value : [];
			return typeInfo.children
				.filter((_: TypeInfoChild, i: number) => i < showCount)
				.map((child: TypeInfoChild) => ({
					id: String(child.index ?? child.key),
					label: `[${(child.index ?? 0) + 1}]`,
					value: arr[child.index ?? 0],
					typeInfo: child.typeInfo,
					path: [...path, { index: child.index ?? 0 }]
				}));
		}

		// Indexed collection with shared element type (homogeneous arrays)
		if (isIndexed && typeInfo.elementTypeInfo) {
			const arr = Array.isArray(value) ? value : [];
			const count = Math.min(showCount, totalElements, arr.length);
			const result: Entry[] = [];
			for (let i = 0; i < count; i++) {
				result.push({
					id: String(i),
					label: `[${i + 1}]`, // 1-based for MATLAB users
					value: arr[i],
					typeInfo: typeInfo.elementTypeInfo,
					path: [...path, { index: i }]
				});
			}
			return result;
		}

		// Cell array: children have explicit indices
		if (typeInfo.kind === 'cell') {
			const arr = Array.isArray(value) ? value : [];
			return typeInfo.children
				.filter((_: TypeInfoChild, i: number) => i < showCount)
				.map((child: TypeInfoChild) => ({
					id: String(child.index ?? child.key),
					label: `[${(child.index ?? 0) + 1}]`,
					value: arr[child.index ?? 0],
					typeInfo: child.typeInfo,
					path: [...path, { index: child.index ?? 0 }]
				}));
		}

		return [];
	});

	const remaining = $derived(
		isIndexed
			? Math.max(0, Math.min(totalElements, (Array.isArray(value) ? value.length : 0)) - showCount)
			: typeInfo.kind === 'cell'
				? Math.max(0, typeInfo.children.length - showCount)
				: 0
	);

	// --- Value resolution ---

	/** Resolve a named child value from the JS object, handling camelCase mismatch. */
	function resolveNamedValue(key: string): unknown {
		if (value == null || typeof value !== 'object') return undefined;
		const obj = value as Record<string, unknown>;
		// Exact match (structs preserve MATLAB field names)
		if (key in obj) return obj[key];
		// camelCase fallback (objects with toStruct use camelCase)
		const camel = key.charAt(0).toLowerCase() + key.slice(1);
		if (camel in obj) return obj[camel];
		return undefined;
	}

	// --- Display helpers ---

	function isExpandableKind(kind: string): boolean {
		return (
			kind === 'struct' ||
			kind === 'object' ||
			kind === 'objectArray' ||
			kind === 'structArray' ||
			kind === 'array' ||
			kind === 'cell'
		);
	}

	function isEditableLeaf(ti: TypeInfo): boolean {
		if (ti.kind !== 'primitive') return false;
		const c = ti.className;
		return (
			c === 'string' ||
			c === 'double' ||
			c === 'single' ||
			c === 'char' ||
			c === 'logical' ||
			c === 'matlab.lang.OnOffSwitchState'
		);
	}

	function isBooleanType(ti: TypeInfo): boolean {
		return (
			ti.className === 'logical' ||
			ti.className === 'matlab.lang.OnOffSwitchState'
		);
	}

	function isNumericType(ti: TypeInfo): boolean {
		return ti.className === 'double' || ti.className === 'single';
	}

	function shortClass(name: string): string {
		return name.split('.').pop() ?? name;
	}

	/** Infer a basic TypeInfo from a live JS value (fallback for dynamic structs). */
	function inferTypeInfo(val: unknown): TypeInfo {
		if (typeof val === 'boolean')
			return { kind: 'primitive', className: 'logical', size: [1, 1], children: [] };
		if (typeof val === 'number')
			return { kind: 'primitive', className: 'double', size: [1, 1], children: [] };
		if (typeof val === 'string')
			return { kind: 'primitive', className: 'string', size: [1, 1], children: [] };
		if (Array.isArray(val))
			return { kind: 'cell', className: 'cell', size: [1, val.length], children: [] };
		if (val != null && typeof val === 'object')
			return { kind: 'struct', className: 'struct', size: [1, 1], children: [] };
		return { kind: 'primitive', className: 'string', size: [1, 1], children: [] };
	}

	/** Summary string — for structs, count from live value when available. */
	function getSummary(ti: TypeInfo, liveVal?: unknown): string {
		const total = ti.size[0] * ti.size[1];
		switch (ti.kind) {
			case 'struct': {
				const n = (liveVal != null && typeof liveVal === 'object')
					? Object.keys(liveVal as object).length
					: ti.children.length;
				return `{${n} field${n !== 1 ? 's' : ''}}`;
			}
			case 'structArray':
				return `[${total} structs]`;
			case 'object':
				return shortClass(ti.className);
			case 'objectArray':
				return `[${total} ${shortClass(ti.className)}]`;
			case 'array':
				return `[${total} ${ti.className}]`;
			case 'cell':
				return `{${total} cells}`;
			case 'function_handle':
				return '@function_handle';
			case 'opaque':
				return shortClass(ti.className);
			case 'truncated':
				return '{...}';
			default:
				return '';
		}
	}

	function formatLeafValue(val: unknown, ti: TypeInfo): string {
		if (val == null) return 'null';
		if (ti.className === 'string' || ti.className === 'char') return `"${val}"`;
		return String(val);
	}

	function getBooleanChecked(val: unknown, className: string): boolean {
		if (className === 'matlab.lang.OnOffSwitchState') return val === 'on';
		return !!val;
	}

	// --- Edit state ---
	let editingId = $state<string | null>(null);
	let editBuffer = $state('');

	function startEdit(entry: Entry) {
		editingId = entry.id;
		editBuffer = entry.value == null ? '' : String(entry.value);
	}

	function commitEdit(entry: Entry) {
		editingId = null;
		let newVal: unknown = editBuffer;
		if (isNumericType(entry.typeInfo)) newVal = Number(editBuffer);
		if (editBuffer !== String(entry.value ?? '')) {
			oncommit(entry.path, newVal);
		}
	}

	function handleToggle(entry: Entry, className: string) {
		if (className === 'matlab.lang.OnOffSwitchState') {
			oncommit(entry.path, entry.value === 'on' ? 'off' : 'on');
		} else {
			oncommit(entry.path, !entry.value);
		}
	}

	function handleKeydown(e: KeyboardEvent, entry: Entry) {
		if (e.key === 'Enter') {
			commitEdit(entry);
			(e.target as HTMLElement)?.blur();
		} else if (e.key === 'Escape') {
			editingId = null;
			(e.target as HTMLElement)?.blur();
		}
	}

	function toggleExpand(id: string) {
		expandedIds[id] = !expandedIds[id];
	}

	function handleShowMore() {
		showCount += PAGE_SIZE;
	}
</script>

{#each entries as entry (entry.id)}
	{@const expandable = isExpandableKind(entry.typeInfo.kind)}
	{@const editable = isEditableLeaf(entry.typeInfo)}
	{@const boolType = isBooleanType(entry.typeInfo)}
	{@const numType = isNumericType(entry.typeInfo)}
	{@const hasDropdown = !!entry.validation?.mustBeMember?.length}

	<!-- Row -->
	<div class="ic-dt-vt__row" style="padding-left: {depth * INDENT}px">
		<!-- Toggle or spacer -->
		{#if expandable}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<span
				class="ic-dt-vt__toggle"
				class:ic-dt-vt__toggle--open={expandedIds[entry.id]}
				onclick={() => toggleExpand(entry.id)}
				role="button"
				tabindex="-1"
			>&#9654;</span>
		{:else}
			<span class="ic-dt-vt__spacer"></span>
		{/if}

		<!-- Label -->
		<span class={entry.label.startsWith('[') ? 'ic-dt-vt__index' : 'ic-dt-vt__key'}>
			{entry.label}</span><span class="ic-dt-vt__colon">:&nbsp;</span>

		<!-- Value -->
		{#if expandable}
			<span class="ic-dt-vt__summary">{getSummary(entry.typeInfo, entry.value)}</span>
		{:else if editable && hasDropdown}
			<select
				class="ic-dt-vt__select"
				value={String(entry.value ?? '')}
				onchange={(e) => oncommit(entry.path, (e.target as HTMLSelectElement).value)}
			>
				{#each entry.validation!.mustBeMember! as option (option)}
					<option value={option}>{option}</option>
				{/each}
			</select>
		{:else if editable && boolType}
			<label class="ic-dt-vt__bool">
				<input
					type="checkbox"
					checked={getBooleanChecked(entry.value, entry.typeInfo.className)}
					onchange={() => handleToggle(entry, entry.typeInfo.className)}
				/>
				<span class="ic-dt-vt__bool-track">
					<span class="ic-dt-vt__bool-thumb"></span>
				</span>
				<span class="ic-dt-vt__bool-label">
					{entry.typeInfo.className === 'matlab.lang.OnOffSwitchState'
						? (entry.value === 'on' ? 'on' : 'off')
						: (entry.value ? 'true' : 'false')}
				</span>
			</label>
		{:else if editable}
			<input
				class="ic-dt-vt__input"
				type={numType ? 'number' : 'text'}
				value={editingId === entry.id ? editBuffer : (entry.value == null ? '' : String(entry.value))}
				onfocus={() => startEdit(entry)}
				oninput={(e) => { editBuffer = (e.target as HTMLInputElement).value; }}
				onblur={() => commitEdit(entry)}
				onkeydown={(e) => handleKeydown(e, entry)}
			/>
		{:else if entry.typeInfo.kind === 'function_handle'}
			<span class="ic-dt-vt__opaque">@function_handle</span>
		{:else if entry.typeInfo.kind === 'opaque'}
			<span class="ic-dt-vt__opaque">{shortClass(entry.typeInfo.className)}</span>
		{:else if entry.typeInfo.kind === 'truncated'}
			<span class="ic-dt-vt__opaque">{'{...'}</span>
		{:else}
			<span class="ic-dt-vt__leaf">{formatLeafValue(entry.value, entry.typeInfo)}</span>
		{/if}

		<!-- Type badge -->
		<span class="ic-dt-vt__type">{shortClass(entry.typeInfo.className)}</span>
	</div>

	<!-- Expanded children (recursive) -->
	{#if expandable && expandedIds[entry.id]}
		<ValueTree
			value={entry.value}
			typeInfo={entry.typeInfo}
			path={entry.path}
			depth={depth + 1}
			{oncommit}
		/>
	{/if}
{/each}

<!-- Show more button for paginated arrays -->
{#if remaining > 0}
	<div class="ic-dt-vt__row" style="padding-left: {depth * INDENT}px">
		<span class="ic-dt-vt__spacer"></span>
		<button class="ic-dt-vt__show-more" onclick={handleShowMore}>
			show {remaining} more...
		</button>
	</div>
{/if}

<style>
	.ic-dt-vt__row {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 1px 6px 1px 0;
		min-height: 20px;
		font-family: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
		font-size: 11px;
		line-height: 18px;
		cursor: default;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.ic-dt-vt__row:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	/* --- Toggle --- */

	.ic-dt-vt__toggle {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 12px;
		flex-shrink: 0;
		font-size: 8px;
		color: var(--ic-muted-foreground);
		cursor: pointer;
		transition: transform 0.12s;
		user-select: none;
	}

	.ic-dt-vt__toggle--open {
		transform: rotate(90deg);
	}

	.ic-dt-vt__toggle:hover {
		color: var(--ic-foreground);
	}

	.ic-dt-vt__spacer {
		display: inline-block;
		width: 12px;
		flex-shrink: 0;
	}

	/* --- Labels --- */

	.ic-dt-vt__key {
		color: var(--ic-primary);
		font-weight: 500;
		flex-shrink: 0;
	}

	.ic-dt-vt__index {
		color: #d19a66;
		flex-shrink: 0;
	}

	.ic-dt-vt__colon {
		color: var(--ic-muted-foreground);
		flex-shrink: 0;
	}

	/* --- Values --- */

	.ic-dt-vt__summary {
		color: var(--ic-muted-foreground);
		font-style: italic;
	}

	.ic-dt-vt__leaf {
		color: var(--ic-foreground);
	}

	.ic-dt-vt__opaque {
		color: var(--ic-muted-foreground);
		font-style: italic;
		opacity: 0.6;
	}

	.ic-dt-vt__type {
		color: var(--ic-muted-foreground);
		font-size: 0.85em;
		opacity: 0.5;
		margin-left: auto;
		flex-shrink: 0;
	}

	/* --- Inline select --- */

	.ic-dt-vt__select {
		all: unset;
		padding: 1px 4px;
		background: var(--ic-background);
		border: 1px solid transparent;
		border-radius: 2px;
		font-family: inherit;
		font-size: inherit;
		color: var(--ic-foreground);
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
		cursor: pointer;
		appearance: auto;
	}

	.ic-dt-vt__select:focus {
		border-color: var(--ic-primary);
	}

	/* --- Inline input --- */

	.ic-dt-vt__input {
		all: unset;
		padding: 1px 4px;
		background: var(--ic-background);
		border: 1px solid transparent;
		border-radius: 2px;
		font-family: inherit;
		font-size: inherit;
		color: var(--ic-foreground);
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.06);
		min-width: 40px;
		max-width: 200px;
	}

	.ic-dt-vt__input:focus {
		border-color: var(--ic-primary);
		box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	/* --- Boolean toggle (compact) --- */

	.ic-dt-vt__bool {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		cursor: pointer;
	}

	.ic-dt-vt__bool input {
		position: absolute;
		opacity: 0;
		pointer-events: none;
	}

	.ic-dt-vt__bool-track {
		width: 22px;
		height: 11px;
		background: var(--ic-muted);
		border-radius: 2px;
		position: relative;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.15);
		transition: background 0.15s;
	}

	.ic-dt-vt__bool input:checked + .ic-dt-vt__bool-track {
		background: var(--ic-primary);
	}

	.ic-dt-vt__bool-thumb {
		position: absolute;
		top: 1.5px;
		left: 2px;
		width: 8px;
		height: 8px;
		background: var(--ic-foreground);
		border-radius: 1px;
		transition: left 0.15s;
		box-shadow: 0 1px 1px rgba(0, 0, 0, 0.2);
	}

	.ic-dt-vt__bool input:checked + .ic-dt-vt__bool-track .ic-dt-vt__bool-thumb {
		left: 12px;
		background: var(--ic-primary-foreground);
	}

	.ic-dt-vt__bool-label {
		color: var(--ic-muted-foreground);
		font-size: 0.9em;
	}

	/* --- Show more --- */

	.ic-dt-vt__show-more {
		all: unset;
		cursor: pointer;
		color: var(--ic-primary);
		font-family: inherit;
		font-size: inherit;
		padding: 1px 4px;
	}

	.ic-dt-vt__show-more:hover {
		text-decoration: underline;
	}
</style>
