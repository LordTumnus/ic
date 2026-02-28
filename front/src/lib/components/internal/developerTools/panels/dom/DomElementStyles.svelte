<!--
  DomElementStyles.svelte — Shows CSS rules matching the selected DOM element.

  Collects all matching CSS rules from document stylesheets, cleans selectors
  of .svelte-* hashes, and renders them in the same format as StylesPanel.
  Also shows inline styles if present.
-->
<script lang="ts">
	import type { CssRule } from '../../devtools-types';
	import { collectElementRules, cleanSelector } from './dom-utils';

	let {
		element
	}: {
		element: Element;
	} = $props();

	let rules = $state<CssRule[]>([]);
	let inlineStyle = $state('');

	$effect(() => {
		if (element) {
			rules = collectElementRules(element);
			inlineStyle = (element as HTMLElement).style?.cssText?.trim() ?? '';
		} else {
			rules = [];
			inlineStyle = '';
		}
	});

	function formatCss(cssText: string): string {
		return cssText
			.split(';')
			.filter((s) => s.trim())
			.map((s) => `  ${s.trim()};`)
			.join('\n');
	}

	const tagSummary = $derived.by(() => {
		if (!element) return '';
		const tag = element.tagName.toLowerCase();
		const id = element.id ? `#${element.id}` : '';
		const cls = element.className
			? typeof element.className === 'string'
				? '.' +
					element.className
						.replace(/\bsvelte-[a-z0-9]+\b/g, '')
						.trim()
						.replace(/\s+/g, '.')
				: ''
			: '';
		return `${tag}${id}${cls}`;
	});
</script>

<div class="ic-dt-dom-s">
	<div class="ic-dt-dom-s__header">
		Styles for <span class="ic-dt-dom-s__el">{tagSummary}</span>
	</div>

	<!-- Inline styles -->
	{#if inlineStyle}
		<div class="ic-dt-dom-s__section">
			<div class="ic-dt-dom-s__section-label">element.style</div>
			<div class="ic-dt-dom-s__rule">
				<pre class="ic-dt-dom-s__body">{formatCss(inlineStyle)}</pre>
			</div>
		</div>
	{/if}

	<!-- Matched CSS rules -->
	{#if rules.length > 0}
		<div class="ic-dt-dom-s__section">
			<div class="ic-dt-dom-s__section-label">Matched Rules ({rules.length})</div>
			{#each rules as rule, idx (rule.selector + idx)}
				<div class="ic-dt-dom-s__rule">
					<div class="ic-dt-dom-s__selector">{rule.displaySelector} &#123;</div>
					<pre class="ic-dt-dom-s__body">{formatCss(rule.cssText)}</pre>
					<div class="ic-dt-dom-s__brace">&#125;</div>
				</div>
			{/each}
		</div>
	{:else}
		<div class="ic-dt-dom-s__empty">No matched CSS rules</div>
	{/if}
</div>

<style>
	.ic-dt-dom-s {
		font-family: var(--ic-font-family);
	}

	.ic-dt-dom-s__header {
		position: sticky;
		top: 0;
		z-index: 1;
		padding: 5px 10px;
		font-size: var(--ic-font-size);
		color: var(--ic-muted-foreground);
		background: var(--ic-secondary);
		border-bottom: 1px solid var(--ic-border);
	}

	.ic-dt-dom-s__el {
		color: #e06c75;
		font-family: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
		font-size: 11px;
	}

	.ic-dt-dom-s__section {
		border-bottom: 1px solid var(--ic-border);
	}

	.ic-dt-dom-s__section-label {
		padding: 4px 10px;
		font-size: 0.85em;
		font-weight: 600;
		color: var(--ic-muted-foreground);
		background: var(--ic-secondary);
	}

	.ic-dt-dom-s__rule {
		padding: 2px 10px 4px;
		border-bottom: 1px solid rgba(128, 128, 128, 0.06);
	}

	.ic-dt-dom-s__rule:last-child {
		border-bottom: none;
	}

	.ic-dt-dom-s__selector {
		color: var(--ic-primary);
		font-weight: 500;
	}

	.ic-dt-dom-s__body {
		margin: 0;
		padding: 0 0 0 8px;
		color: var(--ic-foreground);
		font-size: var(--ic-font-size);
		line-height: 1.5;
		white-space: pre-wrap;
		word-break: break-all;
	}

	.ic-dt-dom-s__brace {
		color: var(--ic-muted-foreground);
	}

	.ic-dt-dom-s__empty {
		color: var(--ic-muted-foreground);
		font-style: italic;
		padding: 12px 10px;
	}
</style>
