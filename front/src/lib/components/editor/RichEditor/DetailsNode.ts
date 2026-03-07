/**
 * DetailsNode — Custom TipTap node extension for collapsible sections.
 *
 * Two nodes:
 *   - details (wrapper): <details class="ic-rte-details">
 *   - detailsSummary (title): <summary>
 *   - detailsContent (body): <div class="ic-rte-details__content">
 *
 * Commands: setDetails(), toggleDetails(), removeDetails()
 */
import { Node, mergeAttributes } from '@tiptap/core';

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    details: {
      setDetails: () => ReturnType;
      removeDetails: () => ReturnType;
    };
  }
}

export const DetailsSummary = Node.create({
  name: 'detailsSummary',
  group: '',
  content: 'inline*',
  defining: true,

  addStorage() {
    return {
      markdown: {
        serialize(state: any, node: any) {
          state.write('<summary>');
          state.renderInline(node);
          state.write('</summary>\n\n');
        },
        parse: {},
      },
    };
  },

  parseHTML() {
    return [
      { tag: 'summary' },
      { tag: 'div[data-details-summary]' },
    ];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class: 'ic-rte-details__summary',
        'data-details-summary': '',
      }),
      0,
    ];
  },
});

export const DetailsContent = Node.create({
  name: 'detailsContent',
  group: '',
  content: 'block+',
  defining: true,

  addStorage() {
    return {
      markdown: {
        serialize(state: any, node: any) {
          state.renderContent(node);
        },
        parse: {},
      },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-details-content]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class: 'ic-rte-details__content',
        'data-details-content': '',
      }),
      0,
    ];
  },
});

export const DetailsNode = Node.create({
  name: 'details',
  group: 'block',
  content: 'detailsSummary detailsContent',
  defining: true,

  addStorage() {
    return {
      markdown: {
        serialize(state: any, node: any) {
          state.write('<details>\n');
          state.renderContent(node);
          state.write('</details>');
          state.closeBlock(node);
        },
        parse: {},
      },
    };
  },

  addAttributes() {
    return {
      open: {
        default: true,
        parseHTML: (el) => el.hasAttribute('open'),
        renderHTML: (attrs) => (attrs.open ? { open: '' } : {}),
      },
    };
  },

  parseHTML() {
    return [{ tag: 'details' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['details', mergeAttributes(HTMLAttributes, { class: 'ic-rte-details' }), 0];
  },

  addCommands() {
    return {
      setDetails:
        () =>
        ({ chain }) => {
          return chain()
            .insertContent({
              type: this.name,
              attrs: { open: true },
              content: [
                { type: 'detailsSummary' },
                {
                  type: 'detailsContent',
                  content: [{ type: 'paragraph' }],
                },
              ],
            })
            .focus()
            .run();
        },
      removeDetails:
        () =>
        ({ commands }) => {
          return commands.lift(this.name);
        },
    };
  },

  // Custom NodeView: native <details> toggle is broken inside contentEditable,
  // so we use <div> wrappers + a toggle button instead.
  addNodeView() {
    return ({ node, getPos, editor }) => {
      let isOpen = !!node.attrs.open;

      const dom = document.createElement('div');
      dom.classList.add('ic-rte-details');
      if (isOpen) dom.classList.add('ic-rte-details--open');

      // Toggle button (non-editable) — sits in top-left corner
      const toggle = document.createElement('button');
      toggle.className = 'ic-rte-details__toggle';
      toggle.type = 'button';
      toggle.contentEditable = 'false';
      toggle.addEventListener('mousedown', (e) => e.preventDefault());
      toggle.addEventListener('click', () => {
        if (typeof getPos === 'function') {
          const pos = getPos();
          if (pos == null) return;
          editor.commands.command(({ tr }) => {
            tr.setNodeMarkup(pos, undefined, {
              ...node.attrs,
              open: !isOpen,
            });
            return true;
          });
        }
      });
      dom.appendChild(toggle);

      // Content wrapper — ProseMirror renders detailsSummary + detailsContent here
      const contentDOM = document.createElement('div');
      contentDOM.classList.add('ic-rte-details__body');
      dom.appendChild(contentDOM);

      return {
        dom,
        contentDOM,
        update(updatedNode) {
          if (updatedNode.type.name !== 'details') return false;
          isOpen = !!updatedNode.attrs.open;
          dom.classList.toggle('ic-rte-details--open', isOpen);
          return true;
        },
      };
    };
  },
});
