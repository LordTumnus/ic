<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { BubbleMenu } from '@tiptap/extension-bubble-menu';
  import type { Editor } from '@tiptap/core';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    editor,
    onLinkClick,
    onColorClick,
  }: {
    editor: Editor;
    onLinkClick: (e: MouseEvent) => void;
    onColorClick: (e: MouseEvent) => void;
  } = $props();

  let menuEl: HTMLDivElement;
  let bubbleMenuPlugin: ReturnType<typeof BubbleMenu.create> | null = null;

  const icons = {
    bold: resolveIcon('bold', 14),
    italic: resolveIcon('italic', 14),
    underline: resolveIcon('underline', 14),
    strike: resolveIcon('strikethrough', 14),
    link: resolveIcon('link', 14),
    highlight: resolveIcon('highlighter', 14),
    palette: resolveIcon('palette', 14),
  };

  let activeStates = $state<Record<string, boolean>>({});

  $effect(() => {
    if (!editor) return;
    const update = () => {
      activeStates = {
        bold: editor.isActive('bold'),
        italic: editor.isActive('italic'),
        underline: editor.isActive('underline'),
        strike: editor.isActive('strike'),
        link: editor.isActive('link'),
        highlight: editor.isActive('highlight'),
      };
    };
    editor.on('transaction', update);
    update();
    return () => { editor.off('transaction', update); };
  });

  function cmd(action: string) {
    switch (action) {
      case 'bold': editor.chain().focus().toggleBold().run(); break;
      case 'italic': editor.chain().focus().toggleItalic().run(); break;
      case 'underline': editor.chain().focus().toggleUnderline().run(); break;
      case 'strike': editor.chain().focus().toggleStrike().run(); break;
      case 'highlight': editor.chain().focus().toggleHighlight().run(); break;
    }
  }

  function handleMouseDown(e: MouseEvent) {
    e.preventDefault();
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ic-rte-bubble" bind:this={menuEl} onmousedown={handleMouseDown}>
  <button class="ic-rte-bubble__btn" class:ic-rte-bubble__btn--active={activeStates.bold} onclick={() => cmd('bold')} title="Bold">{@html icons.bold}</button>
  <button class="ic-rte-bubble__btn" class:ic-rte-bubble__btn--active={activeStates.italic} onclick={() => cmd('italic')} title="Italic">{@html icons.italic}</button>
  <button class="ic-rte-bubble__btn" class:ic-rte-bubble__btn--active={activeStates.underline} onclick={() => cmd('underline')} title="Underline">{@html icons.underline}</button>
  <button class="ic-rte-bubble__btn" class:ic-rte-bubble__btn--active={activeStates.strike} onclick={() => cmd('strike')} title="Strikethrough">{@html icons.strike}</button>
  <div class="ic-rte-bubble__sep"></div>
  <button class="ic-rte-bubble__btn" class:ic-rte-bubble__btn--active={activeStates.link} onclick={(e) => onLinkClick(e)} title="Link">{@html icons.link}</button>
  <button class="ic-rte-bubble__btn" class:ic-rte-bubble__btn--active={activeStates.highlight} onclick={() => cmd('highlight')} title="Highlight">{@html icons.highlight}</button>
  <button class="ic-rte-bubble__btn" onclick={onColorClick} title="Color">{@html icons.palette}</button>
</div>

<style>
  .ic-rte-bubble {
    display: flex;
    align-items: center;
    gap: 1px;
    padding: 4px 6px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15), inset 0 -1px 2px rgba(0, 0, 0, 0.08);
  }

  .ic-rte-bubble__btn {
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
    transition: color 0.1s ease, background-color 0.1s ease;
    line-height: 0;
  }

  .ic-rte-bubble__btn:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
  }

  .ic-rte-bubble__btn:active {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  .ic-rte-bubble__btn--active {
    color: var(--ic-primary);
  }

  .ic-rte-bubble__sep {
    width: 1px;
    height: 16px;
    background-color: var(--ic-border);
    margin: 0 3px;
  }
</style>
