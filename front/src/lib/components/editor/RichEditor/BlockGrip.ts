/**
 * BlockGrip — ProseMirror plugin for block grip handles + context menu.
 *
 * On mousemove: finds top-level block under cursor, adds a decoration
 * with a 6-dot grip widget on the left edge.
 *
 * On click: dispatches a custom event for the Svelte GripMenu component
 * to position and display the context menu.
 */
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';
import type { EditorView } from '@tiptap/pm/view';
import type { ResolvedPos } from '@tiptap/pm/model';

export interface GripMenuEvent {
  pos: number;
  nodeSize: number;
  top: number;
  left: number;
  nodeType: string;
}

const GRIP_PLUGIN_KEY = new PluginKey('blockGrip');

/** Create the 6-dot grip SVG icon */
function createGripDot(): HTMLButtonElement {
  const btn = document.createElement('button');
  btn.className = 'ic-rte-grip';
  btn.contentEditable = 'false';
  btn.type = 'button';
  btn.setAttribute('aria-label', 'Block menu');
  btn.innerHTML = `<svg width="10" height="14" viewBox="0 0 10 14" fill="currentColor">
    <circle cx="3" cy="2" r="1.2"/><circle cx="7" cy="2" r="1.2"/>
    <circle cx="3" cy="7" r="1.2"/><circle cx="7" cy="7" r="1.2"/>
    <circle cx="3" cy="12" r="1.2"/><circle cx="7" cy="12" r="1.2"/>
  </svg>`;
  return btn;
}

/**
 * Creates the BlockGrip ProseMirror plugin.
 *
 * @param onGripClick - callback when grip is clicked, receives position info
 */
export function createBlockGripPlugin(onGripClick: (event: GripMenuEvent) => void): Plugin {
  let hoveredPos: number | null = null;

  return new Plugin({
    key: GRIP_PLUGIN_KEY,

    props: {
      handleDOMEvents: {
        mousemove(view: EditorView, event: MouseEvent) {
          const editorRect = view.dom.getBoundingClientRect();
          // Only show grip when mouse is in the left gutter area (first 40px)
          const relX = event.clientX - editorRect.left;
          if (relX > 48) {
            if (hoveredPos !== null) {
              hoveredPos = null;
              // Force decoration update
              view.dispatch(view.state.tr.setMeta(GRIP_PLUGIN_KEY, { hoveredPos: null }));
            }
            return false;
          }

          const pos = view.posAtCoords({ left: event.clientX + 40, top: event.clientY });
          if (!pos) return false;

          // Find top-level block
          const $pos = view.state.doc.resolve(pos.pos);
          const topPos = getTopLevelBlockPos($pos);
          if (topPos !== hoveredPos) {
            hoveredPos = topPos;
            view.dispatch(view.state.tr.setMeta(GRIP_PLUGIN_KEY, { hoveredPos: topPos }));
          }
          return false;
        },

        mouseleave(view: EditorView) {
          if (hoveredPos !== null) {
            hoveredPos = null;
            view.dispatch(view.state.tr.setMeta(GRIP_PLUGIN_KEY, { hoveredPos: null }));
          }
          return false;
        },
      },
    },

    state: {
      init() {
        return DecorationSet.empty;
      },
      apply(tr, oldSet, _oldState, newState) {
        const meta = tr.getMeta(GRIP_PLUGIN_KEY);
        if (!meta) return oldSet.map(tr.mapping, tr.doc);

        const hp = meta.hoveredPos as number | null;
        if (hp === null) return DecorationSet.empty;

        // Create grip widget at the start of the hovered block
        const node = newState.doc.nodeAt(hp);
        if (!node) return DecorationSet.empty;

        const gripWidget = Decoration.widget(hp, (view) => {
          const grip = createGripDot();
          grip.addEventListener('mousedown', (e) => {
            e.preventDefault();
            e.stopPropagation();

            const blockNode = view.state.doc.nodeAt(hp);
            if (!blockNode) return;

            // Get position for context menu
            const coords = view.coordsAtPos(hp);
            onGripClick({
              pos: hp,
              nodeSize: blockNode.nodeSize,
              top: coords.top,
              left: coords.left,
              nodeType: blockNode.type.name,
            });
          });
          return grip;
        }, { side: -1, key: `grip-${hp}` });

        return DecorationSet.create(newState.doc, [gripWidget]);
      },
    },
  });
}

/** Get the position of the top-level block containing the resolved position */
function getTopLevelBlockPos($pos: ResolvedPos): number | null {
  // Walk up to depth 1 (direct child of doc)
  if ($pos.depth === 0) return null;
  // Find the start position of the top-level block
  return $pos.start(1) - 1;
}
