import { EditorView } from '@codemirror/view';
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { tags as t } from '@lezer/highlight';
import type { Extension } from '@codemirror/state';

/**
 * Industrial Flat editor theme for CodeMirror 6.
 *
 * Uses `--ic-*` CSS variables so it adapts to the active IC theme.
 * Sharp edges, inset shadows, flat colors — no glossy gradients.
 */
const editorTheme = EditorView.theme({
  '&': {
    color: 'var(--ic-foreground)',
    backgroundColor: 'var(--ic-background)',
    height: '100%',
  },
  '&.cm-focused': {
    outline: 'none',
  },
  '.cm-content': {
    caretColor: 'var(--ic-primary)',
    fontFamily: "'Roboto Mono', ui-monospace, monospace",
    padding: '4px 0',
  },
  '.cm-cursor, .cm-dropCursor': {
    borderLeftColor: 'var(--ic-primary)',
    borderLeftWidth: '2px',
  },
  // NOTE: uses --ic-ce-* tokens defined on .ic-ce (Chromium 104 compat)
  '.cm-selectionBackground': {
    backgroundColor: 'var(--ic-ce-selection)',
  },
  '&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground': {
    backgroundColor: 'var(--ic-ce-selection-focus)',
  },
  '.cm-activeLine': {
    backgroundColor: 'var(--ic-ce-active-line)',
  },
  '.cm-selectionMatch': {
    backgroundColor: 'var(--ic-ce-selection-match)',
  },
  // Gutters — Industrial Flat recessed channel
  '.cm-gutters': {
    backgroundColor: 'var(--ic-secondary)',
    color: 'var(--ic-muted-foreground)',
    border: 'none',
    boxShadow: 'inset -1px 0 2px rgba(0,0,0,0.06)',
    borderRight: '1px solid var(--ic-border)',
  },
  '.cm-lineNumbers .cm-gutterElement': {
    padding: '0 8px 0 4px',
    minWidth: '2.5em',
    fontSize: '0.9em',
  },
  '.cm-activeLineGutter': {
    backgroundColor: 'var(--ic-ce-active-gutter)',
    color: 'var(--ic-foreground)',
  },
  // Fold gutter
  '.cm-foldGutter .cm-gutterElement': {
    padding: '0 4px',
    cursor: 'pointer',
    color: 'var(--ic-muted-foreground)',
  },
  '.cm-foldGutter .cm-gutterElement:hover': {
    color: 'var(--ic-primary)',
  },
  '.cm-foldPlaceholder': {
    backgroundColor: 'transparent',
    border: 'none',
    color: 'var(--ic-ce-fold)',
    opacity: '0.4',
    padding: '0 1px',
    margin: '0 2px',
    cursor: 'pointer',
    fontSize: '0.9em',
    letterSpacing: '0.5px',
  },
  '.cm-foldPlaceholder:hover': {
    opacity: '0.8',
  },
  // Bracket matching — subtle underline + faint background
  '.cm-matchingBracket': {
    backgroundColor: 'var(--ic-ce-bracket)',
    borderBottom: '2px solid var(--ic-primary)',
    outline: 'none',
  },
  '.cm-nonmatchingBracket': {
    backgroundColor: 'var(--ic-ce-bracket-bad)',
    borderBottom: '2px solid var(--ic-destructive)',
    outline: 'none',
  },
  // Search match highlights (the panel itself is styled in CodeEditor.svelte)
  '.cm-searchMatch': {
    backgroundColor: 'var(--ic-ce-search)',
    outline: '1px solid rgba(255, 193, 7, 0.40)',
  },
  '.cm-searchMatch.cm-searchMatch-selected': {
    backgroundColor: 'var(--ic-ce-search-active)',
    outline: '1px solid rgba(66, 133, 244, 0.40)',
  },
  // Placeholder
  '.cm-placeholder': {
    color: 'var(--ic-muted-foreground)',
    fontStyle: 'italic',
  },
  // Tooltips
  '.cm-tooltip': {
    backgroundColor: 'var(--ic-background)',
    border: '1px solid var(--ic-border)',
    borderRadius: '2px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.12)',
  },
  // Scrollbar styling
  '.cm-scroller': {
    overflow: 'auto',
    fontFamily: "'Roboto Mono', ui-monospace, monospace",
  },
});

