<script lang="ts">
  import { untrack } from 'svelte';
  import { Editor, InputRule } from '@tiptap/core';
  import { StarterKit } from '@tiptap/starter-kit';
  import { Underline } from '@tiptap/extension-underline';
  import { Link } from '@tiptap/extension-link';
  import { Image } from '@tiptap/extension-image';
  import { Table, TableRow, TableCell, TableHeader } from '@tiptap/extension-table';
  import { TaskList } from '@tiptap/extension-task-list';
  import { TaskItem } from '@tiptap/extension-task-item';
  import { TextAlign } from '@tiptap/extension-text-align';
  import { Placeholder } from '@tiptap/extension-placeholder';
  import { CharacterCount } from '@tiptap/extension-character-count';
  import { Highlight } from '@tiptap/extension-highlight';
  import { Subscript } from '@tiptap/extension-subscript';
  import { Superscript } from '@tiptap/extension-superscript';
  import { Color } from '@tiptap/extension-color';
  import { TextStyle } from '@tiptap/extension-text-style';
  import { Typography } from '@tiptap/extension-typography';
  import { BubbleMenu } from '@tiptap/extension-bubble-menu';
  import { Focus } from '@tiptap/extension-focus';
  import { FontFamily } from '@tiptap/extension-font-family';
  import { CodeBlockLowlight } from '@tiptap/extension-code-block-lowlight';
  import { Markdown } from 'tiptap-markdown';
  import MathExtension, { InlineMathNode } from '@aarkue/tiptap-math-extension';
  import katex from 'katex';
  import 'katex/dist/katex.min.css';
  import type { Resolution, RequestFn } from '$lib/types';
  import { resolveAssetAsDataUri, type AssetData } from '$lib/utils/asset-cache';
  import type { CssSize } from '$lib/utils/css';
  import { toSize } from '$lib/utils/css';
  import logger from '$lib/core/logger';
  import { htmlToPdfBase64 } from '$lib/utils/html2pdf';

  import { CalloutNode } from './CalloutNode';
  import { DetailsNode, DetailsSummary, DetailsContent } from './DetailsNode';
  import { SlashCommands, filterCommands } from './slash-commands';
  import { createBlockGripPlugin, type GripMenuEvent } from './BlockGrip';
  import { TableControls } from './TableControls';
  import { CodeBlockLanguageSelector } from './CodeBlockLangSelector';

  import Toolbar from './Toolbar.svelte';
  import BubbleToolbar from './BubbleToolbar.svelte';
  import SlashMenu from './SlashMenu.svelte';
  import TOCSidebar from './TOCSidebar.svelte';
  import ImageDialog from './ImageDialog.svelte';
  import LinkDialog from './LinkDialog.svelte';
  import LinkPreview from './LinkPreview.svelte';
  import ColorPicker from './ColorPicker.svelte';
  import TableGridPicker from './TableGridPicker.svelte';
  import GripMenu from './GripMenu.svelte';

  // Import editor theme CSS
  import './editor-theme.css';

  // ─── Props ───────────────────────────────────────────
  let {
    // Data props
    value = $bindable(''),
    height = $bindable<CssSize>('100%'),
    readOnly = $bindable(false),
    placeholder: placeholderText = $bindable(''),
    disabled = $bindable(false),
    showToolbar = $bindable(true),
    showToc = $bindable(true),
    focusMode = $bindable(false),
    maxLength = $bindable<number | null>(null),

    // Read-only props (frontend → MATLAB)
    wordCount = $bindable(0),
    characterCount = $bindable(0),
    isFocused = $bindable(false),

    // Events
    valueChanged,
    focusChanged,
    submitted,

    // Methods
    focus: focusFn = $bindable((): Resolution => ({ success: true, data: null })),
    blur: blurFn = $bindable((): Resolution => ({ success: true, data: null })),
    clear: clearFn = $bindable((): Resolution => ({ success: true, data: null })),
    insertContent: insertContentFn = $bindable(
      (_html: string): Resolution => ({ success: true, data: null }),
    ),
    getMarkdown: getMarkdownFn = $bindable((): Resolution => ({ success: true, data: '' })),
    exportPdf: exportPdfFn = $bindable(
      (_filepath: string): Resolution => ({ success: true, data: null }),
    ),

    // Request function (for MATLAB-side image fetching)
    request,
  }: {
    value?: string;
    height?: CssSize;
    readOnly?: boolean;
    placeholder?: string;
    disabled?: boolean;
    showToolbar?: boolean;
    showToc?: boolean;
    focusMode?: boolean;
    maxLength?: number | null;
    wordCount?: number;
    characterCount?: number;
    isFocused?: boolean;
    valueChanged?: (data?: unknown) => void;
    focusChanged?: (data?: unknown) => void;
    submitted?: (data?: unknown) => void;
    focus?: () => Resolution;
    blur?: () => Resolution;
    clear?: () => Resolution;
    insertContent?: (html: string) => Resolution;
    getMarkdown?: () => Resolution;
    exportPdf?: (filepath: string) => Resolution;
    request?: RequestFn;
  } = $props();

  // ─── Internal state ──────────────────────────────────
  let containerEl: HTMLDivElement;
  let editorEl: HTMLDivElement;
  let bubbleMenuEl: HTMLDivElement;
  let editor: Editor | null = $state(null);
  let updatingFromProp = false;

  // Debounce timer for valueChanged
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;

  // Slash menu state
  let slashMenuEl: HTMLDivElement;
  let slashMenuVisible = $state(false);
  let slashMenuItems = $state<import('./slash-commands').SlashCommand[]>([]);
  let slashMenuComponent = $state<SlashMenu | null>(null);
  let slashCommandFn: ((props: { command: (item: import('./slash-commands').SlashCommand) => void }) => void) | null = null;

  // Dialog state
  let imageDialogVisible = $state(false);
  let imageDialogX = $state(0);
  let imageDialogY = $state(0);
  let linkDialogVisible = $state(false);
  let linkDialogX = $state(0);
  let linkDialogY = $state(0);
  let colorPickerVisible = $state(false);
  let colorPickerX = $state(0);
  let colorPickerY = $state(0);
  let tablePickerVisible = $state(false);
  let tablePickerX = $state(0);
  let tablePickerY = $state(0);

  // Grip menu state
  let gripMenuVisible = $state(false);
  let gripMenuEvent = $state<GripMenuEvent | null>(null);

  // TOC component ref
  let tocComponent = $state<TOCSidebar | null>(null);

  // ── Computed ──────────────────────────────────────────
  const readingTime = $derived(Math.max(1, Math.ceil(wordCount / 200)));
  const hasTextSelection = $derived.by(() => {
    void txCount; // re-evaluate on transactions
    if (!editor) return false;
    const { from, to } = editor.state.selection;
    return from !== to;
  });
  const selectedWordCount = $derived.by(() => {
    if (!hasTextSelection || !editor) return 0;
    const { from, to } = editor.state.selection;
    const text = editor.state.doc.textBetween(from, to, ' ');
    return text.split(/\s+/).filter(Boolean).length;
  });

  // ── Lowlight setup (reuse existing highlight.js) ────
  let lowlightInstance: unknown = null;

  async function getLowlight() {
    if (lowlightInstance) return lowlightInstance;
    const { createLowlight, common } = await import('lowlight');
    lowlightInstance = createLowlight(common);
    return lowlightInstance;
  }

  // ─── Editor mount ────────────────────────────────────
  $effect(() => {
    const el = editorEl;
    if (!el) return;

    return untrack(() => {
      // Build lowlight then mount editor
      getLowlight().then((lowlight) => {
        const editorInstance = new Editor({
          element: el,
          content: value || '',
          editable: !readOnly && !disabled,

          extensions: [
            StarterKit.configure({
              codeBlock: false, // Replaced by CodeBlockLowlight
              dropcursor: false, // MATLAB blocks drag events
            }),
            Underline,
            Link.extend({
              addInputRules() {
                // Markdown link: [text](url)
                return [
                  new InputRule({
                    find: /\[([^\]]+)\]\(([^)]+)\)\s$/,
                    handler: ({ state, range, match }) => {
                      const [, text, url] = match;
                      const { tr } = state;
                      const start = range.from;
                      const end = range.to;
                      tr.delete(start, end);
                      const linkMark = state.schema.marks.link.create({ href: url });
                      tr.insert(start, state.schema.text(text, [linkMark]));
                    },
                  }),
                ];
              },
            }).configure({
              openOnClick: false,
              autolink: true,
              HTMLAttributes: { rel: 'noopener noreferrer nofollow' },
            }),
            Image.configure({
              allowBase64: true,
            }),
            Table.configure({ resizable: true }),
            TableRow,
            TableCell,
            TableHeader,
            TableControls,
            TaskList,
            TaskItem.configure({ nested: true }),
            TextAlign.configure({
              types: ['heading', 'paragraph'],
            }),
            Placeholder.configure({
              placeholder: placeholderText,
            }),
            CharacterCount.configure({
              limit: maxLength,
            }),
            Highlight.configure({ multicolor: true }),
            Subscript,
            Superscript,
            Color,
            TextStyle,
            Typography,
            BubbleMenu.configure({
              element: bubbleMenuEl,
            }),
            Focus.configure({ className: 'has-focus', mode: 'shallowest' }),
            FontFamily,
            CodeBlockLowlight.configure({ lowlight: lowlight as any }),
            CodeBlockLanguageSelector,
            Markdown.configure({
              html: true,
              transformPastedText: false,
              transformCopiedText: false,
            }),
            MathExtension.configure({
              evaluation: false,
              delimiters: 'dollar',
              addInlineMath: false, // We register our extended version below
            }),
            InlineMathNode.extend({
              addStorage() {
                return {
                  ...this.parent?.(),
                  markdown: {
                    serialize(state: any, node: any) {
                      const latex = node.attrs.latex || '';
                      if (node.attrs.display === 'yes') {
                        state.write(`$$${latex}$$`);
                        state.closeBlock(node);
                      } else {
                        state.write(`$${latex}$`);
                      }
                    },
                    parse: {},
                  },
                };
              },
              addNodeView() {
                return ({ node, getPos, editor, HTMLAttributes }) => {
                  const katexLib = katex;
                  const outerSpan = document.createElement('span');
                  outerSpan.classList.add('tiptap-math', 'latex');

                  // KaTeX render target
                  const mathSpan = document.createElement('span');
                  outerSpan.appendChild(mathSpan);

                  // Inline LaTeX editor (hidden by default)
                  const inputEl = document.createElement('input');
                  inputEl.type = 'text';
                  inputEl.className = 'ic-rte-math-input';
                  inputEl.spellcheck = false;
                  inputEl.style.display = 'none';
                  outerSpan.appendChild(inputEl);

                  let isEditing = false;
                  let currentLatex = node.attrs.latex || '';
                  let displayMode = node.attrs.display === 'yes';

                  function renderKatex() {
                    try {
                      katexLib.render(currentLatex || '\\text{empty}', mathSpan, {
                        displayMode,
                        throwOnError: false,
                      });
                    } catch {
                      mathSpan.textContent = currentLatex;
                    }
                  }

                  function openEditor() {
                    if (isEditing || !editor.isEditable) return;
                    isEditing = true;
                    inputEl.value = currentLatex;
                    mathSpan.style.display = 'none';
                    inputEl.style.display = '';
                    inputEl.focus();
                    inputEl.select();
                  }

                  function closeEditor(apply: boolean) {
                    if (!isEditing) return;
                    isEditing = false;
                    inputEl.style.display = 'none';
                    mathSpan.style.display = '';
                    if (apply && typeof getPos === 'function') {
                      const newLatex = inputEl.value.trim() || 'x';
                      if (newLatex !== currentLatex) {
                        const pos = getPos();
                        if (pos != null) {
                          editor.commands.command(({ tr }) => {
                            tr.setNodeMarkup(pos, undefined, {
                              ...node.attrs,
                              latex: newLatex,
                            });
                            return true;
                          });
                        }
                      }
                    }
                    editor.commands.focus();
                  }

                  renderKatex();

                  // Double-click to edit
                  outerSpan.addEventListener('dblclick', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    openEditor();
                  });

                  // Enter to apply, Escape to cancel
                  inputEl.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      closeEditor(true);
                    } else if (e.key === 'Escape') {
                      e.preventDefault();
                      closeEditor(false);
                    }
                    e.stopPropagation();
                  });

                  // Blur to apply
                  inputEl.addEventListener('blur', () => closeEditor(true));

                  // Prevent ProseMirror from handling clicks inside the input
                  inputEl.addEventListener('mousedown', (e) => e.stopPropagation());

                  return {
                    dom: outerSpan,
                    ignoreMutation: () => true,
                    stopEvent: (e: Event) => {
                      // Let the input handle all events when editing
                      if (isEditing && outerSpan.contains(e.target as HTMLElement)) return true;
                      return false;
                    },
                    update(updatedNode) {
                      if (updatedNode.type.name !== 'inlineMath') return false;
                      currentLatex = updatedNode.attrs.latex || '';
                      displayMode = updatedNode.attrs.display === 'yes';
                      if (!isEditing) renderKatex();
                      return true;
                    },
                  };
                };
              },
            }),

            // Custom nodes
            CalloutNode,
            DetailsNode,
            DetailsSummary,
            DetailsContent,

            // Slash commands
            SlashCommands.configure({
              suggestion: {
                items: ({ query }: { query: string }) => {
                  return filterCommands(query);
                },
                render: () => {
                  /** Position slash menu with viewport-aware flipping */
                  function positionSlashMenu(rect: DOMRect) {
                    if (!slashMenuEl) return;
                    slashMenuEl.style.position = 'fixed';
                    slashMenuEl.style.left = `${rect.left}px`;

                    // Menu max-height is 300px (see SlashMenu.svelte)
                    const menuMaxH = 300;
                    const gap = 4;
                    const spaceBelow = window.innerHeight - rect.bottom - gap;
                    const spaceAbove = rect.top - gap;

                    if (spaceBelow >= menuMaxH || spaceBelow >= spaceAbove) {
                      // Below: anchor top edge to bottom of cursor
                      slashMenuEl.style.top = `${rect.bottom + gap}px`;
                      slashMenuEl.style.bottom = 'auto';
                      slashMenuEl.style.maxHeight = `${Math.min(menuMaxH, spaceBelow)}px`;
                    } else {
                      // Above: anchor bottom edge to top of cursor
                      // so popup hugs the slash regardless of content height
                      slashMenuEl.style.top = 'auto';
                      slashMenuEl.style.bottom = `${window.innerHeight - rect.top + gap}px`;
                      slashMenuEl.style.maxHeight = `${Math.min(menuMaxH, spaceAbove)}px`;
                    }
                  }

                  return {
                    onStart: (props: any) => {
                      slashMenuItems = props.items;
                      slashMenuVisible = true;
                      slashCommandFn = props.command;

                      if (props.clientRect) {
                        const rect = props.clientRect();
                        if (rect) positionSlashMenu(rect);
                      }
                    },
                    onUpdate: (props: any) => {
                      slashMenuItems = props.items;
                      slashCommandFn = props.command;

                      if (props.clientRect) {
                        const rect = props.clientRect();
                        if (rect) positionSlashMenu(rect);
                      }
                    },
                    onKeyDown: (props: any) => {
                      if (props.event.key === 'Escape') {
                        slashMenuVisible = false;
                        return true;
                      }
                      return slashMenuComponent?.onKeyDown?.(props.event) ?? false;
                    },
                    onExit: () => {
                      slashMenuVisible = false;
                      slashCommandFn = null;
                    },
                  };
                },
              },
            }),
          ],

          onUpdate: ({ editor: ed }) => {
            if (updatingFromProp) return;

            const html = ed.getHTML();
            value = html;

            // Update counts
            const storage = ed.storage.characterCount;
            wordCount = storage?.words?.() ?? 0;
            characterCount = storage?.characters?.() ?? 0;

            // Debounced valueChanged event
            if (debounceTimer) clearTimeout(debounceTimer);
            debounceTimer = setTimeout(() => {
              valueChanged?.({ value: html });
            }, 300);
          },

          onFocus: () => {
            isFocused = true;
            focusChanged?.({ focused: true });
          },

          onBlur: () => {
            isFocused = false;
            focusChanged?.({ focused: false });
          },

          editorProps: {
            handleKeyDown: (_view, event) => {
              // Ctrl/Cmd+Enter → submitted
              if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
                submitted?.({ value: value });
                return true;
              }
              return false;
            },

            // Clipboard paste → blob to base64 for images
            handlePaste: (_view, event) => {
              const items = event.clipboardData?.items;
              if (!items) return false;

              for (const item of items) {
                if (item.type.startsWith('image/')) {
                  event.preventDefault();
                  const file = item.getAsFile();
                  if (!file) continue;

                  const reader = new FileReader();
                  reader.onload = () => {
                    const dataUri = reader.result as string;
                    editorInstance.chain().focus().setImage({ src: dataUri }).run();
                  };
                  reader.readAsDataURL(file);
                  return true;
                }
              }
              return false;
            },
          },
        });

        // Add block grip plugin
        const gripPlugin = createBlockGripPlugin((event) => {
          gripMenuEvent = event;
          gripMenuVisible = true;
        });
        // Register the plugin via the editor's plugin API
        const { state } = editorInstance;
        const newState = state.reconfigure({ plugins: [...state.plugins, gripPlugin] });
        editorInstance.view.updateState(newState);

        editor = editorInstance;

        // Initial counts
        const storage = editorInstance.storage.characterCount;
        wordCount = storage?.words?.() ?? 0;
        characterCount = storage?.characters?.() ?? 0;

        logger.debug('RichEditor', 'mounted');
      });

      return () => {
        // Flush pending debounce
        if (debounceTimer) {
          clearTimeout(debounceTimer);
          if (editor) {
            valueChanged?.({ value: editor.getHTML() });
          }
        }
        editor?.destroy();
        editor = null;
        logger.debug('RichEditor', 'destroyed');
      };
    });
  });

  // ─── Value sync (MATLAB → editor) ───────────────────
  $effect(() => {
    const v = value;
    if (!editor) return;
    const current = editor.getHTML();
    if (v === current) return;

    updatingFromProp = true;
    editor.commands.setContent(v, false);
    updatingFromProp = false;
  });

  // ─── ReadOnly sync ──────────────────────────────────
  $effect(() => {
    editor?.setEditable(!readOnly && !disabled);
  });

  // ─── Placeholder sync ──────────────────────────────
  $effect(() => {
    if (!editor) return;
    // Reconfigure the placeholder extension with the new text
    editor.extensionManager.extensions
      .find((ext) => ext.name === 'placeholder')
      ?.options && (editor.extensionManager.extensions.find((ext) => ext.name === 'placeholder')!.options.placeholder = placeholderText);
    // Force decoration refresh
    editor.view.dispatch(editor.state.tr);
  });

  // ─── Link click interception ────────────────────────
  // Read-only: any click opens the link directly.
  // Edit mode: link preview popup handles opening (via "Open" button).
  function handleEditorClick(e: MouseEvent) {
    const link = (e.target as HTMLElement).closest('a');
    if (!link) return;

    const href = link.getAttribute('href') ?? '';
    if (href.startsWith('#')) return;

    // Always prevent default navigation
    e.preventDefault();

    // Read-only: open immediately
    if (readOnly) {
      e.stopPropagation();
      openLinkUrl(href);
    }
    // Edit mode: cursor positions on click, link preview popup provides "Open"
  }

  function openLinkUrl(href: string) {
    if (!request || !href) return;
    if (!/^https?:\/\//i.test(href)) {
      href = 'https://' + href;
    }
    request('openLink', { url: href });
  }

  // ─── Image resolution (URLs → MATLAB → base64) ────
  const imageCache = new Map<string, string>();
  const pendingImages = new Set<string>();

  function needsResolve(src: string): boolean {
    if (src.startsWith('http://') || src.startsWith('https://')) return true;
    if (src.startsWith('/')) return true;
    if (/^[A-Za-z]:[/\\]/.test(src)) return true;
    return false;
  }

  $effect(() => {
    // Re-run when editor mounts (async) or when value changes from MATLAB
    void editor;
    value;
    if (!editor || !editorEl || !request) return;
    requestAnimationFrame(() => {
      const imgs = editorEl.querySelectorAll<HTMLImageElement>('img[src]');
      for (const img of imgs) {
        const src = img.getAttribute('src') ?? '';
        if (!needsResolve(src)) continue;
        if (imageCache.has(src)) { img.src = imageCache.get(src)!; continue; }
        if (pendingImages.has(src)) continue;
        pendingImages.add(src);

        request!('fetchImage', { url: src })
          .then((res) => {
            if (res.success && res.data) {
              const asset = (res.data as { asset: AssetData }).asset;
              const dataUri = resolveAssetAsDataUri(asset);
              imageCache.set(src, dataUri);
              editorEl?.querySelectorAll<HTMLImageElement>(`img[src="${CSS.escape(src)}"]`)
                .forEach((el) => { el.src = dataUri; });
            }
          })
          .catch(() => {})
          .finally(() => { pendingImages.delete(src); });
      }
    });
  });

  // ─── Editor scroll tracking (for TOC) ──────────────
  function handleEditorScroll(e: Event) {
    tocComponent?.handleEditorScroll?.(e);
  }

  // ─── Popup viewport clamping ────────────────────
  /** Clamp popup to viewport, flipping above anchor when it overflows bottom */
  function clampPopup(
    anchorX: number, anchorY: number,
    popupW: number, popupH: number,
    gap = 4,
  ): { x: number; y: number } {
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    let x = anchorX;
    let y = anchorY;

    // Clamp horizontal
    if (x + popupW > vw - gap) x = vw - popupW - gap;
    if (x < gap) x = gap;

    // Clamp vertical — flip above anchor if insufficient space below
    if (y + popupH > vh - gap) {
      const flipped = anchorY - popupH - gap * 2;
      y = flipped >= gap ? flipped : Math.max(gap, vh - popupH - gap);
    }

    return { x, y };
  }

  // ─── Dialog handlers ──────────────────────────────
  function openImageDialog(e: MouseEvent) {
    const btn = (e.target as HTMLElement).closest('button');
    const rect = btn?.getBoundingClientRect();
    const ax = rect ? rect.left : e.clientX;
    const ay = rect ? rect.bottom + 4 : e.clientY + 4;
    const pos = clampPopup(ax, ay, 280, 220);
    imageDialogX = pos.x;
    imageDialogY = pos.y;
    imageDialogVisible = true;
  }
  function openLinkDialog(e: MouseEvent) {
    // If cursor is on a link, anchor dialog to the link element in the editor
    let ax = e.clientX;
    let ay = e.clientY + 4;
    if (editor?.isActive('link')) {
      const { from } = editor.state.selection;
      const resolved = editor.view.domAtPos(from);
      const domNode = resolved.node as HTMLElement;
      const linkEl =
        domNode.nodeType === Node.ELEMENT_NODE
          ? (domNode as HTMLElement).closest('a')
          : domNode.parentElement?.closest('a');
      if (linkEl) {
        const linkRect = linkEl.getBoundingClientRect();
        ax = linkRect.left;
        ay = linkRect.bottom + 4;
      }
    } else {
      const btn = (e.target as HTMLElement).closest('button');
      const rect = btn?.getBoundingClientRect();
      if (rect) { ax = rect.left; ay = rect.bottom + 4; }
    }
    const pos = clampPopup(ax, ay, 260, 150);
    linkDialogX = pos.x;
    linkDialogY = pos.y;
    linkDialogVisible = true;
  }
  function openColorPicker(e: MouseEvent) {
    const btn = (e.target as HTMLElement).closest('button');
    const rect = btn?.getBoundingClientRect();
    const ax = rect ? rect.left : e.clientX;
    const ay = rect ? rect.bottom + 4 : e.clientY + 4;
    const pos = clampPopup(ax, ay, 200, 280);
    colorPickerX = pos.x;
    colorPickerY = pos.y;
    colorPickerVisible = true;
  }
  function openTablePicker(e: MouseEvent) {
    const btn = (e.target as HTMLElement).closest('button');
    const rect = btn?.getBoundingClientRect();
    const ax = rect ? rect.left : e.clientX;
    const ay = rect ? rect.bottom + 4 : e.clientY + 4;
    const pos = clampPopup(ax, ay, 190, 170);
    tablePickerX = pos.x;
    tablePickerY = pos.y;
    tablePickerVisible = true;
  }
  function toggleFocusMode() { focusMode = !focusMode; }

  // ─── Block type for status bar ────────────────────
  const currentBlockType = $derived.by(() => {
    void txCount; // re-evaluate on transactions
    if (!editor) return 'P';
    for (let i = 1; i <= 6; i++) {
      if (editor.isActive('heading', { level: i })) return `H${i}`;
    }
    if (editor.isActive('bulletList')) return 'UL';
    if (editor.isActive('orderedList')) return 'OL';
    if (editor.isActive('taskList')) return 'TASK';
    if (editor.isActive('blockquote')) return 'QUOTE';
    if (editor.isActive('codeBlock')) return 'CODE';
    if (editor.isActive('callout')) return 'CALL';
    return 'P';
  });

  // ─── Slash menu command execution ─────────────────
  function executeSlashCommand(item: import('./slash-commands').SlashCommand) {
    if (slashCommandFn) {
      slashCommandFn({ command: () => {} } as any);
      // The actual command is executed by the suggestion plugin
    }
  }

  // ─── Method implementations ────────────────────────
  $effect(() => {
    focusFn = (): Resolution => {
      editor?.commands.focus();
      return { success: true, data: null };
    };

    blurFn = (): Resolution => {
      editor?.commands.blur();
      return { success: true, data: null };
    };

    clearFn = (): Resolution => {
      editor?.commands.clearContent();
      value = '';
      return { success: true, data: null };
    };

    insertContentFn = (html: string): Resolution => {
      if (!editor) return { success: false, data: 'Editor not mounted' };
      editor.commands.insertContent(html);
      return { success: true, data: null };
    };

    getMarkdownFn = (): Resolution => {
      if (!editor) return { success: false, data: 'Editor not mounted' };
      try {
        // tiptap-markdown adds getMarkdown() to the editor
        const md = (editor as any).storage?.markdown?.getMarkdown?.() ??
                   (editor as any).getMarkdown?.() ?? '';
        return { success: true, data: md };
      } catch {
        return { success: false, data: 'Markdown conversion unavailable' };
      }
    };

    exportPdfFn = (filepath: string): Resolution => {
      doExportPdf(filepath ?? '');
      return { success: true, data: null };
    };
  });

  // ─── PDF Export (async, uses request to send base64 to MATLAB) ────
  async function doExportPdf(filepath: string) {
    if (!editor) return;
    const proseMirrorEl = editorEl?.querySelector('.ProseMirror') as HTMLElement;
    if (!proseMirrorEl) return;

    try {
      const base64 = await htmlToPdfBase64(proseMirrorEl, {
        title: 'RichEditor Export',
      });
      if (request) {
        await request('savePdf', { base64, filepath });
      }
    } catch (err) {
      logger.warn('RichEditor', 'PDF export error', { error: String(err) });
    }
  }

  // ─── Force transaction-based UI refresh ───────────
  // Incremented on every editor transaction so derived state
  // that reads it (selectedWordCount, currentBlockType) re-evaluates.
  let txCount = $state(0);
  $effect(() => {
    if (!editor) return;
    const ed = editor;
    const handler = () => { txCount++; };
    ed.on('transaction', handler);
    return () => { ed.off('transaction', handler); };
  });
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-rte"
  class:ic-rte--focus-mode={focusMode}
  class:ic-rte--disabled={disabled}
  class:ic-rte--readonly={readOnly}
  style:height={toSize(height)}
  bind:this={containerEl}
