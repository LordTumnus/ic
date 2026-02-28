<!--
  StylesPanel.svelte — Full stylesheet view for inspected component.

  Scans document.styleSheets to collect all CSS rules matching the
  component's DOM subtree, grouped by source (component/dynamic/global).
  When the component has children, subtabs let the user switch between
  parent-only and per-child CSS rules.
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

	// --- Per-component style entries ---

	interface ComponentStyleEntry {
		id: string;
		label: string;
		rules: GroupedRules;
	}

	let entries = $state<ComponentStyleEntry[]>([]);
	let activeComponentId = $state<string>('');
	let scanning = $state(false);

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

	/** Recursively flatten children into a flat array with direct child IDs. */
	function flattenChildren(info: ComponentInfo): ChildComponentInfo[] {
		const result: ChildComponentInfo[] = [];
		for (const child of info.children ?? []) {
			result.push(child);
			result.push(...flattenChildren(child));
		}
		return result;
	}

	/** Get direct child IDs of a component info node. */
	function directChildIds(info: ComponentInfo): string[] {
		return (info.children ?? []).map((c) => c.componentId);
	}

	// --- Core scan logic ---

	function scan() {
		scanning = true;
		requestAnimationFrame(() => {
			const result: ComponentStyleEntry[] = [];

			// Parent: exclude direct children's subtrees
			const parentChildIds = directChildIds(componentInfo);
			const parentRules = collectRulesExcludingChildren(
				componentInfo.componentId,
				parentChildIds
			);
			result.push({
				id: componentInfo.componentId,
				label: shortType(componentInfo.componentType),
				rules: parentRules
			});

			// All descendants (flattened)
			const allDescendants = flattenChildren(componentInfo);
			for (const childInfo of allDescendants) {
				const grandchildIds = directChildIds(childInfo);
				const childRules = collectRulesExcludingChildren(
					childInfo.componentId,
					grandchildIds
				);
				result.push({
					id: childInfo.componentId,
					label: `${shortType(childInfo.componentType)} (${childInfo.target})`,
					rules: childRules
				});
			}

			entries = result;
			if (!activeComponentId || !result.some((e) => e.id === activeComponentId)) {
				activeComponentId = result[0]?.id ?? '';
			}
			scanning = false;
		});
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

	let collapsed = $state<Record<string, boolean>>({});

	const activeEntry = $derived(entries.find((e) => e.id === activeComponentId));
	const hasChildren = $derived(entries.length > 1);
</script>

<div class="ic-dt-css">
	<div class="ic-dt-css__toolbar">
		<!-- Component subtabs (only when children exist) -->
		{#if hasChildren}
			<div class="ic-dt-css__component-tabs">
				{#each entries as entry (entry.id)}
					<button
						class="ic-dt-css__component-tab"
						class:ic-dt-css__component-tab--active={activeComponentId === entry.id}
						onclick={() => (activeComponentId = entry.id)}
					>
						{entry.label}
					</button>
				{/each}
			</div>
		{/if}
		<button class="ic-dt-css__refresh" onclick={scan} disabled={scanning}>
			{scanning ? 'Scanning...' : 'Refresh'}
		</button>
	</div>

	<!-- Rules for active component -->
	{#if activeEntry}
		{#each ruleSections as section (section.key)}
			{@const sectionRules = activeEntry.rules[section.key]}
			{#if sectionRules.length > 0}
				<div class="ic-dt-css__section">
					<button
						class="ic-dt-css__section-header"
						onclick={() => (collapsed[section.key] = !collapsed[section.key])}
					>
						<span
							class="ic-dt-css__chevron"
							class:ic-dt-css__chevron--open={!collapsed[section.key]}
						>
							&#9654;
						</span>
						{section.label}
						<span class="ic-dt-css__count">{sectionRules.length}</span>
					</button>

					{#if !collapsed[section.key]}
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

		{#if activeEntry.rules.component.length === 0 && activeEntry.rules.dynamic.length === 0 && activeEntry.rules.global.length === 0}
			<div class="ic-dt-css__empty">
				{scanning ? 'Scanning stylesheets...' : 'No matching CSS rules found'}
			</div>
		{/if}
	{:else if !scanning}
		<div class="ic-dt-css__empty">No matching CSS rules found</div>
	{/if}
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
		align-items: center;
		gap: 8px;
	}

	/* --- Component subtabs --- */

	.ic-dt-css__component-tabs {
		display: flex;
		gap: 0;
		flex: 1;
		overflow-x: auto;
	}

	.ic-dt-css__component-tab {
		all: unset;
		padding: 3px 10px;
		cursor: pointer;
		font-family: var(--ic-font-family);
		font-size: 0.9em;
		color: var(--ic-muted-foreground);
		border-bottom: 2px solid transparent;
		white-space: nowrap;
		transition: color 0.15s, border-color 0.15s;
	}

	.ic-dt-css__component-tab:hover {
		color: var(--ic-foreground);
	}

	.ic-dt-css__component-tab--active {
		color: var(--ic-primary);
		border-bottom-color: var(--ic-primary);
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
		margin-left: auto;
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

	/* --- Sections --- */

	.ic-dt-css__section {
		border-bottom: 1px solid var(--ic-border);
	}

	.ic-dt-css__section-header {
		all: unset;
		display: flex;
		align-items: center;
		gap: 6px;
		width: 100%;
		padding: 5px 10px;
		cursor: pointer;
		font-weight: 600;
		font-size: var(--ic-font-size);
		font-family: var(--ic-font-family);
		color: var(--ic-foreground);
		background: var(--ic-secondary);
		box-sizing: border-box;
	}

	.ic-dt-css__section-header:hover {
		background: rgba(128, 128, 128, 0.1);
	}

	.ic-dt-css__chevron {
		font-size: 0.65em;
		transition: transform 0.15s;
		display: inline-block;
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

	.ic-dt-css__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}
</style>
