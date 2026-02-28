<!--
  StylesPanel.svelte — Full stylesheet view for inspected component tree.

  Scans document.styleSheets to collect all CSS rules matching each
  component's DOM subtree, grouped by source (component/dynamic/global).
  Uses the same collapsible tree layout as other panels — each component
  node expands to show its CSS rules and nested children.
  Component-scoped rules include ALL rules (even non-matching) so the user
  can see inactive variants/states. Svelte hash selectors are cleaned.
-->
<script lang="ts">
	import type { ComponentInfo, ChildComponentInfo, CssRule, GroupedRules } from '../devtools-types';
	import { cleanSelector } from './dom/dom-utils';

	let {
		componentInfo
	}: {
		componentInfo: ComponentInfo;
	} = $props();

	let rulesMap = $state<Record<string, GroupedRules>>({});
	let scanning = $state(false);
	let rootExpanded = $state(true);
	let expandedChildren = $state<Record<string, boolean>>({});
	let collapsedSections = $state<Record<string, boolean>>({});

	// Scan on mount
	$effect(() => {
		if (componentInfo.componentId) {
			scan();
		}
	});

	// --- Helpers ---

	/** Short type label: "ic.FlexContainer" → "FlexContainer" */
	function shortType(type: string): string {
		return type.split('.').pop() ?? type;
	}

	/** Get direct child IDs of a component info node. */
	function directChildIds(info: ComponentInfo): string[] {
		return (info.children ?? []).map((c) => c.componentId);
	}

	/** Collapse key for a rule section within a specific component. */
	function sectionCollapseKey(componentId: string, sectionKey: string): string {
		return `${componentId}:${sectionKey}`;
	}

	/** Total rule count for a GroupedRules. */
	function totalRules(rules: GroupedRules | undefined): number {
		if (!rules) return 0;
		return rules.component.length + rules.dynamic.length + rules.global.length;
	}

	// --- Scan logic ---

	function scan() {
		scanning = true;
		requestAnimationFrame(() => {
			const map: Record<string, GroupedRules> = {};
			scanComponent(componentInfo, map);
			rulesMap = map;
			scanning = false;
		});
	}

	/** Recursively scan a component and all its children. */
	function scanComponent(info: ComponentInfo, map: Record<string, GroupedRules>) {
		const childIds = directChildIds(info);
		map[info.componentId] = collectRulesExcludingChildren(info.componentId, childIds);
		for (const child of info.children ?? []) {
			scanComponent(child, map);
		}
	}

	// --- CSS collection ---

	/**
	 * Collect rules for a component, excluding elements inside child wrappers.
	 * If childIds is empty, this scans the full subtree (same as before).
	 */
	function collectRulesExcludingChildren(
		componentId: string,
		childIds: string[]
	): GroupedRules {
		const wrapper = document.getElementById(componentId);
		if (!wrapper) return { component: [], dynamic: [], global: [] };

		const childWrappers = childIds
			.map((id) => document.getElementById(id))
			.filter(Boolean) as Element[];

		const allElements = [wrapper, ...Array.from(wrapper.querySelectorAll('*'))];

		// Keep only elements that are NOT inside any child wrapper
		const elements =
			childWrappers.length > 0
				? allElements.filter(
						(el) => !childWrappers.some((cw) => cw !== el && cw.contains(el))
					)
				: allElements;

		return collectRulesForElements(elements);
	}

	/** Core rule collection: hash discovery + rule grouping for a given set of elements. */
	function collectRulesForElements(elements: Element[]): GroupedRules {
		const groups: GroupedRules = { component: [], dynamic: [], global: [] };
		const seen = new Set<string>();

		const allSheets: CSSStyleSheet[] = [
			...Array.from(document.styleSheets),
			...(document.adoptedStyleSheets ?? [])
		];

		// Phase 1: Discover which .svelte-XXXX hashes belong to these elements
		const componentHashes = new Set<string>();

		for (const sheet of allSheets) {
			try {
				for (const rule of Array.from(sheet.cssRules)) {
					if (!(rule instanceof CSSStyleRule)) continue;
					const hashMatches = rule.selectorText.match(/\.svelte-[a-z0-9]+/g);
					if (!hashMatches) continue;

					const matchesElement = elements.some((el) => {
						try {
							return el.matches(rule.selectorText);
						} catch {
							return false;
						}
					});
					if (matchesElement) {
						for (const h of hashMatches) componentHashes.add(h);
					}
				}
			} catch {
				/* CORS */
			}
		}

		// Phase 2: Collect rules
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
						try {
							return el.matches(rule.selectorText);
						} catch {
							return false;
						}
					});

					if (isSvelteScoped) {
						seen.add(key);
						groups.component.push({
							selector: rule.selectorText,
							displaySelector: cleanSelector(rule.selectorText),
							cssText: rule.style.cssText,
							matches: matchesElement
						});
					} else if (matchesElement) {
						seen.add(key);
						const source = classifySource(rule, isAdopted);
						groups[source].push({
							selector: rule.selectorText,
							displaySelector: cleanSelector(rule.selectorText),
							cssText: rule.style.cssText,
							matches: true
						});
					}
				}
			} catch {
				/* CORS or access error — skip sheet */
			}
		}

		return groups;
	}

	function classifySource(rule: CSSStyleRule, isAdopted: boolean): keyof GroupedRules {
		if (rule.selectorText.includes('[data-ic-type=')) return 'global';
		if (isAdopted) return 'dynamic';
		return 'component';
	}

	function formatCss(cssText: string): string {
		return cssText
			.split(';')
			.filter((s) => s.trim())
			.map((s) => `  ${s.trim()};`)
			.join('\n');
	}

	const ruleSections: { key: keyof GroupedRules; label: string }[] = [
		{ key: 'component', label: 'Component Styles' },
		{ key: 'dynamic', label: 'Dynamic Styles (.style())' },
		{ key: 'global', label: 'Global / Type Styles' }
	];
