/**
 * Slash command definitions + TipTap suggestion configuration.
 *
 * Type "/" on an empty line to trigger the command palette.
 * Each command: { title, icon, description, group, command(editor) }
 */
import type { Editor, Range } from '@tiptap/core';
import { Extension } from '@tiptap/core';
import Suggestion, { type SuggestionOptions } from '@tiptap/suggestion';

export interface SlashCommand {
  title: string;
  icon: string;
  description: string;
  group: string;
  command: (editor: Editor, range: Range) => void;
}

export const SLASH_COMMANDS: SlashCommand[] = [
  // ── Text ──────────────────────────────────────────
  {
    title: 'Paragraph',
    icon: 'pilcrow',
    description: 'Plain text block',
    group: 'Text',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setParagraph().run();
    },
  },
  {
    title: 'Heading 1',
    icon: 'heading-1',
    description: 'Large section heading',
    group: 'Text',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setHeading({ level: 1 }).run();
    },
  },
  {
    title: 'Heading 2',
    icon: 'heading-2',
    description: 'Medium section heading',
    group: 'Text',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setHeading({ level: 2 }).run();
    },
  },
  {
    title: 'Heading 3',
    icon: 'heading-3',
    description: 'Small section heading',
    group: 'Text',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setHeading({ level: 3 }).run();
    },
  },

  // ── Lists ─────────────────────────────────────────
  {
    title: 'Bullet List',
    icon: 'list',
    description: 'Unordered list',
    group: 'Lists',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).toggleBulletList().run();
    },
  },
  {
    title: 'Numbered List',
    icon: 'list-ordered',
    description: 'Ordered list',
    group: 'Lists',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).toggleOrderedList().run();
    },
  },
  {
    title: 'Task List',
    icon: 'list-checks',
    description: 'Checklist with checkboxes',
    group: 'Lists',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).toggleTaskList().run();
    },
  },

  // ── Blocks ────────────────────────────────────────
  {
    title: 'Blockquote',
    icon: 'quote',
    description: 'Quoted text block',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).toggleBlockquote().run();
    },
  },
  {
    title: 'Code Block',
    icon: 'code-2',
    description: 'Syntax-highlighted code',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).toggleCodeBlock().run();
    },
  },
  {
    title: 'Callout: Info',
    icon: 'info',
    description: 'Informational note',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setCallout({ type: 'info' }).run();
    },
  },
  {
    title: 'Callout: Warning',
    icon: 'alert-triangle',
    description: 'Warning notice',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setCallout({ type: 'warning' }).run();
    },
  },
  {
    title: 'Callout: Tip',
    icon: 'lightbulb',
    description: 'Helpful tip',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setCallout({ type: 'tip' }).run();
    },
  },
  {
    title: 'Callout: Danger',
    icon: 'alert-octagon',
    description: 'Danger or error alert',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setCallout({ type: 'danger' }).run();
    },
  },
  {
    title: 'Collapsible',
    icon: 'chevrons-down-up',
    description: 'Expandable section',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setDetails().run();
    },
  },
  {
    title: 'Horizontal Rule',
    icon: 'minus',
    description: 'Divider line',
    group: 'Blocks',
    command: (editor, range) => {
      editor.chain().focus().deleteRange(range).setHorizontalRule().run();
    },
  },

  // ── Insert ────────────────────────────────────────
  {
    title: 'Table',
    icon: 'table',
    description: '3x3 table',
    group: 'Insert',
    command: (editor, range) => {
      editor
        .chain()
        .focus()
        .deleteRange(range)
        .insertTable({ rows: 3, cols: 3, withHeaderRow: true })
        .run();
    },
  },
  {
    title: 'Math Block',
    icon: 'sigma',
    description: 'LaTeX math expression',
    group: 'Insert',
    command: (editor, range) => {
      editor
        .chain()
        .focus()
        .deleteRange(range)
        .insertContent({
          type: 'inlineMath',
          attrs: { latex: '\\dot{x} = Ax + Bu', display: 'yes', evaluate: 'no' },
        })
        .run();
    },
  },
];

/**
 * Filter slash commands by query string.
 */
export function filterCommands(query: string): SlashCommand[] {
  if (!query) return SLASH_COMMANDS;
  const lower = query.toLowerCase();
  return SLASH_COMMANDS.filter(
    (cmd) =>
      cmd.title.toLowerCase().includes(lower) ||
      cmd.description.toLowerCase().includes(lower) ||
      cmd.group.toLowerCase().includes(lower),
  );
}

/**
 * Group commands by their group property.
 */
export function groupCommands(commands: SlashCommand[]): Map<string, SlashCommand[]> {
  const groups = new Map<string, SlashCommand[]>();
  for (const cmd of commands) {
    const list = groups.get(cmd.group) || [];
    list.push(cmd);
    groups.set(cmd.group, list);
  }
  return groups;
}

/**
 * TipTap extension wrapping @tiptap/suggestion for "/" trigger.
 */
export const SlashCommands = Extension.create({
  name: 'slashCommands',

  addOptions() {
    return {
      suggestion: {
        char: '/',
        startOfLine: false,
        command: ({
          editor,
          range,
          props,
        }: {
          editor: Editor;
          range: Range;
          props: SlashCommand;
        }) => {
          props.command(editor, range);
        },
        items: ({ query }: { query: string }) => filterCommands(query),
      } as Partial<SuggestionOptions>,
    };
  },

  addProseMirrorPlugins() {
    return [
      Suggestion({
        editor: this.editor,
        ...this.options.suggestion,
      }),
    ];
  },
});