/**
 * Syntax highlighting using IC theme variables.
 *
 * Color mapping:
 * - Keywords → --ic-primary (the brand color anchors the code)
 * - Strings  → --ic-success (green = data/values)
 * - Numbers  → --ic-warning (warm = numeric literals)
 * - Comments → --ic-muted-foreground, italic
 * - Functions → --ic-info (blue = callable things)
 * - Errors   → --ic-destructive
 */
const highlightStyle = HighlightStyle.define([
  // Keywords
  { tag: t.keyword, color: 'var(--ic-primary)', fontWeight: '600' },
  { tag: t.controlKeyword, color: 'var(--ic-primary)', fontWeight: '600' },
  { tag: t.definitionKeyword, color: 'var(--ic-primary)', fontWeight: '600' },
  { tag: t.modifier, color: 'var(--ic-primary)', fontWeight: '600' },

  // Literals
  { tag: t.string, color: 'var(--ic-success)' },
  { tag: t.number, color: 'var(--ic-warning)' },
  { tag: t.bool, color: 'var(--ic-warning)', fontWeight: '600' },

  // Identifiers
  { tag: t.variableName, color: 'var(--ic-foreground)' },
  { tag: t.definition(t.variableName), color: 'var(--ic-foreground)', fontWeight: '600' },
  { tag: t.function(t.variableName), color: 'var(--ic-info)' },
  { tag: t.function(t.definition(t.variableName)), color: 'var(--ic-info)', fontWeight: '600' },
  { tag: t.propertyName, color: 'var(--ic-foreground)' },
  { tag: t.definition(t.className), color: 'var(--ic-info)', fontWeight: '700' },
  { tag: t.special(t.variableName), color: 'var(--ic-primary)' },
  { tag: t.typeName, color: 'var(--ic-info)' },

  // Operators
  { tag: t.operator, color: 'var(--ic-foreground)' },
  { tag: t.arithmeticOperator, color: 'var(--ic-foreground)' },
  { tag: t.logicOperator, color: 'var(--ic-primary)' },
  { tag: t.compareOperator, color: 'var(--ic-primary)' },
  { tag: t.definitionOperator, color: 'var(--ic-foreground)' },

  // Comments
  { tag: t.lineComment, color: 'var(--ic-muted-foreground)', fontStyle: 'italic' },
  { tag: t.blockComment, color: 'var(--ic-muted-foreground)', fontStyle: 'italic' },

  // Punctuation
  { tag: t.paren, color: 'var(--ic-muted-foreground)' },
  { tag: t.squareBracket, color: 'var(--ic-muted-foreground)' },
  { tag: t.brace, color: 'var(--ic-muted-foreground)' },
  { tag: t.separator, color: 'var(--ic-muted-foreground)' },
  { tag: t.punctuation, color: 'var(--ic-muted-foreground)' },
  { tag: t.meta, color: 'var(--ic-muted-foreground)' },

  // Errors
  { tag: t.invalid, color: 'var(--ic-destructive)', textDecoration: 'underline wavy' },

  // HTML/Markdown (for lang-markdown, lang-css, lang-javascript)
  { tag: t.heading, color: 'var(--ic-primary)', fontWeight: '700' },
  { tag: t.link, color: 'var(--ic-info)', textDecoration: 'underline' },
  { tag: t.emphasis, fontStyle: 'italic' },
  { tag: t.strong, fontWeight: '700' },
  { tag: t.tagName, color: 'var(--ic-primary)' },
  { tag: t.attributeName, color: 'var(--ic-info)' },
  { tag: t.attributeValue, color: 'var(--ic-success)' },
  { tag: t.regexp, color: 'var(--ic-warning)' },
]);

/** Combined Industrial Flat theme extension. */
export const industrialFlatTheme: Extension = [
  editorTheme,
  syntaxHighlighting(highlightStyle),
];
