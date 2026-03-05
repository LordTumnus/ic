/**
 * Typst language support for CodeMirror 6.
 *
 * Uses the official `typst-syntax` WASM parser via `codemirror-lang-typst`,
 * but bypasses its buggy incremental update code (`edit()` + `applyTreeEdit()`).
 *
 * Both the WASM `edit()` and the JS `applyTreeEdit()` corrupt state on
 * incremental edits. Our fix: on any document change, destroy the WASM
 * parser entirely via `clearParser()`. The next parse creates a fresh
 * parser from the full document text — correct and fast for typical sizes.
 *
 * Includes the package's bundled `TypstHighlightStyle` for Typst-native
 * colors (keywords, headings, brackets, etc.).
 */

import {
  Language,
  defineLanguageFacet,
  LanguageSupport,
  syntaxHighlighting,
  language,
} from '@codemirror/language';
import { StateField } from '@codemirror/state';
import { TypstParser, typstHighlight, TypstHighlightSytle } from 'codemirror-lang-typst';

// ============================================================================
// Fixed update listener
// ============================================================================

/**
 * Create a StateField that resets the WASM parser on every document change.
 *
 * `clearParser()` destroys the WASM parser instance + cached tree. The next
 * `createParse()` call rebuilds a fresh parser from the full document text.
 * This bypasses both the buggy `edit()` and `applyTreeEdit()` code paths.
 */
function fixedUpdateListener(parser: TypstParser): StateField<null> {
  return StateField.define({
    create() { return null; },
    update(_value, transaction) {
      if (
        transaction.docChanged ||
        transaction.startState.facet(language) !== transaction.state.facet(language)
      ) {
        parser.clearParser();
      }
      return null;
    },
  });
}

// ============================================================================
// Export
// ============================================================================

const facet = defineLanguageFacet({
  commentTokens: { block: { open: '/*', close: '*/' }, line: '//' },
});

let cached: LanguageSupport | null = null;

/**
 * Create Typst language support for CodeMirror.
 *
 * Uses the official `typst-syntax` WASM parser with a fixed update
 * listener and IC-themed highlighting.
 */
export function typst(): LanguageSupport {
  if (cached) return cached;

  const parser = new (TypstParser as any)(typstHighlight) as TypstParser;
  const listener = fixedUpdateListener(parser);

  cached = new LanguageSupport(
    new Language(facet, parser, [
      listener,
      syntaxHighlighting(TypstHighlightSytle),
    ], 'typst'),
  );

  return cached;
}
