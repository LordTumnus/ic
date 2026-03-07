<script lang="ts">
  import type { Editor } from '@tiptap/core';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    editor,
    onImageClick,
    onLinkClick,
    onColorClick,
    focusMode = false,
    onFocusModeToggle,
  }: {
    editor: Editor | null;
    onImageClick: (e: MouseEvent) => void;
    onLinkClick: (e: MouseEvent) => void;
    onColorClick: (e: MouseEvent) => void;
    focusMode?: boolean;
    onFocusModeToggle: () => void;
  } = $props();

  // ── Icon resolution (14px, matching Latex toolbar) ─────────────
  const icons = {
    bold: resolveIcon('bold', 14),
    italic: resolveIcon('italic', 14),
    underline: resolveIcon('underline', 14),
    strikethrough: resolveIcon('strikethrough', 14),
    code: resolveIcon('code', 14),
    highlight: resolveIcon('highlighter', 14),
    subscript: resolveIcon('subscript', 14),
    superscript: resolveIcon('superscript', 14),
    h1: resolveIcon('heading-1', 14),
    h2: resolveIcon('heading-2', 14),
    h3: resolveIcon('heading-3', 14),
    h4: resolveIcon('heading-4', 14),
    h5: resolveIcon('heading-5', 14),
    h6: resolveIcon('heading-6', 14),
    paragraph: resolveIcon('pilcrow', 14),
    bulletList: resolveIcon('list', 14),
    orderedList: resolveIcon('list-ordered', 14),
    taskList: resolveIcon('list-checks', 14),
    blockquote: resolveIcon('quote', 14),
    codeBlock: resolveIcon('code-2', 14),
    hr: resolveIcon('minus', 14),
    link: resolveIcon('link', 14),
    image: resolveIcon('image', 14),
    table: resolveIcon('table', 14),
    alignLeft: resolveIcon('align-left', 14),
    alignCenter: resolveIcon('align-center', 14),
    alignRight: resolveIcon('align-right', 14),
    alignJustify: resolveIcon('align-justify', 14),
    focusMode: resolveIcon('eye', 14),
    palette: resolveIcon('palette', 14),
    undo: resolveIcon('undo-2', 14),
    redo: resolveIcon('redo-2', 14),
    chevronDown: resolveIcon('chevron-down', 10),
  };

  // ── Active state tracking ─────────────────────────────────────
  let activeStates = $state<Record<string, boolean>>({});
  let headingDropdownOpen = $state(false);
  let headingBtnEl = $state<HTMLButtonElement>();
  let dropdownMenuEl = $state<HTMLDivElement>();
  let dropdownX = $state(0);
  let dropdownY = $state(0);

  $effect(() => {
    if (!editor) return;

    const updateStates = () => {
      activeStates = {
        bold: editor!.isActive('bold'),
        italic: editor!.isActive('italic'),
        underline: editor!.isActive('underline'),
        strike: editor!.isActive('strike'),
        code: editor!.isActive('code'),
        highlight: editor!.isActive('highlight'),
        subscript: editor!.isActive('subscript'),
        superscript: editor!.isActive('superscript'),
        bulletList: editor!.isActive('bulletList'),
        orderedList: editor!.isActive('orderedList'),
        taskList: editor!.isActive('taskList'),
        blockquote: editor!.isActive('blockquote'),
        codeBlock: editor!.isActive('codeBlock'),
        alignLeft: editor!.isActive({ textAlign: 'left' }),
        alignCenter: editor!.isActive({ textAlign: 'center' }),
        alignRight: editor!.isActive({ textAlign: 'right' }),
        alignJustify: editor!.isActive({ textAlign: 'justify' }),
        link: editor!.isActive('link'),
        h1: editor!.isActive('heading', { level: 1 }),
        h2: editor!.isActive('heading', { level: 2 }),
        h3: editor!.isActive('heading', { level: 3 }),
        h4: editor!.isActive('heading', { level: 4 }),
        h5: editor!.isActive('heading', { level: 5 }),
        h6: editor!.isActive('heading', { level: 6 }),
      };
    };

    editor.on('transaction', updateStates);
    updateStates();
    return () => { editor!.off('transaction', updateStates); };
  });

  function currentHeadingLabel(): string {
    for (let i = 1; i <= 6; i++) {
      if (activeStates[`h${i}`]) return `H${i}`;
    }
    return 'P';
  }

  function toggleHeadingDropdown() {
    headingDropdownOpen = !headingDropdownOpen;
    if (headingDropdownOpen && headingBtnEl) {
      const rect = headingBtnEl.getBoundingClientRect();
      const menuW = 140, menuH = 230;
      const gap = 4;
      let x = rect.left;
      let y = rect.bottom + 2;
      if (x + menuW > window.innerWidth - gap) x = window.innerWidth - menuW - gap;
      if (x < gap) x = gap;
      if (y + menuH > window.innerHeight - gap) {
        const flipped = rect.top - menuH - 2;
        y = flipped >= gap ? flipped : Math.max(gap, window.innerHeight - menuH - gap);
      }
      dropdownX = x;
      dropdownY = y;
    }
  }

  // Click-outside-to-close for heading dropdown
  $effect(() => {
    if (!headingDropdownOpen) return;
    const onMouseDown = (e: MouseEvent) => {
      if (dropdownMenuEl && !dropdownMenuEl.contains(e.target as Node) &&
          headingBtnEl && !headingBtnEl.contains(e.target as Node)) {
        headingDropdownOpen = false;
      }
    };
    const timer = setTimeout(() => window.addEventListener('mousedown', onMouseDown), 0);
    return () => {
      clearTimeout(timer);
      window.removeEventListener('mousedown', onMouseDown);
    };
  });

  function setHeading(level: number | null) {
    if (!editor) return;
    headingDropdownOpen = false;
    if (level === null) {
      editor.chain().focus().setParagraph().run();
    } else {
      editor.chain().focus().setHeading({ level: level as 1|2|3|4|5|6 }).run();
    }
  }

  function cmd(action: string) {
    if (!editor) return;
    switch (action) {
      case 'bold': editor.chain().focus().toggleBold().run(); break;
      case 'italic': editor.chain().focus().toggleItalic().run(); break;
      case 'underline': editor.chain().focus().toggleUnderline().run(); break;
      case 'strike': editor.chain().focus().toggleStrike().run(); break;
      case 'code': editor.chain().focus().toggleCode().run(); break;
      case 'highlight': editor.chain().focus().toggleHighlight().run(); break;
      case 'subscript': editor.chain().focus().toggleSubscript().run(); break;
      case 'superscript': editor.chain().focus().toggleSuperscript().run(); break;
      case 'bulletList': editor.chain().focus().toggleBulletList().run(); break;
      case 'orderedList': editor.chain().focus().toggleOrderedList().run(); break;
      case 'taskList': editor.chain().focus().toggleTaskList().run(); break;
      case 'blockquote': editor.chain().focus().toggleBlockquote().run(); break;
      case 'codeBlock': editor.chain().focus().toggleCodeBlock().run(); break;
      case 'hr': editor.chain().focus().setHorizontalRule().run(); break;
      case 'table': editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(); break;
      case 'alignLeft': editor.chain().focus().setTextAlign('left').run(); break;
      case 'alignCenter': editor.chain().focus().setTextAlign('center').run(); break;
      case 'alignRight': editor.chain().focus().setTextAlign('right').run(); break;
      case 'alignJustify': editor.chain().focus().setTextAlign('justify').run(); break;
      case 'undo': editor.chain().focus().undo().run(); break;
      case 'redo': editor.chain().focus().redo().run(); break;
    }
  }

  function handleToolbarMouseDown(e: MouseEvent) {
    // Prevent toolbar clicks from stealing focus from the editor
    e.preventDefault();
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ic-rte-toolbar" onmousedown={handleToolbarMouseDown}>
  <!-- Inline formatting -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.bold} onclick={() => cmd('bold')} title="Bold (Ctrl+B)">{@html icons.bold}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.italic} onclick={() => cmd('italic')} title="Italic (Ctrl+I)">{@html icons.italic}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.underline} onclick={() => cmd('underline')} title="Underline (Ctrl+U)">{@html icons.underline}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.strike} onclick={() => cmd('strike')} title="Strikethrough">{@html icons.strikethrough}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.code} onclick={() => cmd('code')} title="Inline Code">{@html icons.code}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.highlight} onclick={() => cmd('highlight')} title="Highlight">{@html icons.highlight}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.subscript} onclick={() => cmd('subscript')} title="Subscript">{@html icons.subscript}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.superscript} onclick={() => cmd('superscript')} title="Superscript">{@html icons.superscript}</button>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- Heading dropdown -->
  <div class="ic-rte-toolbar__group">
    <div class="ic-rte-toolbar__dropdown-wrap">
      <button
        class="ic-rte-toolbar__btn ic-rte-toolbar__btn--dropdown"
        bind:this={headingBtnEl}
        onclick={toggleHeadingDropdown}
        title="Block type"
      >
        <span class="ic-rte-toolbar__dropdown-label">{currentHeadingLabel()}</span>
        {@html icons.chevronDown}
      </button>
      {#if headingDropdownOpen}
        <div class="ic-rte-toolbar__dropdown-menu" style:left="{dropdownX}px" style:top="{dropdownY}px" bind:this={dropdownMenuEl}>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={!activeStates.h1 && !activeStates.h2 && !activeStates.h3 && !activeStates.h4 && !activeStates.h5 && !activeStates.h6} onclick={() => setHeading(null)}>
            {@html icons.paragraph} Paragraph
          </button>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={activeStates.h1} onclick={() => setHeading(1)}>
            {@html icons.h1} Heading 1
          </button>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={activeStates.h2} onclick={() => setHeading(2)}>
            {@html icons.h2} Heading 2
          </button>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={activeStates.h3} onclick={() => setHeading(3)}>
            {@html icons.h3} Heading 3
          </button>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={activeStates.h4} onclick={() => setHeading(4)}>
            {@html icons.h4} Heading 4
          </button>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={activeStates.h5} onclick={() => setHeading(5)}>
            {@html icons.h5} Heading 5
          </button>
          <button class="ic-rte-toolbar__dropdown-item" class:ic-rte-toolbar__dropdown-item--active={activeStates.h6} onclick={() => setHeading(6)}>
            {@html icons.h6} Heading 6
          </button>
        </div>
      {/if}
    </div>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- Lists -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.bulletList} onclick={() => cmd('bulletList')} title="Bullet List">{@html icons.bulletList}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.orderedList} onclick={() => cmd('orderedList')} title="Numbered List">{@html icons.orderedList}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.taskList} onclick={() => cmd('taskList')} title="Task List">{@html icons.taskList}</button>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- Block types -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.blockquote} onclick={() => cmd('blockquote')} title="Blockquote">{@html icons.blockquote}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.codeBlock} onclick={() => cmd('codeBlock')} title="Code Block">{@html icons.codeBlock}</button>
    <button class="ic-rte-toolbar__btn" onclick={() => cmd('hr')} title="Horizontal Rule">{@html icons.hr}</button>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- Insert -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.link} onclick={(e) => onLinkClick(e)} title="Link">{@html icons.link}</button>
    <button class="ic-rte-toolbar__btn" onclick={(e) => onImageClick(e)} title="Image">{@html icons.image}</button>
    <button class="ic-rte-toolbar__btn" onclick={() => cmd('table')} title="Table">{@html icons.table}</button>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- Alignment -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.alignLeft} onclick={() => cmd('alignLeft')} title="Align Left">{@html icons.alignLeft}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.alignCenter} onclick={() => cmd('alignCenter')} title="Align Center">{@html icons.alignCenter}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.alignRight} onclick={() => cmd('alignRight')} title="Align Right">{@html icons.alignRight}</button>
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={activeStates.alignJustify} onclick={() => cmd('alignJustify')} title="Justify">{@html icons.alignJustify}</button>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- Tools -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" class:ic-rte-toolbar__btn--active={focusMode} onclick={onFocusModeToggle} title="Focus Mode">{@html icons.focusMode}</button>
    <button class="ic-rte-toolbar__btn" onclick={onColorClick} title="Colors">{@html icons.palette}</button>
  </div>

  <div class="ic-rte-toolbar__sep"></div>

  <!-- History -->
  <div class="ic-rte-toolbar__group">
    <button class="ic-rte-toolbar__btn" onclick={() => cmd('undo')} title="Undo (Ctrl+Z)">{@html icons.undo}</button>
    <button class="ic-rte-toolbar__btn" onclick={() => cmd('redo')} title="Redo (Ctrl+Y)">{@html icons.redo}</button>
  </div>
