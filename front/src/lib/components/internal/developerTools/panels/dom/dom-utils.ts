/**
 * DOM inspection utilities for DeveloperTools.
 *
 * Provides DOM tree scanning, CSS rule collection for individual elements,
 * selector cleaning (strip .svelte-* hashes), and highlight overlay management.
 */

import type { CssRule, DomNode } from '../../devtools-types';

// ─── Selector cleaning ───────────────────────────────────────────────

/** Strip .svelte-[hash] fragments from a CSS selector for display. */
export function cleanSelector(raw: string): string {
	return raw
		.replace(/\.svelte-[a-z0-9]+/g, '')
		.replace(/\s{2,}/g, ' ')
		.trim();
}

// ─── DOM tree building ───────────────────────────────────────────────

export interface DomTreeResult {
	tree: DomNode[];
	elementMap: Map<Node, DomNode>;
}

/**
 * Walk the component's DOM subtree and build a DomNode tree.
 * Skips the wrapper itself (display:contents div) — starts from its children.
 * Also builds an element→DomNode map for O(1) lookup (e.g. picker selection).
 */
export function buildDomTree(root: Element): DomTreeResult {
	const elementMap = new Map<Node, DomNode>();
	const tree: DomNode[] = [];
	let idx = 0;
	for (const child of Array.from(root.childNodes)) {
		const node = walkNode(child, String(idx), elementMap);
		if (node) {
			tree.push(node);
			idx++;
		}
	}
	return { tree, elementMap };
}

function walkNode(
	domNode: Node,
	id: string,
	elementMap: Map<Node, DomNode>
): DomNode | null {
	// Text node
	if (domNode.nodeType === Node.TEXT_NODE) {
		const text = domNode.textContent?.trim();
		if (!text) return null;
		const node: DomNode = {
			id,
			nodeType: 3,
			textContent: text,
			children: [],
			hasChildren: false,
			element: domNode as Text
		};
		elementMap.set(domNode, node);
		return node;
	}

	// Skip comments and non-element nodes
	if (domNode.nodeType !== Node.ELEMENT_NODE) return null;

	const el = domNode as Element;
	const tagName = el.tagName.toLowerCase();

	// Collect attributes, filtering out Svelte internals
	const attrs: Array<{ name: string; value: string }> = [];
	for (const attr of Array.from(el.attributes)) {
		if (attr.name.startsWith('data-svelte')) continue;
		if (attr.name === 'class') {
			const cleaned = attr.value
				.replace(/\bsvelte-[a-z0-9]+\b/g, '')
				.trim()
				.replace(/\s{2,}/g, ' ');
			if (cleaned) attrs.push({ name: 'class', value: cleaned });
		} else {
			attrs.push({ name: attr.name, value: attr.value });
		}
	}

	// Walk children recursively
	const children: DomNode[] = [];
	let childIdx = 0;
	for (const child of Array.from(el.childNodes)) {
		const childNode = walkNode(child, `${id}-${childIdx}`, elementMap);
		if (childNode) {
			children.push(childNode);
			childIdx++;
		}
	}

	const node: DomNode = {
		id,
		nodeType: 1,
		tagName,
		attributes: attrs.length > 0 ? attrs : undefined,
		children,
		hasChildren: children.length > 0,
		element: el
	};
	elementMap.set(el, node);
	return node;
}

// ─── Ancestor ID calculation ─────────────────────────────────────────

/** Given a DomNode id like "0-2-1", return ancestor ids: ["0", "0-2"]. */
export function findAncestorIds(nodeId: string): string[] {
	const parts = nodeId.split('-');
	const ancestors: string[] = [];
	for (let i = 1; i < parts.length; i++) {
		ancestors.push(parts.slice(0, i).join('-'));
	}
	return ancestors;
}

// ─── CSS rules for a single element ──────────────────────────────────

/** Collect all CSS rules matching a specific element. */
export function collectElementRules(element: Element): CssRule[] {
	const rules: CssRule[] = [];
	const seen = new Set<string>();

	const allSheets: CSSStyleSheet[] = [
		...Array.from(document.styleSheets),
		...(document.adoptedStyleSheets ?? [])
	];

	for (const sheet of allSheets) {
		try {
			for (const rule of Array.from(sheet.cssRules)) {
				if (!(rule instanceof CSSStyleRule)) continue;
				if (rule.selectorText.startsWith('.ic-dt')) continue;

				try {
					if (!element.matches(rule.selectorText)) continue;
				} catch {
					continue;
				}

				const key = `${rule.selectorText}|${rule.style.cssText}`;
				if (seen.has(key)) continue;
				seen.add(key);

				rules.push({
					selector: rule.selectorText,
					displaySelector: cleanSelector(rule.selectorText),
					cssText: rule.style.cssText,
					matches: true
				});
			}
		} catch {
			/* CORS or access error — skip sheet */
		}
	}
	return rules;
}

// ─── Highlight overlay ───────────────────────────────────────────────

let highlightOverlay: HTMLDivElement | null = null;

/** Show a highlight overlay on the given element within a positioned container. */
export function showHighlight(element: Element, container: Element): void {
	if (!highlightOverlay) {
		highlightOverlay = document.createElement('div');
		highlightOverlay.className = 'ic-dt-highlight';
		highlightOverlay.style.cssText = [
			'position: absolute',
			'pointer-events: none',
			'z-index: 10000',
			'background: rgba(66, 133, 244, 0.15)',
			'border: 1px solid rgba(66, 133, 244, 0.6)',
			'border-radius: 2px',
			'transition: top 0.08s, left 0.08s, width 0.08s, height 0.08s'
		].join(';');
	}

	const containerRect = container.getBoundingClientRect();
	const elRect = element.getBoundingClientRect();

	highlightOverlay.style.top = `${elRect.top - containerRect.top + container.scrollTop}px`;
	highlightOverlay.style.left = `${elRect.left - containerRect.left + container.scrollLeft}px`;
	highlightOverlay.style.width = `${elRect.width}px`;
	highlightOverlay.style.height = `${elRect.height}px`;

	if (!highlightOverlay.parentElement) {
		container.appendChild(highlightOverlay);
	}
}

/** Remove the highlight overlay from the DOM. */
export function hideHighlight(): void {
	highlightOverlay?.remove();
}
