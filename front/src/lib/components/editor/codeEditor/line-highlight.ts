import {
  Decoration,
  EditorView,
  ViewPlugin,
  type DecorationSet,
  type ViewUpdate,
} from '@codemirror/view';
import type { EditorState, Extension, Range } from '@codemirror/state';

/**
 * Line highlighting: colors specific lines.
 *
 * Line numbers are 1-based. Uses the --ic-ce-highlight token
 * defined on .ic-ce for the highlight color.
 */
const deco = Decoration.line({ class: 'ic-ce__highlight' });

function highlightDeco(
  state: EditorState,
  lines: Set<number>,
): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  const total = state.doc.lines;
  for (const ln of lines) {
    if (ln >= 1 && ln <= total) {
      ranges.push(deco.range(state.doc.line(ln).from));
    }
  }
  ranges.sort((a, b) => a.from - b.from);
  return Decoration.set(ranges);
}

export function lineHighlight(lineNumbers: number[]): Extension {
  const highlighted = new Set(lineNumbers);

  return [
    ViewPlugin.fromClass(
      class {
        decorations: DecorationSet;
        constructor(view: EditorView) {
          this.decorations = highlightDeco(view.state, highlighted);
        }
        update(update: ViewUpdate) {
          if (update.docChanged) {
            this.decorations = highlightDeco(update.state, highlighted);
          }
        }
      },
      { decorations: (v) => v.decorations },
    ),
    EditorView.baseTheme({
      '.ic-ce__highlight': {
        backgroundColor: 'var(--ic-ce-highlight)',
      },
    }),
  ];
}