</div>

<style>
  .ic-rte-toolbar {
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 4px 8px;
    border-bottom: 1px solid var(--ic-border);
    background-color: var(--ic-secondary);
    box-shadow: inset 0 -1px 2px rgba(0, 0, 0, 0.04);
    flex-wrap: wrap;
    user-select: none;
    min-height: 32px;
  }

  .ic-rte-toolbar__group {
    display: flex;
    align-items: center;
    gap: 1px;
  }

  .ic-rte-toolbar__sep {
    width: 1px;
    height: 16px;
    background-color: var(--ic-border);
    margin: 0 4px;
    flex-shrink: 0;
  }

  .ic-rte-toolbar__btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    padding: 0;
    border: 1px solid transparent;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    transition: color 0.1s ease, background-color 0.1s ease, border-color 0.1s ease;
    line-height: 0;
    flex-shrink: 0;
  }

  .ic-rte-toolbar__btn:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
    border-color: var(--ic-border);
  }

  .ic-rte-toolbar__btn:active {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  .ic-rte-toolbar__btn--active {
    color: var(--ic-primary);
    background-color: rgba(66, 133, 244, 0.1);
  }

  .ic-rte-toolbar__btn--dropdown {
    width: auto;
    padding: 0 4px;
    gap: 2px;
    font-size: 11px;
    font-weight: 600;
    min-width: 36px;
  }

  .ic-rte-toolbar__dropdown-label {
    font-variant-numeric: tabular-nums;
  }

  /* ── Heading dropdown menu ────────────────────────── */
  .ic-rte-toolbar__dropdown-wrap {
    position: relative;
  }

  .ic-rte-toolbar__dropdown-menu {
    position: fixed;
    z-index: 50;
    min-width: 140px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
    padding: 2px;
  }

  .ic-rte-toolbar__dropdown-item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 4px 8px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-foreground);
    font-size: 12px;
    cursor: pointer;
    text-align: left;
  }

  .ic-rte-toolbar__dropdown-item:hover {
    background-color: var(--ic-muted);
  }

  .ic-rte-toolbar__dropdown-item--active {
    color: var(--ic-primary);
    font-weight: 600;
  }
</style>