>
  <!-- Toolbar -->
  {#if showToolbar && !readOnly && !disabled}
    <Toolbar
      {editor}
      {focusMode}
      onImageClick={openImageDialog}
      onLinkClick={openLinkDialog}
      onColorClick={openColorPicker}
      onTableClick={openTablePicker}
      onFocusModeToggle={toggleFocusMode}
    />
  {/if}

  <!-- Editor area + TOC -->
  <div class="ic-rte__body">
    <div
      class="ic-rte__editor"
      bind:this={editorEl}
      onclick={handleEditorClick}
      onscroll={handleEditorScroll}
    ></div>

    <!-- TOC sidebar -->
    {#if showToc}
      <TOCSidebar
        {editor}
        visible={showToc}
        bind:this={tocComponent}
      />
    {/if}
  </div>

  <!-- Bubble menu (anchor element for TipTap BubbleMenu extension) -->
  <div bind:this={bubbleMenuEl} style="visibility: hidden; position: absolute; top: 0; left: 0;">
    {#if editor && !readOnly && !disabled && hasTextSelection}
      <BubbleToolbar
        {editor}
        onLinkClick={openLinkDialog}
        onColorClick={openColorPicker}
      />
    {/if}
  </div>

  <!-- Slash menu (positioned by suggestion plugin) -->
  <div bind:this={slashMenuEl} style="position: fixed; z-index: 50;" class:ic-rte-slash-hidden={!slashMenuVisible}>
    {#if slashMenuVisible}
      <SlashMenu
        items={slashMenuItems}
        command={(item) => {
          if (slashCommandFn) {
            (slashCommandFn as any)(item);
          }
        }}
        bind:this={slashMenuComponent}
      />
    {/if}
  </div>

  <!-- Status bar -->
  <div class="ic-rte__status">
    <span class="ic-rte__status-item ic-rte__status-block">{currentBlockType}</span>
    <span class="ic-rte__status-spacer"></span>
    {#if selectedWordCount > 0}
      <span class="ic-rte__status-item">{selectedWordCount} words selected</span>
    {:else}
      <span class="ic-rte__status-item">
        {wordCount} words &middot; {characterCount} chars &middot; ~{readingTime} min read
      </span>
    {/if}
    <span class="ic-rte__status-spacer"></span>
  </div>

  <!-- Dialog popovers -->
  <ImageDialog
    {editor}
    {request}
    bind:visible={imageDialogVisible}
    x={imageDialogX}
    y={imageDialogY}
  />
  <LinkDialog
    {editor}
    bind:visible={linkDialogVisible}
    x={linkDialogX}
    y={linkDialogY}
  />
  {#if editor && !disabled}
    <LinkPreview
      {editor}
      onOpen={openLinkUrl}
      onEdit={(e) => openLinkDialog(e)}
    />
  {/if}
  <ColorPicker
    {editor}
    bind:visible={colorPickerVisible}
    x={colorPickerX}
    y={colorPickerY}
  />
  <TableGridPicker
    {editor}
    bind:visible={tablePickerVisible}
    x={tablePickerX}
    y={tablePickerY}
  />
  <GripMenu
    {editor}
    bind:visible={gripMenuVisible}
    bind:event={gripMenuEvent}
  />
</div>

<style>
  .ic-rte {
    position: relative;
    display: flex;
    flex-direction: column;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    overflow: clip;
    background-color: var(--ic-background);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  .ic-rte--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-rte__body {
    flex: 1;
    position: relative;
    min-height: 0;
    display: flex;
    overflow: hidden;
  }

  .ic-rte__editor {
    flex: 1;
    overflow-y: auto;
    overflow-x: clip;
    min-height: 0;
    position: relative;
  }

  /* Ensure ProseMirror fills the editor */
  .ic-rte__editor :global(.ProseMirror) {
    min-height: 100%;
  }

  /* ── Status bar ──────────────────────────────── */
  .ic-rte__status {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 2px 8px;
    border-top: 1px solid var(--ic-border);
    background-color: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    font-size: 0.75em;
    line-height: 1.6;
    user-select: none;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
    font-variant-numeric: tabular-nums;
  }

  .ic-rte__status-item {
    white-space: nowrap;
  }

  .ic-rte__status-block {
    font-weight: 600;
    min-width: 36px;
    text-align: center;
    padding: 0 4px;
    border-radius: 2px;
    background-color: var(--ic-muted);
  }

  .ic-rte__status-spacer {
    flex: 1;
  }

  /* Hide slash menu when not visible */
  .ic-rte-slash-hidden {
    display: none;
  }
</style>
