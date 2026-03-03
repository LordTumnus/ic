import { EditorView, ViewPlugin, type ViewUpdate } from '@codemirror/view';
import type { Extension } from '@codemirror/state';

/**
 * Column rulers: vertical lines at specified column positions.
 *
 * Implemented as absolutely positioned pseudo-elements in a container
 * layer. Recomputes on font size changes (rare) but the CSS positions
 * are set via CSS custom properties based on character width.
 */
export function rulers(columns: number[]): Extension {
  if (columns.length === 0) return [];

  return [
    ViewPlugin.fromClass(
      class {
        private container: HTMLDivElement | null = null;

        constructor(view: EditorView) {
          this.buildRulers(view);
        }

        update(update: ViewUpdate) {
          if (update.geometryChanged) {
            this.buildRulers(update.view);
          }
        }

        destroy() {
          this.container?.remove();
        }

        private buildRulers(view: EditorView) {
          this.container?.remove();

          const charWidth = view.defaultCharacterWidth;
          const contentDom = view.contentDOM;
          const parent = contentDom.parentElement;
          if (!parent) return;

          this.container = document.createElement('div');
          this.container.className = 'ic-ce__rulers';
          this.container.style.position = 'absolute';
          this.container.style.top = '0';
          this.container.style.bottom = '0';
          this.container.style.left = '0';
          this.container.style.right = '0';
          this.container.style.pointerEvents = 'none';
          this.container.style.overflow = 'clip';

          const padding = view.contentDOM.getBoundingClientRect().left -
            view.scrollDOM.getBoundingClientRect().left;

          for (const col of columns) {
            const ruler = document.createElement('div');
            ruler.className = 'ic-ce__ruler';
            ruler.style.position = 'absolute';
            ruler.style.top = '0';
            ruler.style.bottom = '0';
            ruler.style.width = '1px';
            ruler.style.left = `${padding + col * charWidth}px`;
            this.container.appendChild(ruler);
          }

          parent.style.position = 'relative';
          parent.appendChild(this.container);
        }
      },
    ),
    EditorView.baseTheme({
      '.ic-ce__ruler': {
        backgroundColor: 'var(--ic-ce-ruler)',
      },
    }),
  ];
}
