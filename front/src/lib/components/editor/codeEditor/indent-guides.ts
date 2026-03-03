import {
  Decoration,
  ViewPlugin,
  type DecorationSet,
  type ViewUpdate,
} from '@codemirror/view';
import { syntaxTree } from '@codemirror/language';
import type { EditorState, Extension, Range } from '@codemirror/state';

/**
 * Scope-based indent guides: vertical lines connecting each MATLAB
 * block keyword to its matching `end`.
 *
 * Draws guides via CSS `background-image` on `.cm-line` elements.
 * Each guide is a 1px-wide linear-gradient positioned at the block
 * keyword's indent column using `ch` units — no widgets, no absolute
 * positioning, no font mismatch issues.
 */

/** All MATLAB grammar nodes that form keyword…end blocks. */
const BLOCK_TYPES = new Set([
  'ClassDefinition',
  'PropertiesBlock',
  'MethodsBlock',
  'EventsBlock',
  'EnumerationBlock',
  'FunctionDeclaration',
  'ArgumentsBlock',
  'IfStatement',
  'ForStatement',
  'ParforStatement',
  'WhileStatement',
  'SwitchStatement',
  'TryCatchStatement',
  'SpmdStatement',
]);

interface BlockScope {
  fromLine: number;
  toLine: number;
  column: number;
}

const GRAD = 'linear-gradient(var(--ic-ce-indent-guide),var(--ic-ce-indent-guide))';

// ─── Scope collection ─────────────────────────────────

function collectScopes(
  state: EditorState,
  tabSize: number,
): BlockScope[] {
  const scopes: BlockScope[] = [];
  const tree = syntaxTree(state);

  tree.iterate({
    enter(node) {
      if (!BLOCK_TYPES.has(node.name)) return;

      const startLine = state.doc.lineAt(node.from);
      const endLine = state.doc.lineAt(node.to);
      if (startLine.number >= endLine.number) return;

      const text = startLine.text;
      let indent = 0;
      for (let i = 0; i < text.length; i++) {
        if (text[i] === ' ') indent++;
        else if (text[i] === '\t') indent += tabSize - (indent % tabSize);
        else break;
      }

      scopes.push({
        fromLine: startLine.number + 1,
        toLine: endLine.number,
        column: indent,
      });
    },
  });

  return scopes;
}

// ─── Line decoration cache ────────────────────────────
// Avoid allocating duplicate Decoration objects for identical guide patterns.

const decoCache = new Map<string, Decoration>();

function getLineDeco(columns: number[]): Decoration {
  const key = columns.join(',');
  let deco = decoCache.get(key);
  if (deco) return deco;

  const n = columns.length;
  const img = Array(n).fill(GRAD).join(',');
  const size = Array(n).fill('1px 100%').join(',');
  const pos = columns.map((c) => `${c}ch 0`).join(',');
  const rep = Array(n).fill('no-repeat').join(',');

  deco = Decoration.line({
    attributes: {
      style: [
        `background-image:${img}`,
        `background-size:${size}`,
        `background-position:${pos}`,
        `background-repeat:${rep}`,
      ].join(';'),
    },
  });

  decoCache.set(key, deco);
  return deco;
}

// ─── Decorations ──────────────────────────────────────

function guidesDeco(
  view: import('@codemirror/view').EditorView,
  tabSize: number,
): DecorationSet {
  const scopes = collectScopes(view.state, tabSize);
  if (scopes.length === 0) return Decoration.set([]);

  const ranges: Range<Decoration>[] = [];

  for (const { from, to } of view.visibleRanges) {
    for (let pos = from; pos <= to; ) {
      const line = view.state.doc.lineAt(pos);
      const ln = line.number;

      const columns: number[] = [];
      for (const scope of scopes) {
        if (ln >= scope.fromLine && ln <= scope.toLine) {
          columns.push(scope.column);
        }
      }

      if (columns.length > 0) {
        const unique = [...new Set(columns)].sort((a, b) => a - b);
        ranges.push(getLineDeco(unique).range(line.from));
      }

      pos = line.to + 1;
    }
  }

  return Decoration.set(ranges);
}

// ─── Extension ────────────────────────────────────────

export function indentGuides(tabSize: number = 4): Extension {
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;
      private lastTree: unknown;
      constructor(view: import('@codemirror/view').EditorView) {
        this.lastTree = syntaxTree(view.state);
        this.decorations = guidesDeco(view, tabSize);
      }
      update(update: ViewUpdate) {
        const newTree = syntaxTree(update.state);
        if (
          update.docChanged ||
          update.viewportChanged ||
          newTree !== this.lastTree
        ) {
          this.lastTree = newTree;
          this.decorations = guidesDeco(update.view, tabSize);
        }
      }
    },
    { decorations: (v) => v.decorations },
  );
}
