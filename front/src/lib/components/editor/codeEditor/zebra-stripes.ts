import {
  Decoration,
  ViewPlugin,
  EditorView,
  type DecorationSet,
  type ViewUpdate,
} from '@codemirror/view';
import type { Extension, Range } from '@codemirror/state';

/**
 * Zebra stripes: alternating background on every Nth line.
 *
 * Uses a ViewPlugin to compute line decorations within the visible
 * viewport. Recomputes on doc changes and viewport scrolls.
 */
const stripe = Decoration.line({ class: 'ic-ce__stripe' });

function stripeDeco(view: EditorView, step: number): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  for (const { from, to } of view.visibleRanges) {
    for (let pos = from; pos <= to; ) {
      const line = view.state.doc.lineAt(pos);
      if ((line.number - 1) % step === 0) {
        ranges.push(stripe.range(line.from));
      }
      pos = line.to + 1;
    }
  }
  return Decoration.set(ranges);
}

export function zebraStripes(step: number = 2): Extension {
  return [
    ViewPlugin.fromClass(
      class {
        decorations: DecorationSet;
        constructor(view: EditorView) {
          this.decorations = stripeDeco(view, step);
        }
        update(update: ViewUpdate) {
          if (update.docChanged || update.viewportChanged) {
            this.decorations = stripeDeco(update.view, step);
          }
        }
      },
      { decorations: (v) => v.decorations },
    ),
    EditorView.baseTheme({
      '.ic-ce__stripe': {
        backgroundColor: 'var(--ic-ce-stripe)',
      },
    }),
  ];
}