</script>

<div class="ic-dt-css">
	<!-- Toolbar with Refresh button -->
	<div class="ic-dt-css__toolbar">
		<button class="ic-dt-css__refresh" onclick={scan} disabled={scanning}>
			{scanning ? 'Scanning...' : 'Refresh'}
		</button>
	</div>

	<!-- Grouped rules for a single component -->
	{#snippet rulesContent(componentId: string)}
		{@const rules = rulesMap[componentId]}
		{#if rules}
			{#each ruleSections as section (section.key)}
				{@const sectionRules = rules[section.key]}
				{#if sectionRules.length > 0}
					{@const sk = sectionCollapseKey(componentId, section.key)}
					<div class="ic-dt-css__section">
						<button
							class="ic-dt-css__section-header"
							onclick={() => (collapsedSections[sk] = !collapsedSections[sk])}
						>
							<span
								class="ic-dt-css__chevron"
								class:ic-dt-css__chevron--open={!collapsedSections[sk]}
							>
								&#9654;
							</span>
							{section.label}
							<span class="ic-dt-css__count">{sectionRules.length}</span>
						</button>

						{#if !collapsedSections[sk]}
							<div class="ic-dt-css__rules">
								{#each sectionRules as rule, idx (rule.selector + idx)}
									<div
										class="ic-dt-css__rule"
										class:ic-dt-css__rule--muted={!rule.matches}
									>
										<div class="ic-dt-css__selector">
											{rule.displaySelector} &#123;
										</div>
										<pre class="ic-dt-css__body">{formatCss(rule.cssText)}</pre>
										<div class="ic-dt-css__brace">&#125;</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				{/if}
			{/each}

			{#if totalRules(rules) === 0}
				<div class="ic-dt-css__empty">No matching CSS rules</div>
			{/if}
		{/if}
	{/snippet}

	<!-- Recursive child section -->
	{#snippet childSection(info: ChildComponentInfo)}
		{@const cid = info.componentId}
		{@const count = totalRules(rulesMap[cid])}
		<div class="ic-dt-css__child">
			<button
				class="ic-dt-css__child-header"
				onclick={() => (expandedChildren[cid] = !expandedChildren[cid])}
			>
				<span
					class="ic-dt-css__tree-chevron"
					class:ic-dt-css__tree-chevron--open={expandedChildren[cid]}
				>&#9654;</span>
				<span class="ic-dt-css__child-type">{shortType(info.componentType)}</span>
				<span class="ic-dt-css__child-target">({info.target})</span>
				{#if count > 0}
					<span class="ic-dt-css__badge">{count}</span>
				{/if}
			</button>

			{#if expandedChildren[cid]}
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
			{#if totalRules(rulesMap[componentInfo.componentId]) > 0}
				<span class="ic-dt-css__badge">{totalRules(rulesMap[componentInfo.componentId])}</span>
			{/if}
		</button>

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

	.ic-dt-css__toolbar {
		padding: 6px 10px;
		border-bottom: 1px solid var(--ic-border);
		display: flex;
		justify-content: flex-end;
	}

	.ic-dt-css__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}

	/* --- Refresh button --- */

	.ic-dt-css__refresh {
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

	.ic-dt-css__refresh:hover:not(:disabled) {
		color: var(--ic-foreground);
		border-color: var(--ic-muted-foreground);
	}

	.ic-dt-css__refresh:disabled {
		opacity: 0.5;
		cursor: default;
	}

	/* --- Tree structure (matches other panels) --- */

	.ic-dt-css__child {
		border-top: 1px solid var(--ic-border);
		margin-top: 2px;
	}

	.ic-dt-css__child--root {
		border-top: none;
		margin-top: 0;
	}

	.ic-dt-css__child-header {
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

	.ic-dt-css__child-header:hover {
		background: rgba(128, 128, 128, 0.1);
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

	/* --- Rule count badge on tree headers --- */

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

	/* --- Rule sections (Component Styles, Dynamic, Global) --- */

	.ic-dt-css__section {
		border-bottom: 1px solid rgba(128, 128, 128, 0.08);
	}

	.ic-dt-css__section-header {
		all: unset;
		display: flex;
		align-items: center;
		gap: 6px;
		width: 100%;
		padding: 4px 10px;
		cursor: pointer;
		font-weight: 500;
		font-size: var(--ic-font-size);
		font-family: var(--ic-font-family);
		color: var(--ic-foreground);
		box-sizing: border-box;
	}

	.ic-dt-css__section-header:hover {
		background: rgba(128, 128, 128, 0.06);
	}

	.ic-dt-css__chevron {
		font-size: 0.6em;
		transition: transform 0.15s;
		display: inline-block;
		color: var(--ic-muted-foreground);
	}

	.ic-dt-css__chevron--open {
		transform: rotate(90deg);
	}

	.ic-dt-css__count {
		color: var(--ic-muted-foreground);
		font-weight: 400;
		font-size: 0.85em;
	}

	/* --- Rules --- */

	.ic-dt-css__rules {
		padding: 4px 0;
	}

	.ic-dt-css__rule {
		padding: 2px 10px 4px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.06);
	}

	.ic-dt-css__rule:last-child {
		border-bottom: none;
	}

	.ic-dt-css__rule--muted {
		opacity: 0.4;
	}

	.ic-dt-css__rule--muted .ic-dt-css__selector {
		color: var(--ic-muted-foreground);
	}

	.ic-dt-css__selector {
		color: var(--ic-primary);
		font-weight: 500;
	}

	.ic-dt-css__body {
		margin: 0;
		padding: 0 0 0 8px;
		color: var(--ic-foreground);
		font-size: var(--ic-font-size);
		line-height: 1.5;
		white-space: pre-wrap;
		word-break: break-all;
	}

	.ic-dt-css__brace {
		color: var(--ic-muted-foreground);
	}
</style>
