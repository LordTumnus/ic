<!--
  StylesPanel.svelte — Unified stylesheet view with inline editing.

  Rules from all sources are MERGED by selector. Component and dynamic
  (.style()) properties appear together in one block, with dynamic
  properties visually distinguished by amber tint. Overridden component
  properties show strikethrough.

  Double-click a merged rule to edit. On commit, the system diffs against
  the component baseline and sends only the changes via MATLAB's .style() API.
-->
<script lang="ts">
	import type { RequestFn } from '$lib/types';
	import type {
		ComponentInfo,
		ChildComponentInfo,
		CssRule,
		CssRuleSource,
		CssProperty
	} from '../devtools-types';
	import { cleanSelector } from './dom/dom-utils';
	import ColorPicker from '$lib/components/form/colorPicker/ColorPicker.svelte';

	// --- Merged rule types (local to this component) ---

	interface MergedProperty {
		name: string;
		value: string;
		source: CssRuleSource;
		overridden: boolean;
	}

	interface MergedRule {
		/** Cleaned selector for display */
		displaySelector: string;
		/** Selector to use when sending edits to MATLAB */
		editSelector: string;
		/** Merged properties from all sources */
		properties: MergedProperty[];
		/** Whether any element matches this rule */
		matches: boolean;
		/** Whether this rule has any dynamic (.style()) properties */
		hasDynamic: boolean;
		/** Whether this rule has any component properties */
		hasComponent: boolean;
		/** The component-only properties (baseline for diff) */
		componentBaseline: Record<string, string>;
		/** The current dynamic-only properties */
		dynamicOverrides: Record<string, string>;
	}

	let {
		componentInfo,
		request
	}: {
		componentInfo: ComponentInfo;
		request?: RequestFn;
	} = $props();

	let rulesMap = $state<Record<string, MergedRule[]>>({});
	let scanning = $state(false);
	let rootExpanded = $state(true);
	let collapsedChildren = $state<Record<string, boolean>>({});

	// --- Edit state ---

	let editingKey = $state<string | null>(null);
	let editBuffer = $state('');
	let editPending = $state(false);

	// --- Filter state ---

	let filterText = $state('');
	let filterEl: HTMLInputElement | undefined;

	// --- Color picker state ---

	let optimisticColors = $state<Record<string, string>>({});
	let colorDebounceTimer: ReturnType<typeof setTimeout> | null = null;
	let pendingColorCommit: {
		componentId: string;
		rule: MergedRule;
		propName: string;
		color: string;
		key: string;
	} | null = null;

	// --- Add Rule state ---

	let addingFor = $state<string | null>(null);
	let newSelector = $state('> *');
	let newBody = $state('');

	// Scan on mount
	$effect(() => {
		if (componentInfo.componentId) {
			scan();
		}
	});

	// --- Helpers ---

	function shortType(type: string): string {
		return type.split('.').pop() ?? type;
	}

	function directChildIds(info: ComponentInfo): string[] {
		return (info.children ?? []).map((c) => c.componentId);
	}

	function matchesFilter(rule: MergedRule, query: string): boolean {
		if (!query) return true;
		const q = query.toLowerCase();
		if (rule.displaySelector.toLowerCase().includes(q)) return true;
		return rule.properties.some(
			(p) => p.name.toLowerCase().includes(q) || p.value.toLowerCase().includes(q)
		);
	}

	function filteredRules(componentId: string): MergedRule[] {
		const rules = rulesMap[componentId] ?? [];
		if (!filterText) return rules;
		return rules.filter((r) => matchesFilter(r, filterText));
	}

	function totalRules(componentId: string): number {
		return filteredRules(componentId).length;
	}

	function findInfo(
		id: string,
		node: ComponentInfo = componentInfo
	): ComponentInfo | ChildComponentInfo | null {
		if (node.componentId === id) return node;
		for (const child of node.children ?? []) {
			const found = findInfo(id, child);
			if (found) return found;
		}
		return null;
	}

	// --- CSS parsing helpers ---

	function parseCssProperties(cssText: string): CssProperty[] {
		return cssText
			.split(';')
			.map((s) => s.trim())
			.filter(Boolean)
			.map((decl) => {
				const colonIdx = decl.indexOf(':');
				if (colonIdx === -1) return null;
				return {
					name: decl.slice(0, colonIdx).trim(),
					value: decl.slice(colonIdx + 1).trim(),
					overridden: false
				};
			})
			.filter(Boolean) as CssProperty[];
	}

	function parseEditorText(text: string): Record<string, string> {
		const result: Record<string, string> = {};
		for (const line of text.split('\n')) {
			const trimmed = line.trim().replace(/;$/, '').trim();
			if (!trimmed) continue;
			const colonIdx = trimmed.indexOf(':');
			if (colonIdx === -1) continue;
			const name = trimmed.slice(0, colonIdx).trim();
			const value = trimmed.slice(colonIdx + 1).trim();
			if (name) result[name] = value;
		}
		return result;
	}

	function kebabToCamel(str: string): string {
		if (str.startsWith('--')) return str;
		return str.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
	}

	// --- Color detection & conversion ---

	let colorCtx: CanvasRenderingContext2D | null = null;

	function getColorCtx(): CanvasRenderingContext2D {
		if (!colorCtx) colorCtx = document.createElement('canvas').getContext('2d')!;
		return colorCtx;
	}

	function isColorValue(value: string): boolean {
		const v = value.trim();
		if (!v) return false;
		if (/^#[0-9a-f]{3,8}$/i.test(v)) return true;
		if (/^(rgb|hsl)a?\([^)]+\)\s*$/i.test(v)) return true;
		if (/^(inherit|initial|unset|revert|none|auto|transparent|currentcolor|var\(|calc\()/i.test(v)) return false;
		// Named colors: validate via canvas
		if (/^[a-z]+$/i.test(v)) {
			const ctx = getColorCtx();
			ctx.fillStyle = '#000001';
			ctx.fillStyle = v;
			return ctx.fillStyle !== '#000001';
		}
		return false;
	}

	/** Resolve any CSS color to a format parseColor understands (hex/rgb/hsl). */
	function resolveColor(value: string): string {
		const v = value.trim();
		if (v.startsWith('#') || /^(rgb|hsl)a?\(/i.test(v)) return v;
		const ctx = getColorCtx();
		ctx.fillStyle = '#000000';
		ctx.fillStyle = v;
		return ctx.fillStyle;
	}

	/**
	 * Compute the merge key for a rule — the selector portion that identifies
	 * which rules should be grouped together.
	 * For dynamic rules: strip the "#componentId " scoping prefix.
	 * For component rules: use the displaySelector (svelte hashes stripped).
	 */
	function mergeKeyFor(rule: CssRule, componentId: string): string {
		if (rule.source === 'dynamic') {
			const escapedId = CSS.escape(componentId);
			const prefix = `#${escapedId} `;
			if (rule.selector.startsWith(prefix)) {
				return rule.selector.slice(prefix.length);
			}
			return cleanSelector(rule.selector);
		}
		return rule.displaySelector;
	}

	// --- Scan logic ---

	function scan() {
		scanning = true;
		requestAnimationFrame(() => {
			const map: Record<string, MergedRule[]> = {};
			scanComponent(componentInfo, map);
			rulesMap = map;
			scanning = false;
		});
	}

	function scanComponent(info: ComponentInfo, map: Record<string, MergedRule[]>) {
		const childIds = directChildIds(info);
		const raw = collectRawRules(info.componentId, childIds);
		map[info.componentId] = mergeRules(raw, info.componentId);
		for (const child of info.children ?? []) {
			scanComponent(child, map);
		}
	}

	// --- CSS collection (raw) ---

	function collectRawRules(componentId: string, childIds: string[]): CssRule[] {
		const wrapper = document.getElementById(componentId);
		if (!wrapper) return [];

		const childWrappers = childIds
			.map((id) => document.getElementById(id))
			.filter(Boolean) as Element[];

		const allElements = [wrapper, ...Array.from(wrapper.querySelectorAll('*'))];

		const elements =
			childWrappers.length > 0
				? allElements.filter(
						(el) => !childWrappers.some((cw) => cw !== el && cw.contains(el))
					)
				: allElements;

		return collectRulesForElements(elements, componentId);
	}

	function collectRulesForElements(elements: Element[], componentId: string): CssRule[] {
		const rules: CssRule[] = [];
		const seen = new Set<string>();

		const allSheets: CSSStyleSheet[] = [
			...Array.from(document.styleSheets),
			...(document.adoptedStyleSheets ?? [])
		];

		// Build the scoping prefix for dynamic rules belonging to this component
		const scopePrefix = `#${CSS.escape(componentId)} `;

		// Phase 1: Discover .svelte-XXXX hashes belonging to these elements
		const componentHashes = new Set<string>();

		for (const sheet of allSheets) {
			try {
				for (const rule of Array.from(sheet.cssRules)) {
					if (!(rule instanceof CSSStyleRule)) continue;
					const hashMatches = rule.selectorText.match(/\.svelte-[a-z0-9]+/g);
					if (!hashMatches) continue;
					const matchesElement = elements.some((el) => {
						try { return el.matches(rule.selectorText); } catch { return false; }
					});
					if (matchesElement) {
						for (const h of hashMatches) componentHashes.add(h);
					}
				}
			} catch { /* CORS */ }
		}

		// Phase 2: Collect rules with source classification
		for (const sheet of allSheets) {
			const isAdopted = document.adoptedStyleSheets?.includes(sheet) ?? false;
			try {
				for (const rule of Array.from(sheet.cssRules)) {
					if (!(rule instanceof CSSStyleRule)) continue;
					if (rule.selectorText.startsWith('.ic-dt')) continue;

					const key = `${rule.selectorText}|${rule.style.cssText}`;
					if (seen.has(key)) continue;

					const hashMatches = rule.selectorText.match(/\.svelte-[a-z0-9]+/g);
					const isSvelteScoped =
						hashMatches != null && hashMatches.some((h) => componentHashes.has(h));

					const matchesElement = elements.some((el) => {
						try { return el.matches(rule.selectorText); } catch { return false; }
					});

					if (isSvelteScoped) {
						seen.add(key);
						rules.push({
							selector: rule.selectorText,
							displaySelector: cleanSelector(rule.selectorText),
							cssText: rule.style.cssText,
							matches: matchesElement,
							source: 'component',
							properties: parseCssProperties(rule.style.cssText)
						});
					} else if (matchesElement) {
						seen.add(key);
						const source = classifySource(rule, isAdopted);
						rules.push({
							selector: rule.selectorText,
							displaySelector: cleanSelector(rule.selectorText),
							cssText: rule.style.cssText,
							matches: true,
							source,
							properties: parseCssProperties(rule.style.cssText)
						});
					} else if (isAdopted && rule.selectorText.startsWith(scopePrefix)) {
						// Dynamic rule scoped to this component — always collect even
						// when no element in the filtered set matches (the selector may
						// target elements inside child components).
						seen.add(key);
						const matches = !!document.querySelector(rule.selectorText);
						rules.push({
							selector: rule.selectorText,
							displaySelector: cleanSelector(rule.selectorText),
							cssText: rule.style.cssText,
							matches,
							source: 'dynamic',
							properties: parseCssProperties(rule.style.cssText)
						});
					}
				}
			} catch { /* CORS or access error — skip sheet */ }
		}

		return rules;
	}

	function classifySource(rule: CSSStyleRule, isAdopted: boolean): CssRuleSource {
		if (rule.selectorText.includes('[data-ic-type=')) return 'global';
		if (isAdopted) return 'dynamic';
		return 'component';
	}

	// --- Merge rules by selector ---

	function mergeRules(rawRules: CssRule[], componentId: string): MergedRule[] {
		// Group raw rules by merge key
		const groups = new Map<string, { comp: CssRule[]; dyn: CssRule[]; glob: CssRule[] }>();

		for (const rule of rawRules) {
			const key = mergeKeyFor(rule, componentId);
			if (!groups.has(key)) groups.set(key, { comp: [], dyn: [], glob: [] });
			const g = groups.get(key)!;
			if (rule.source === 'dynamic') g.dyn.push(rule);
			else if (rule.source === 'global') g.glob.push(rule);
			else g.comp.push(rule);
		}

		const merged: MergedRule[] = [];

		for (const [key, group] of groups) {
			// Build component baseline
			const componentBaseline: Record<string, string> = {};
			for (const rule of group.comp) {
				for (const p of rule.properties) {
					componentBaseline[p.name] = p.value;
				}
			}

			// Build dynamic overrides
			const dynamicOverrides: Record<string, string> = {};
			for (const rule of group.dyn) {
				for (const p of rule.properties) {
					dynamicOverrides[p.name] = p.value;
				}
			}

			// Build global baseline
			const globalBaseline: Record<string, string> = {};
			for (const rule of group.glob) {
				for (const p of rule.properties) {
					globalBaseline[p.name] = p.value;
				}
			}

			const hasComponent = group.comp.length > 0 || group.glob.length > 0;
			const hasDynamic = group.dyn.length > 0;

			// Determine the base source for non-dynamic props
			const baseSource: CssRuleSource = group.comp.length > 0 ? 'component' : 'global';
			const baseProps = group.comp.length > 0 ? componentBaseline : globalBaseline;

			// Interleave: base properties first, with dynamic overrides inline
			const properties: MergedProperty[] = [];
			const addedDynamic = new Set<string>();

			for (const [name, value] of Object.entries(baseProps)) {
				if (name in dynamicOverrides) {
					// Component property overridden by dynamic
					properties.push({ name, value, source: baseSource, overridden: true });
					properties.push({ name, value: dynamicOverrides[name], source: 'dynamic', overridden: false });
					addedDynamic.add(name);
				} else {
					properties.push({ name, value, source: baseSource, overridden: false });
				}
			}

			// Add dynamic-only properties (not overriding anything)
			for (const [name, value] of Object.entries(dynamicOverrides)) {
				if (!addedDynamic.has(name)) {
					properties.push({ name, value, source: 'dynamic', overridden: false });
				}
			}

			// Determine matches from any source
			const matches = [...group.comp, ...group.dyn, ...group.glob].some((r) => r.matches);

			// Display selector: prefer the cleaned component selector, else the merge key
			const displaySelector = group.comp[0]?.displaySelector
				?? group.glob[0]?.displaySelector
				?? key;

			// Edit selector: what we send to MATLAB .style()
			// It's the merge key (without #componentId scoping, without svelte hashes)
			const editSelector = key;

			merged.push({
				displaySelector,
				editSelector,
				properties,
				matches,
				hasDynamic,
				hasComponent,
				componentBaseline: { ...componentBaseline, ...globalBaseline },
				dynamicOverrides
			});
		}

		// Dynamic-only rules (user-added) appear first, like element.style in browser DevTools
		merged.sort((a, b) => {
			const aDynOnly = a.hasDynamic && !a.hasComponent ? 1 : 0;
			const bDynOnly = b.hasDynamic && !b.hasComponent ? 1 : 0;
			return bDynOnly - aDynOnly;
		});

		return merged;
	}

	// --- Edit logic ---

	function editKey(componentId: string, idx: number): string {
		return `${componentId}:${idx}`;
	}

	function handleDoubleClick(componentId: string, rule: MergedRule, ruleIdx: number) {
		const info = findInfo(componentId);
		if (!info?.isStylable || !request) return;

		editingKey = editKey(componentId, ruleIdx);

		// Show the effective view: for each property, show its current effective value
		const effective: Record<string, string> = {};
		for (const p of rule.properties) {
			if (!p.overridden) {
				effective[p.name] = p.value;
			}
		}
		editBuffer = Object.entries(effective)
			.map(([name, value]) => `${name}: ${value};`)
			.join('\n');
	}

	function handleEditorKeydown(e: KeyboardEvent, componentId: string, rule: MergedRule) {
		if (e.key === 'Escape') {
			e.preventDefault();
			editingKey = null;
			return;
		}
		if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
			e.preventDefault();
			commitEdit(componentId, rule);
		}
	}

	function handleEditorBlur(componentId: string, rule: MergedRule) {
		if (editingKey === null) return;
		commitEdit(componentId, rule);
	}

	async function commitEdit(componentId: string, rule: MergedRule) {
		if (!request || editPending) return;

		const newProps = parseEditorText(editBuffer);
		const baseline = rule.componentBaseline;
		const prevDynamic = rule.dynamicOverrides;

		// Compute delta in kebab-case (original CSS property names)
		const delta: Record<string, string> = {};

		for (const [name, value] of Object.entries(newProps)) {
			if (baseline[name] !== value) {
				delta[name] = value;
			} else if (name in prevDynamic) {
				delta[name] = ''; // revert to baseline → clear dynamic override
			}
		}

		for (const name of Object.keys(prevDynamic)) {
			if (!(name in newProps)) {
				delta[name] = ''; // removed from editor → clear
			}
		}

		if (Object.keys(delta).length === 0) {
			editingKey = null;
			return;
		}

		// Split into regular properties (camelCase for MATLAB) and CSS variables
		const properties: Record<string, string> = {};
		const cssVariables: Array<{ name: string; value: string }> = [];

		for (const [name, value] of Object.entries(delta)) {
			if (name.startsWith('--')) {
				cssVariables.push({ name, value });
			} else {
				properties[kebabToCamel(name)] = value;
			}
		}

		editPending = true;
		try {
			const payload: Record<string, unknown> = {
				componentId,
				selector: rule.editSelector,
				properties
			};
			if (cssVariables.length > 0) payload.cssVariables = cssVariables;
			await request('setStyle', payload);
			await new Promise((r) => setTimeout(r, 60));
			scan();
		} finally {
			editPending = false;
			editingKey = null;
		}
	}

	// --- Add Rule logic ---

	async function commitNewRule(componentId: string) {
		if (!request || editPending) return;

		const props = parseEditorText(newBody);
		if (Object.keys(props).length === 0 || !newSelector.trim()) {
			addingFor = null;
			return;
		}

		// Split into regular properties (camelCase for MATLAB) and CSS variables
		const properties: Record<string, string> = {};
		const cssVariables: Array<{ name: string; value: string }> = [];

		for (const [name, value] of Object.entries(props)) {
			if (name.startsWith('--')) {
				cssVariables.push({ name, value });
			} else {
				properties[kebabToCamel(name)] = value;
			}
		}

		editPending = true;
		try {
			const payload: Record<string, unknown> = {
				componentId,
				selector: newSelector.trim(),
				properties
			};
			if (cssVariables.length > 0) payload.cssVariables = cssVariables;
			await request('setStyle', payload);
			await new Promise((r) => setTimeout(r, 60));
			scan();
		} finally {
			editPending = false;
			addingFor = null;
			newSelector = '> *';
			newBody = '';
		}
	}

	function handleNewRuleKeydown(e: KeyboardEvent, componentId: string) {
		if (e.key === 'Escape') {
			e.preventDefault();
			addingFor = null;
			return;
		}
		if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
			e.preventDefault();
			commitNewRule(componentId);
		}
	}

	function scheduleColorCommit(
		componentId: string,
		rule: MergedRule,
		propName: string,
		color: string,
		key: string
	) {
		pendingColorCommit = { componentId, rule, propName, color, key };
		if (colorDebounceTimer) clearTimeout(colorDebounceTimer);
		colorDebounceTimer = setTimeout(flushColorCommit, 500);
	}

	function flushColorCommit() {
		if (colorDebounceTimer) {
			clearTimeout(colorDebounceTimer);
			colorDebounceTimer = null;
		}
		if (!pendingColorCommit) return;
		const { componentId, rule, propName, color, key } = pendingColorCommit;
		pendingColorCommit = null;
		commitColorChange(componentId, rule, propName, color).then(() => {
			setTimeout(() => {
				scan();
				// Clear optimistic after scan's rAF commits the new rulesMap
				requestAnimationFrame(() => {
					delete optimisticColors[key];
				});
			}, 200);
		});
	}

	async function commitColorChange(
		componentId: string,
		rule: MergedRule,
		propName: string,
		newColor: string
	) {
		if (!request) return;

		const isCssVar = propName.startsWith('--');
		const properties: Record<string, string> = {};
		const cssVariables: Array<{ name: string; value: string }> = [];

		if (isCssVar) {
			cssVariables.push({ name: propName, value: newColor });
		} else {
			properties[kebabToCamel(propName)] = newColor;
		}

		const payload: Record<string, unknown> = {
			componentId,
			selector: rule.editSelector,
			properties
		};
		if (cssVariables.length > 0) payload.cssVariables = cssVariables;
		await request('setStyle', payload);
	}

	function handlePanelKeydown(e: KeyboardEvent) {
		if (e.key === 'f' && (e.ctrlKey || e.metaKey)) {
			e.preventDefault();
			filterEl?.focus();
			filterEl?.select();
		}
	}
</script>

<svelte:window onkeydown={handlePanelKeydown} />

<div class="ic-dt-css">
	<!-- Toolbar -->
	<div class="ic-dt-css__toolbar">
		<input
			class="ic-dt-css__filter"
			type="text"
			bind:this={filterEl}
			bind:value={filterText}
			placeholder="Filter by selector or property..."
			onkeydown={(e) => {
				if (e.key === 'Escape') {
					filterText = '';
					filterEl?.blur();
				}
			}}
		/>
		<button class="ic-dt-css__btn" onclick={scan} disabled={scanning || editPending}>
			{scanning ? 'Scanning...' : 'Refresh'}
		</button>
	</div>

	<!-- Rules for a single component -->
	{#snippet rulesContent(componentId: string)}
		{@const rules = filteredRules(componentId)}
		{@const info = findInfo(componentId)}
		{@const stylable = info?.isStylable ?? false}

		<!-- Add Rule form -->
		{#if addingFor === componentId}
			<div class="ic-dt-css__add-form">
				<div class="ic-dt-css__add-header">New .style() rule</div>
				<input
					class="ic-dt-css__add-selector"
					type="text"
					bind:value={newSelector}
					placeholder=""
					onkeydown={(e) => handleNewRuleKeydown(e, componentId)}
				/>
				<!-- svelte-ignore a11y_autofocus -->
				<textarea
					class="ic-dt-css__editor"
					bind:value={newBody}
					placeholder="property: value;"
					rows="3"
					autofocus
					onkeydown={(e) => handleNewRuleKeydown(e, componentId)}
				></textarea>
				<div class="ic-dt-css__add-actions">
					<button
						class="ic-dt-css__btn ic-dt-css__btn--primary"
						onclick={() => commitNewRule(componentId)}
						disabled={editPending}
					>Apply</button>
					<button class="ic-dt-css__btn" onclick={() => (addingFor = null)}>Cancel</button>
					<span class="ic-dt-css__hint">Ctrl+Enter to apply</span>
				</div>
			</div>
		{/if}

		{#if rules.length > 0}
			<div class="ic-dt-css__rules">
				{#each rules as rule, idx (rule.displaySelector + idx)}
					{@const ek = editKey(componentId, idx)}
					{@const isEditing = editingKey === ek}
					<!-- svelte-ignore a11y_no_static_element_interactions -->
					<div
						class="ic-dt-css__rule"
						class:ic-dt-css__rule--has-dynamic={rule.hasDynamic}
						class:ic-dt-css__rule--dynamic-only={rule.hasDynamic && !rule.hasComponent}
						class:ic-dt-css__rule--muted={!rule.matches}
						class:ic-dt-css__rule--editable={stylable && !!request}
						ondblclick={() => handleDoubleClick(componentId, rule, idx)}
					>
						<div class="ic-dt-css__selector">
							{rule.displaySelector} &#123;
							{#if rule.hasDynamic}
								<span class="ic-dt-css__source">.style()</span>
							{/if}
						</div>

						{#if isEditing}
							<!-- svelte-ignore a11y_autofocus -->
							<textarea
								class="ic-dt-css__editor"
								bind:value={editBuffer}
								rows={Math.max(3, editBuffer.split('\n').length + 1)}
								autofocus
								onkeydown={(e) => handleEditorKeydown(e, componentId, rule)}
								onblur={() => handleEditorBlur(componentId, rule)}
							></textarea>
							<div class="ic-dt-css__edit-hint">
								Ctrl+Enter to apply &middot; Escape to cancel
							</div>
						{:else}
							<div class="ic-dt-css__body">
								{#each rule.properties as prop (prop.name + prop.source)}
									{@const colorKey = `${componentId}:${rule.editSelector}:${prop.name}:${prop.source}`}
									{@const displayValue = optimisticColors[colorKey] ?? prop.value}
									<div
										class="ic-dt-css__prop"
										class:ic-dt-css__prop--overridden={prop.overridden}
										class:ic-dt-css__prop--dynamic={prop.source === 'dynamic'}
									>
										<span class="ic-dt-css__prop-name">{prop.name}</span>:{' '}{#if isColorValue(displayValue)}{#if stylable && !!request && !prop.overridden}<span class="ic-dt-css__color-picker-wrap"><ColorPicker
											value={resolveColor(displayValue)}
											size="sm"
											showAlpha
											popupPosition="best"
											valueChanging={(data) => {
												const d = data as { value: string };
												optimisticColors[colorKey] = d.value;
												scheduleColorCommit(componentId, rule, prop.name, d.value, colorKey);
											}}
											closed={flushColorCommit}
										/></span>{:else}<span class="ic-dt-css__swatch" style="background-color: {displayValue}"></span>{/if}{' '}{/if}<span class="ic-dt-css__prop-value">{displayValue}</span>;
									</div>
								{/each}
							</div>
						{/if}

						{#if !isEditing}
							<div class="ic-dt-css__brace">&#125;</div>
						{/if}
					</div>
				{/each}
			</div>
		{:else if !addingFor}
			<div class="ic-dt-css__empty">No matching CSS rules</div>
		{/if}
	{/snippet}

	<!-- Recursive child section -->
	{#snippet childSection(info: ChildComponentInfo)}
		{@const cid = info.componentId}
		{@const count = totalRules(cid)}
		<div class="ic-dt-css__child">
			<div class="ic-dt-css__child-row">
				<button
					class="ic-dt-css__child-header"
					onclick={() => (collapsedChildren[cid] = !collapsedChildren[cid])}
				>
					<span
						class="ic-dt-css__tree-chevron"
						class:ic-dt-css__tree-chevron--open={!collapsedChildren[cid]}
					>&#9654;</span>
					<span class="ic-dt-css__child-type">{shortType(info.componentType)}</span>
					<span class="ic-dt-css__child-target">({info.target})</span>
					{#if !info.isStylable}
						<span class="ic-dt-css__readonly-badge">read-only</span>
					{/if}
					{#if count > 0}
						<span class="ic-dt-css__badge">{count}</span>
					{/if}
				</button>
				{#if info.isStylable && request}
					<button
						class="ic-dt-css__add-btn"
						onclick={() => {
							addingFor = cid;
							newSelector = '> *';
							newBody = '';
							if (collapsedChildren[cid]) collapsedChildren[cid] = false;
						}}
						disabled={scanning || editPending}
						title="Add .style() rule to {shortType(info.componentType)}"
					>+</button>
				{/if}
			</div>

			{#if !collapsedChildren[cid]}
				<div class="ic-dt-css__child-body">
					{@render rulesContent(cid)}
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
	<div class="ic-dt-css__child ic-dt-css__child--root">
		<div class="ic-dt-css__child-row">
			<button
				class="ic-dt-css__child-header"
				onclick={() => (rootExpanded = !rootExpanded)}
			>
				<span
					class="ic-dt-css__tree-chevron"
					class:ic-dt-css__tree-chevron--open={rootExpanded}
				>&#9654;</span>
				<span class="ic-dt-css__child-type">{componentInfo.componentType}</span>
				<span class="ic-dt-css__child-target">{componentInfo.componentId}</span>
				{#if !componentInfo.isStylable}
					<span class="ic-dt-css__readonly-badge">read-only</span>
				{/if}
				{#if totalRules(componentInfo.componentId) > 0}
					<span class="ic-dt-css__badge">{totalRules(componentInfo.componentId)}</span>
				{/if}
			</button>
			{#if componentInfo.isStylable && request}
				<button
					class="ic-dt-css__add-btn"
					onclick={() => {
						addingFor = componentInfo.componentId;
						newSelector = '> *';
						newBody = '';
						rootExpanded = true;
					}}
					disabled={scanning || editPending}
					title="Add .style() rule"
				>+</button>
			{/if}
		</div>

		{#if rootExpanded}
			<div class="ic-dt-css__child-body">
				{@render rulesContent(componentInfo.componentId)}
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
	.ic-dt-css {
		padding: 0;
		font-family: var(--ic-font-family);
	}

	/* --- Toolbar --- */

	.ic-dt-css__toolbar {
		padding: 6px 10px;
		border-bottom: 1px solid var(--ic-border);
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.ic-dt-css__filter {
		all: unset;
		flex: 1;
		min-width: 0;
		padding: 3px 8px;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		color: var(--ic-foreground);
		background: var(--ic-background);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
		box-sizing: border-box;
	}

	.ic-dt-css__filter::placeholder {
		color: var(--ic-muted-foreground);
		opacity: 0.6;
	}

	.ic-dt-css__filter:focus {
		border-color: var(--ic-primary);
	}

	.ic-dt-css__btn {
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
		white-space: nowrap;
	}

	.ic-dt-css__btn:hover:not(:disabled) {
		color: var(--ic-foreground);
		border-color: var(--ic-muted-foreground);
	}

	.ic-dt-css__btn:disabled {
		opacity: 0.5;
		cursor: default;
	}

	.ic-dt-css__btn--primary {
		background: var(--ic-primary);
		color: var(--ic-primary-foreground);
		border-color: var(--ic-primary);
	}

	.ic-dt-css__btn--primary:hover:not(:disabled) {
		opacity: 0.9;
		color: var(--ic-primary-foreground);
	}

	/* --- Empty state --- */

	.ic-dt-css__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}

	/* --- Tree structure --- */

	.ic-dt-css__child {
		border-top: 1px solid var(--ic-border);
		margin-top: 2px;
	}

	.ic-dt-css__child--root {
		border-top: none;
		margin-top: 0;
	}

	.ic-dt-css__child-row {
		display: flex;
		align-items: center;
		background: transparent;
	}

	.ic-dt-css__child-header {
		all: unset;
		display: flex;
		align-items: center;
		gap: 6px;
		flex: 1;
		min-width: 0;
		padding: 3px 8px;
		cursor: pointer;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		box-sizing: border-box;
	}

	.ic-dt-css__child-row:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	.ic-dt-css__child--root > .ic-dt-css__child-row {
		background: var(--ic-secondary);
	}

	.ic-dt-css__child--root > .ic-dt-css__child-row:hover {
		background: rgba(128, 128, 128, 0.1);
	}

	.ic-dt-css__add-btn {
		all: unset;
		cursor: pointer;
		padding: 2px 8px;
		margin-right: 6px;
		font-family: var(--ic-font-family);
		font-size: var(--ic-font-size);
		font-weight: 600;
		color: var(--ic-muted-foreground);
		border: 1px solid transparent;
		border-radius: 2px;
	}

	.ic-dt-css__add-btn:hover {
		color: var(--ic-foreground);
		border-color: var(--ic-border);
		background: rgba(128, 128, 128, 0.08);
	}

	.ic-dt-css__add-btn:disabled {
		opacity: 0.4;
		cursor: default;
	}

	.ic-dt-css__child-type {
		font-weight: 600;
		color: var(--ic-foreground);
	}

	.ic-dt-css__child-target {
		color: var(--ic-muted-foreground);
		font-size: 0.85em;
	}

	.ic-dt-css__child-body {
		border-left: 2px solid var(--ic-primary);
		margin-left: 6px;
		background: rgba(128, 128, 128, 0.03);
	}

	.ic-dt-css__tree-chevron {
		font-size: 0.7em;
		transition: transform 0.15s;
		display: inline-block;
	}

	.ic-dt-css__tree-chevron--open {
		transform: rotate(90deg);
	}

	/* --- Badges --- */

	.ic-dt-css__badge {
		margin-left: auto;
		min-width: 20px;
		text-align: center;
		padding: 0 5px;
		font-size: 0.8em;
		font-variant-numeric: tabular-nums;
		color: var(--ic-muted-foreground);
		background: rgba(128, 128, 128, 0.12);
		border-radius: 2px;
	}

	.ic-dt-css__readonly-badge {
		font-size: 0.75em;
		color: var(--ic-muted-foreground);
		font-style: italic;
		opacity: 0.7;
	}

	/* --- Rules --- */

	.ic-dt-css__rules {
		padding: 4px 0;
	}

	.ic-dt-css__rule {
		padding: 2px 10px 4px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.06);
		border-left: 2px solid transparent;
	}

	.ic-dt-css__rule:last-child {
		border-bottom: none;
	}

	.ic-dt-css__rule--editable {
		cursor: text;
	}

	.ic-dt-css__rule--muted {
		opacity: 0.4;
	}

	.ic-dt-css__rule--muted .ic-dt-css__selector {
		color: var(--ic-muted-foreground);
	}

	/* Rules that are purely dynamic (no component counterpart) */
	.ic-dt-css__rule--dynamic-only {
		background: rgba(217, 119, 6, 0.06);
		border-left-color: var(--ic-warning);
	}

	/* Rules that have some dynamic overrides mixed in */
	.ic-dt-css__rule--has-dynamic {
		border-left-color: var(--ic-warning);
	}

	/* --- Selector line --- */

	.ic-dt-css__selector {
		color: var(--ic-primary);
		font-weight: 500;
	}

	.ic-dt-css__source {
		font-style: italic;
		color: var(--ic-warning);
		font-size: 0.8em;
		font-weight: 400;
		margin-left: 6px;
	}

	/* --- Property lines --- */

	.ic-dt-css__body {
		padding: 0 0 0 8px;
	}

	.ic-dt-css__prop {
		font-size: var(--ic-font-size);
		line-height: 1.5;
		white-space: pre-wrap;
		word-break: break-all;
		padding: 0 4px;
		margin: 0 -4px;
		border-radius: 1px;
	}

	/* Dynamic-sourced property: amber inline tint */
	.ic-dt-css__prop--dynamic {
		background: rgba(217, 119, 6, 0.1);
	}

	/* Overridden component property: strikethrough + dimmed */
	.ic-dt-css__prop--overridden {
		text-decoration: line-through;
		opacity: 0.45;
	}

	.ic-dt-css__prop-name {
		color: var(--ic-primary);
	}

	.ic-dt-css__swatch {
		display: inline-block;
		width: 11px;
		height: 11px;
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		vertical-align: middle;
		box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.1);
	}

	.ic-dt-css__color-picker-wrap {
		display: inline-flex;
		vertical-align: middle;
	}

	/* Shrink the ColorPicker swatch to match devtools scale */
	.ic-dt-css__color-picker-wrap :global(.ic-color-picker__swatch) {
		width: 12px;
		height: 12px;
	}

	.ic-dt-css__prop-value {
		color: var(--ic-foreground);
	}

	.ic-dt-css__brace {
		color: var(--ic-muted-foreground);
	}

	/* --- Editor --- */

	.ic-dt-css__editor {
		display: block;
		width: 100%;
		font-family: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
		font-size: var(--ic-font-size);
		background: var(--ic-background);
		color: var(--ic-foreground);
		border: 1px solid var(--ic-primary);
		border-radius: 2px;
		box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
		padding: 4px 8px;
		resize: vertical;
		line-height: 1.5;
		box-sizing: border-box;
		margin: 4px 0 2px 8px;
	}

	.ic-dt-css__editor:focus {
		outline: none;
		border-color: var(--ic-primary);
		box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12), 0 0 0 1px var(--ic-primary);
	}

	.ic-dt-css__edit-hint {
		font-size: 0.75em;
		color: var(--ic-muted-foreground);
		padding: 0 0 2px 8px;
		font-style: italic;
	}

	/* --- Add Rule form --- */

	.ic-dt-css__add-form {
		padding: 8px 10px;
		border-bottom: 1px solid var(--ic-border);
		background: rgba(217, 119, 6, 0.04);
	}

	.ic-dt-css__add-header {
		font-size: 0.85em;
		font-weight: 600;
		color: var(--ic-warning);
		margin-bottom: 6px;
	}

	.ic-dt-css__add-selector {
		display: block;
		width: 100%;
		font-family: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
		font-size: var(--ic-font-size);
		background: var(--ic-background);
		color: var(--ic-primary);
		border: 1px solid var(--ic-border);
		border-radius: 2px;
		padding: 3px 8px;
		margin-bottom: 4px;
		box-sizing: border-box;
	}

	.ic-dt-css__add-selector:focus {
		outline: none;
		border-color: var(--ic-primary);
	}

	.ic-dt-css__add-actions {
		display: flex;
		align-items: center;
		gap: 6px;
		margin-top: 6px;
	}

	.ic-dt-css__hint {
		font-size: 0.75em;
		color: var(--ic-muted-foreground);
		font-style: italic;
		margin-left: auto;
	}
</style>
