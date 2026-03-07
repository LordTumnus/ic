/**
 * CodeBlockLangSelector — ProseMirror decoration plugin
 *
 * Adds a small <select> language picker in the top-right corner of every
 * code block. When the user picks a language, it dispatches a transaction
 * that updates the node's `language` attribute, which CodeBlockLowlight
 * picks up and re-highlights automatically.
 *
 * Uses widget decorations so it layers on top of the existing NodeView
 * without replacing it.
 */
import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';
import type { EditorState } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';

const LANGUAGES: [value: string, label: string][] = [
  ['', 'auto'],
  ['bash', 'Bash'],
  ['c', 'C'],
  ['cpp', 'C++'],
  ['csharp', 'C#'],
  ['css', 'CSS'],
  ['go', 'Go'],
  ['html', 'HTML'],
  ['java', 'Java'],
  ['javascript', 'JavaScript'],
  ['json', 'JSON'],
  ['latex', 'LaTeX'],
  ['markdown', 'Markdown'],
  ['matlab', 'MATLAB'],
  ['php', 'PHP'],
  ['python', 'Python'],
  ['ruby', 'Ruby'],
  ['rust', 'Rust'],
  ['sql', 'SQL'],
  ['typescript', 'TypeScript'],
  ['xml', 'XML'],
  ['yaml', 'YAML'],
];

const pluginKey = new PluginKey('codeBlockLangSelector');

function buildDecorations(state: EditorState): DecorationSet {
  const decorations: Decoration[] = [];

  state.doc.descendants((node, pos) => {
    if (node.type.name !== 'codeBlock') return;

    const lang = (node.attrs.language as string) || '';

    const widget = Decoration.widget(
      pos + 1, // inside the code block content (<code>)
      (view: EditorView, getPos: () => number | undefined) => {
        const select = document.createElement('select');
        select.className = 'ic-rte-codeblock-lang';
        select.contentEditable = 'false';

        for (const [value, label] of LANGUAGES) {
          const opt = document.createElement('option');
          opt.value = value;
          opt.textContent = label;
          if (value === lang) opt.selected = true;
          select.appendChild(opt);
        }

        select.addEventListener('change', () => {
          if (!view.editable) return;
          const widgetPos = getPos();
          if (widgetPos == null) return;
          const cbPos = widgetPos - 1;
          const cbNode = view.state.doc.nodeAt(cbPos);
          if (!cbNode || cbNode.type.name !== 'codeBlock') return;

          view.dispatch(
            view.state.tr.setNodeMarkup(cbPos, undefined, {
              ...cbNode.attrs,
              language: select.value || null,
            }),
          );
        });

        // Prevent editor focus steal and cursor repositioning
        select.addEventListener('mousedown', (e) => e.stopPropagation());

        return select;
      },
      { key: `cblang-${pos}`, side: -1, ignoreSelection: true },
    );

    decorations.push(widget);
  });

  return DecorationSet.create(state.doc, decorations);
}

export const CodeBlockLanguageSelector = Extension.create({
  name: 'codeBlockLanguageSelector',

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: pluginKey,
        props: {
          decorations(state) {
            return buildDecorations(state);
          },
        },
      }),
    ];
  },
});
