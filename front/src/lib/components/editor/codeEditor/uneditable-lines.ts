import {
  Decoration,
  EditorView,
  ViewPlugin,
  type DecorationSet,
  type ViewUpdate,
} from '@codemirror/view';
import {
  Annotation,
  EditorState,
  Facet,
  StateField,
  type Extension,
  type Range,
} from '@codemirror/state';

/** Annotation to mark programmatic value updates — bypasses the lock filter. */
export const programmatic = Annotation.define<boolean>();

/**
 * Uneditable (sticky) lines: locks specific lines from user editing.
 *
 * Line numbers are "sticky" — when the user inserts or deletes lines
 * elsewhere in the document, locked lines shift to follow their content.
 *
 * Implementation:
 *   - A Facet provides the initial 1-based line numbers (from the compartment).
 *   - A StateField converts them to document positions and maps those
 *     positions through every document change via `ChangeDesc.mapPos()`.
 *   - A transaction filter rejects changes touching locked lines.
 *   - A ViewPlugin renders the dimmed-background decoration.
 */

const lockedLine = Decoration.line({ class: 'ic-ce__locked' });

/** Facet carrying the initial 1-based line numbers from the compartment. */
const lockedLinesFacet = Facet.define<number[], number[]>({
  combine: (inputs) => inputs.flat(),
});

/** Convert 1-based line numbers → document positions (line start offsets). */
function linesToPositions(state: EditorState, lines: number[]): number[] {
  const total = state.doc.lines;
  const positions: number[] = [];
  for (const ln of lines) {
    if (ln >= 1 && ln <= total) {
      positions.push(state.doc.line(ln).from);
    }
  }
  return positions;
}

/**
 * StateField that tracks locked positions.
 *
 * - On facet change (compartment reconfigured): recompute from line numbers.
 * - On doc change: map existing positions through the changes.
 */
const lockedPositionsField = StateField.define<number[]>({
  create(state) {
    return linesToPositions(state, state.facet(lockedLinesFacet));
  },
  update(positions, tr) {
    // Facet changed (compartment reconfigured) → reset from new line numbers
    const oldLines = tr.startState.facet(lockedLinesFacet);
    const newLines = tr.state.facet(lockedLinesFacet);
    if (oldLines !== newLines) {
      return linesToPositions(tr.state, newLines);
    }
    // Document changed → map positions (assoc=1: stick to the right)
    if (tr.docChanged) {
      return positions.map((pos) => tr.changes.mapPos(pos, 1));
    }
    return positions;
  },
});

/** Derive the set of currently-locked line numbers from tracked positions. */
function getLockedLines(state: EditorState): Set<number> {
  const positions = state.field(lockedPositionsField);
  const lines = new Set<number>();
  for (const pos of positions) {
    if (pos <= state.doc.length) {
      lines.add(state.doc.lineAt(pos).number);
    }
  }
  return lines;
}

export function uneditableLines(lineNumbers: number[]): Extension {
  return [
    lockedLinesFacet.of(lineNumbers),
    lockedPositionsField,

    // Visual decoration
    ViewPlugin.fromClass(
      class {
        decorations: DecorationSet;
        constructor(view: EditorView) {
          this.decorations = this.buildDeco(view.state);
        }
        update(update: ViewUpdate) {
          const changed =
            update.startState.field(lockedPositionsField) !==
            update.state.field(lockedPositionsField);
          if (update.docChanged || changed) {
            this.decorations = this.buildDeco(update.state);
          }
        }
        buildDeco(state: EditorState): DecorationSet {
          const positions = state.field(lockedPositionsField);
          const ranges: Range<Decoration>[] = [];
          for (const pos of positions) {
            if (pos <= state.doc.length) {
              ranges.push(lockedLine.range(state.doc.lineAt(pos).from));
            }
          }
          ranges.sort((a, b) => a.from - b.from);
          return Decoration.set(ranges);
        }
      },
      { decorations: (v) => v.decorations },
    ),

    // Transaction filter: reject user edits on locked lines (programmatic updates pass through)
    EditorState.transactionFilter.of((tr) => {
      if (!tr.docChanged || tr.annotation(programmatic)) return tr;
      const locked = getLockedLines(tr.startState);
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
