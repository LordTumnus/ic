import { Compartment, type Extension, EditorState } from '@codemirror/state';
import {
  EditorView,
  keymap,
  lineNumbers,
  highlightActiveLine,
  highlightActiveLineGutter,
  drawSelection,
  placeholder as placeholderExt,
  scrollPastEnd,
} from '@codemirror/view';
import {
  indentOnInput,
  bracketMatching,
  foldGutter,
  foldKeymap,
  LanguageSupport,
  indentUnit,
} from '@codemirror/language';
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import {
  search,
  SearchQuery,
  setSearchQuery,
  findNext,
  findPrevious,
  replaceNext,
  replaceAll,
} from '@codemirror/search';
import { closeBrackets, closeBracketsKeymap } from '@codemirror/autocomplete';
import { highlightSelectionMatches } from '@codemirror/search';

import { matlab } from '$lib/languages/matlab';
import { industrialFlatTheme } from './theme';
import { zebraStripes } from './zebra-stripes';
import { uneditableLines, programmatic } from './uneditable-lines';
export { programmatic };
import { lineHighlight } from './line-highlight';
import { rulers } from './rulers';
import { indentGuides } from './indent-guides';

/** All compartments — one per reactive prop that controls extensions. */
export interface EditorCompartments {
  language: Compartment;
  readOnly: Compartment;
  lineNumbers: Compartment;
  lineWrapping: Compartment;
  highlightActiveLine: Compartment;
  tabSize: Compartment;
  placeholder: Compartment;
  fontSize: Compartment;
  bracketMatching: Compartment;
  codeFolding: Compartment;
  searchPanel: Compartment;
  highlightSelectionMatches: Compartment;
  closeBrackets: Compartment;
  allowMultipleSelections: Compartment;
  zebraStripes: Compartment;
  uneditableLines: Compartment;
  highlightedLines: Compartment;
  rulers: Compartment;
  indentGuides: Compartment;
  scrollPastEnd: Compartment;
}

/** Creates all compartments — must be called once per editor instance. */
export function createCompartments(): EditorCompartments {
  return {
    language: new Compartment(),
    readOnly: new Compartment(),
    lineNumbers: new Compartment(),
    lineWrapping: new Compartment(),
    highlightActiveLine: new Compartment(),
    tabSize: new Compartment(),
    placeholder: new Compartment(),
    fontSize: new Compartment(),
    bracketMatching: new Compartment(),
    codeFolding: new Compartment(),
    searchPanel: new Compartment(),
    highlightSelectionMatches: new Compartment(),
    closeBrackets: new Compartment(),
    allowMultipleSelections: new Compartment(),
    zebraStripes: new Compartment(),
    uneditableLines: new Compartment(),
    highlightedLines: new Compartment(),
    rulers: new Compartment(),
    indentGuides: new Compartment(),
    scrollPastEnd: new Compartment(),
  };
}

// ─── Language resolution ─────────────────────────────────────

let jsLang: LanguageSupport | null = null;
let mdLang: LanguageSupport | null = null;
let cssLang: LanguageSupport | null = null;
let typstLang: LanguageSupport | null = null;
let latexLang: LanguageSupport | null = null;

/** Lazy-load language support. */
async function loadLanguage(lang: string): Promise<Extension> {
  switch (lang) {
    case 'matlab':
      return matlab();
    case 'javascript':
      if (!jsLang) {
        const mod = await import('@codemirror/lang-javascript');
        jsLang = mod.javascript();
      }
      return jsLang;
    case 'markdown':
      if (!mdLang) {
        const mod = await import('@codemirror/lang-markdown');
        mdLang = mod.markdown();
      }
      return mdLang;
    case 'css':
      if (!cssLang) {
        const mod = await import('@codemirror/lang-css');
        cssLang = mod.css();
      }
      return cssLang;
    case 'typst':
      if (!typstLang) {
        const mod = await import('$lib/languages/typst');
        typstLang = mod.typst();
      }
      return typstLang;
    case 'latex':
      if (!latexLang) {
        const mod = await import('codemirror-lang-latex');
        latexLang = mod.latex();
      }
      return latexLang;
    case 'plain':
    default:
      return [];
  }
}

export { loadLanguage };

// ─── Extension builders ──────────────────────────────────────
// Each returns the Extension for its compartment's current value.

export function languageExt(lang: Extension): Extension {
  return lang;
}

export function readOnlyExt(on: boolean): Extension {
  return EditorState.readOnly.of(on);
}

export function lineNumbersExt(on: boolean): Extension {
  return on ? [lineNumbers(), highlightActiveLineGutter()] : [];
}

export function lineWrappingExt(on: boolean): Extension {
  return on ? EditorView.lineWrapping : [];
}

export function highlightActiveLineExt(on: boolean): Extension {
  return on ? highlightActiveLine() : [];
}

export function tabSizeExt(size: number): Extension {
  return [EditorState.tabSize.of(size), indentUnit.of(' '.repeat(size))];
}

export function placeholderExt2(text: string): Extension {
  return text ? placeholderExt(text) : [];
}

