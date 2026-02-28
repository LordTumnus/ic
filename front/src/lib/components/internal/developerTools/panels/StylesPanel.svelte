<!--
  StylesPanel.svelte — Full stylesheet view for inspected component.

  Scans document.styleSheets to collect all CSS rules matching the
  component's DOM subtree, grouped by source (component/dynamic/global).
  Component-scoped rules include ALL rules (even non-matching) so the user
  can see inactive variants/states. Svelte hash selectors are cleaned.
-->
<script lang="ts">
	import type { ComponentInfo, CssRule, GroupedRules } from '../devtools-types';
	import { cleanSelector } from './dom/dom-utils';

	let {
		componentInfo
	}: {
		componentInfo: ComponentInfo;
	} = $props();

	let rules = $state<GroupedRules>({ component: [], dynamic: [], global: [] });
	let scanning = $state(false);

	// Scan on mount
	$effect(() => {
		if (componentInfo.componentId) {
			scan();
		}
	});

	function scan() {
		scanning = true;
		requestAnimationFrame(() => {
			rules = collectComponentRules(componentInfo.componentId);
			scanning = false;
		});
	}

	function collectComponentRules(componentId: string): GroupedRules {
		const wrapper = document.getElementById(componentId);
		if (!wrapper) return { component: [], dynamic: [], global: [] };

		const elements = [wrapper, ...Array.from(wrapper.querySelectorAll('*'))];
		const groups: GroupedRules = { component: [], dynamic: [], global: [] };
		const seen = new Set<string>();

		const allSheets: CSSStyleSheet[] = [
			...Array.from(document.styleSheets),
			...(document.adoptedStyleSheets ?? [])
		];

		// Phase 1: Discover which .svelte-XXXX hashes belong to this component
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

		// Phase 2: Collect rules — ALL svelte-scoped rules with discovered hashes,
		// but only matching rules for dynamic/global groups
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
						// Component-scoped: include ALL rules (matching or not)
						seen.add(key);
						groups.component.push({
							selector: rule.selectorText,
							displaySelector: cleanSelector(rule.selectorText),
							cssText: rule.style.cssText,
							matches: matchesElement
						});
					} else if (matchesElement) {
						// Dynamic / Global: only include matching rules
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

	const sections: { key: keyof GroupedRules; label: string }[] = [
		{ key: 'component', label: 'Component Styles' },
		{ key: 'dynamic', label: 'Dynamic Styles (.style())' },
		{ key: 'global', label: 'Global / Type Styles' }
	];

	let collapsed = $state<Record<string, boolean>>({});
</script>

<div class="ic-dt-css">
	<div class="ic-dt-css__toolbar">
		<button class="ic-dt-css__refresh" onclick={scan} disabled={scanning}>
			{scanning ? 'Scanning...' : 'Refresh'}
		</button>
	</div>

	{#each sections as section (section.key)}
		{@const sectionRules = rules[section.key]}
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

	{#if rules.component.length === 0 && rules.dynamic.length === 0 && rules.global.length === 0}
		<div class="ic-dt-css__empty">
			{scanning ? 'Scanning stylesheets...' : 'No matching CSS rules found'}
		</div>
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
		justify-content: flex-end;
	}

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
