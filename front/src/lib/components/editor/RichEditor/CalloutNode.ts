/**
 * CalloutNode — Custom TipTap node extension for callout/admonition blocks.
 *
 * Renders: <div class="ic-rte-callout ic-rte-callout--{type}">
 *   with type = info | warning | tip | danger
 *
 * Commands: setCallout({type}), toggleCallout(), removeCallout()
 */
import { Node, mergeAttributes } from '@tiptap/core';

export type CalloutType = 'info' | 'warning' | 'tip' | 'danger';

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    callout: {
      setCallout: (attrs: { type?: CalloutType }) => ReturnType;
      toggleCallout: (attrs?: { type?: CalloutType }) => ReturnType;
      removeCallout: () => ReturnType;
    };
  }
}

const CALLOUT_ICONS: Record<CalloutType, string> = {
  info: 'info',
  warning: 'alert-triangle',
  tip: 'lightbulb',
  danger: 'alert-octagon',
};

/** Map callout types to GitHub-style admonition keywords */
const CALLOUT_MD: Record<CalloutType, string> = {
  info: 'NOTE',
  warning: 'WARNING',
  tip: 'TIP',
  danger: 'CAUTION',
};

export const CalloutNode = Node.create({
  name: 'callout',
  group: 'block',
  content: 'block+',
  defining: true,

  addStorage() {
    return {
      markdown: {
        serialize(state: any, node: any) {
          const type = (node.attrs.type as CalloutType) || 'info';
          const keyword = CALLOUT_MD[type] || 'NOTE';
          state.write(`> [!${keyword}]\n`);
          state.wrapBlock('> ', null, node, () => state.renderContent(node));
          state.closeBlock(node);
        },
        parse: {},
      },
    };
  },

  addAttributes() {
    return {
      type: {
        default: 'info' as CalloutType,
        parseHTML: (el) => (el.getAttribute('data-callout-type') as CalloutType) || 'info',
        renderHTML: (attrs) => ({ 'data-callout-type': attrs.type }),
      },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-callout-type]' }];
  },

  renderHTML({ node, HTMLAttributes }) {
    const type = node.attrs.type as CalloutType;
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class: `ic-rte-callout ic-rte-callout--${type}`,
        'data-callout-type': type,
      }),
      ['div', { class: 'ic-rte-callout__icon', 'data-icon': CALLOUT_ICONS[type] || 'info' }, ''],
      ['div', { class: 'ic-rte-callout__content' }, 0],
    ];
  },

  addCommands() {
    return {
      setCallout:
        (attrs) =>
        ({ commands }) => {
          return commands.wrapIn(this.name, attrs);
        },
      toggleCallout:
        (attrs) =>
        ({ commands }) => {
          return commands.toggleWrap(this.name, attrs);
        },
      removeCallout:
        () =>
        ({ commands }) => {
          return commands.lift(this.name);
        },
    };
  },
});

export { CALLOUT_ICONS };