export function fontSizeExt(px: number): Extension {
  return px > 0
    ? EditorView.theme({ '&': { fontSize: `${px}px` } })
    : [];
}

export function bracketMatchingExt(on: boolean): Extension {
  return on ? bracketMatching() : [];
}

export function codeFoldingExt(on: boolean): Extension {
  return on ? [foldGutter(), keymap.of(foldKeymap)] : [];
}

export function searchPanelExt(): Extension {
  // search() provides match highlighting & state; panel UI is custom Svelte.
  // createPanel returns a hidden element so CM never shows its built-in panel
  // (findNext/findPrevious fall back to openSearchPanel when query is empty).
  return search({
    top: true,
    createPanel: () => {
      const el = document.createElement('span');
      el.style.display = 'none';
      return { dom: el, top: true };
    },
  });
}

export function highlightSelectionMatchesExt(on: boolean): Extension {
  return on ? highlightSelectionMatches() : [];
}

export function closeBracketsExt(on: boolean): Extension {
  return on ? [closeBrackets(), keymap.of(closeBracketsKeymap)] : [];
}

export function allowMultipleSelectionsExt(on: boolean): Extension {
  return EditorState.allowMultipleSelections.of(on);
}

export function zebraStripesExt(on: boolean, step: number): Extension {
  return on ? zebraStripes(step) : [];
}

export function uneditableLinesExt(lines: number[]): Extension {
  return lines.length > 0 ? uneditableLines(lines) : [];
}

export function highlightedLinesExt(lines: number[]): Extension {
  return lines.length > 0 ? lineHighlight(lines) : [];
}

export function rulersExt(columns: number[]): Extension {
  return columns.length > 0 ? rulers(columns) : [];
}

export function indentGuidesExt(on: boolean, tabSize: number): Extension {
  return on ? indentGuides(tabSize) : [];
}

export function scrollPastEndExt(on: boolean): Extension {
  return on ? scrollPastEnd() : [];
}

// ─── Initial extensions ──────────────────────────────────────

export interface EditorProps {
  language: Extension;
  readOnly: boolean;
  showLineNumbers: boolean;
  lineWrapping: boolean;
  showHighlightActiveLine: boolean;
  tabSize: number;
  placeholder: string;
  fontSize: number;
  showBracketMatching: boolean;
  codeFolding: boolean;
  showHighlightSelectionMatches: boolean;
  showCloseBrackets: boolean;
  allowMultipleSelections: boolean;
  showZebraStripes: boolean;
  zebraStripeStep: number;
  uneditableLineNumbers: number[];
  highlightedLineNumbers: number[];
  rulerColumns: number[];
  showIndentGuides: boolean;
  showScrollPastEnd: boolean;
}

/** Build the full initial extension array for an EditorState. */
export function buildExtensions(
  c: EditorCompartments,
  p: EditorProps,
): Extension[] {
  return [
    // Theme (static — not compartmented)
    industrialFlatTheme,

    // Core keymaps
    keymap.of([indentWithTab, ...defaultKeymap, ...historyKeymap]),
    history(),
    drawSelection(),
    indentOnInput(),

    // Compartmented extensions — one per reactive prop
    c.language.of(languageExt(p.language)),
    c.readOnly.of(readOnlyExt(p.readOnly)),
    c.lineNumbers.of(lineNumbersExt(p.showLineNumbers)),
    c.lineWrapping.of(lineWrappingExt(p.lineWrapping)),
    c.highlightActiveLine.of(highlightActiveLineExt(p.showHighlightActiveLine)),
    c.tabSize.of(tabSizeExt(p.tabSize)),
    c.placeholder.of(placeholderExt2(p.placeholder)),
    c.fontSize.of(fontSizeExt(p.fontSize)),
    c.bracketMatching.of(bracketMatchingExt(p.showBracketMatching)),
    c.codeFolding.of(codeFoldingExt(p.codeFolding)),
    c.searchPanel.of(searchPanelExt()),
    c.highlightSelectionMatches.of(
      highlightSelectionMatchesExt(p.showHighlightSelectionMatches),
    ),
    c.closeBrackets.of(closeBracketsExt(p.showCloseBrackets)),
    c.allowMultipleSelections.of(
      allowMultipleSelectionsExt(p.allowMultipleSelections),
    ),
    c.zebraStripes.of(zebraStripesExt(p.showZebraStripes, p.zebraStripeStep)),
    c.uneditableLines.of(uneditableLinesExt(p.uneditableLineNumbers)),
    c.highlightedLines.of(highlightedLinesExt(p.highlightedLineNumbers)),
    c.rulers.of(rulersExt(p.rulerColumns)),
    c.indentGuides.of(indentGuidesExt(p.showIndentGuides, p.tabSize)),
    c.scrollPastEnd.of(scrollPastEndExt(p.showScrollPastEnd)),
  ];
}

// Re-export search utilities for the custom search panel
export { SearchQuery, setSearchQuery, findNext, findPrevious, replaceNext, replaceAll };
