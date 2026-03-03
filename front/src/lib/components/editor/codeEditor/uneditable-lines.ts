import {
  Decoration,
  EditorView,
  ViewPlugin,
  type DecorationSet,
  type ViewUpdate,
} from '@codemirror/view';
import { EditorState, type Extension, type Range } from '@codemirror/state';

/**
 * Uneditable lines: locks specific lines from user editing.
 *
 * Two mechanisms:
 * 1. A transaction filter that rejects changes touching locked lines.
 * 2. A line decoration with a visual indicator (dimmed background).
 *
 * Line numbers are 1-based (matching MATLAB convention).
 */
const lockedLine = Decoration.line({ class: 'ic-ce__locked' });

function lockedDeco(
  state: EditorState,
  lines: Set<number>,
): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  const total = state.doc.lines;
  for (const ln of lines) {
    if (ln >= 1 && ln <= total) {
      ranges.push(lockedLine.range(state.doc.line(ln).from));
    }
  }
  ranges.sort((a, b) => a.from - b.from);
  return Decoration.set(ranges);
}

export function uneditableLines(lineNumbers: number[]): Extension {
  const locked = new Set(lineNumbers);

  return [
    // Visual decoration
    ViewPlugin.fromClass(
      class {
        decorations: DecorationSet;
        constructor(view: EditorView) {
          this.decorations = lockedDeco(view.state, locked);
        }
        update(update: ViewUpdate) {
          if (update.docChanged) {
            this.decorations = lockedDeco(update.state, locked);
          }
        }
      },
      { decorations: (v) => v.decorations },
    ),
    // Transaction filter: reject edits on locked lines
    EditorState.transactionFilter.of((tr) => {
      if (!tr.docChanged) return tr;
      let dominated = false;
      tr.changes.iterChangedRanges((fromA, toA) => {
        if (dominated) return;
        const lineFrom = tr.startState.doc.lineAt(fromA).number;
        const lineTo = tr.startState.doc.lineAt(toA).number;
        for (let ln = lineFrom; ln <= lineTo; ln++) {
          if (locked.has(ln)) {
            dominated = true;
            return;
          }
        }
      });
      return dominated ? [] : tr;
    }),
    // Base theme
    EditorView.baseTheme({
      '.ic-ce__locked': {
        backgroundColor: 'var(--ic-ce-locked)',
        opacity: '0.7',
      },
    }),
  ];
}
