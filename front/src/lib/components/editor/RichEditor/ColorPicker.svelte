<script lang="ts">
  import type { Editor } from '@tiptap/core';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    editor,
    visible = $bindable(false),
    x = 0,
    y = 0,
  }: {
    editor: Editor | null;
    visible?: boolean;
    x?: number;
    y?: number;
  } = $props();

  const icX = resolveIcon('x', 14);
  let pickerEl = $state<HTMLDivElement>();

  type ColorMode = 'text' | 'highlight';
  let mode = $state<ColorMode>('text');

  // Flat grid palette — theme colors + extended
  const PALETTE = [
    // Row 1: Neutral tones
    '#000000', '#374151', '#6b7280', '#9ca3af',
    '#d1d5db', '#e5e7eb', '#f3f4f6', '#ffffff',
    // Row 2: Warm colors
    '#ef4444', '#f97316', '#f59e0b', '#eab308',
    '#84cc16', '#22c55e', '#14b8a6', '#06b6d4',
    // Row 3: Cool colors
    '#3b82f6', '#6366f1', '#8b5cf6', '#a855f7',
    '#d946ef', '#ec4899', '#f43f5e', '#fb7185',
  ];

  function setColor(color: string) {
    if (!editor) return;
    if (mode === 'text') {
      editor.chain().focus().setColor(color).run();
    } else {
      editor.chain().focus().toggleHighlight({ color }).run();
    }
  }

  function clearColor() {
    if (!editor) return;
    if (mode === 'text') {
      editor.chain().focus().unsetColor().run();
    } else {
      editor.chain().focus().unsetHighlight().run();
    }
  }

  function close() {
    visible = false;
  }

  // Click-outside-to-close
  $effect(() => {
    if (!visible) return;
    const onMouseDown = (e: MouseEvent) => {
      if (pickerEl && !pickerEl.contains(e.target as Node)) {
        close();
      }
    };
    const timer = setTimeout(() => window.addEventListener('mousedown', onMouseDown), 0);
    return () => {
      clearTimeout(timer);
      window.removeEventListener('mousedown', onMouseDown);
    };
  });
</script>

{#if visible}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="ic-rte-colorpicker" style:left="{x}px" style:top="{y}px" bind:this={pickerEl} onmousedown={(e) => e.preventDefault()}>
    <div class="ic-rte-colorpicker__header">
      <div class="ic-rte-colorpicker__tabs">
        <button
          class="ic-rte-colorpicker__tab"
          class:ic-rte-colorpicker__tab--active={mode === 'text'}
          onclick={() => { mode = 'text'; }}
        >Text</button>
        <button
          class="ic-rte-colorpicker__tab"
          class:ic-rte-colorpicker__tab--active={mode === 'highlight'}
          onclick={() => { mode = 'highlight'; }}
        >Highlight</button>
      </div>
      <button class="ic-rte-colorpicker__close" onclick={close}>{@html icX}</button>
    </div>

    <div class="ic-rte-colorpicker__grid">
      {#each PALETTE as color}
        <button
          class="ic-rte-colorpicker__swatch"
          style:background-color={color}
          onclick={() => setColor(color)}
          title={color}
        ></button>
      {/each}
    </div>

    <button class="ic-rte-colorpicker__clear" onclick={clearColor}>
      Clear color
    </button>
  </div>
{/if}

<style>
  .ic-rte-colorpicker {
    position: fixed;
    z-index: 40;
    width: 200px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    padding: 4px;
  }

  .ic-rte-colorpicker__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 2px 4px 4px;
    border-bottom: 1px solid var(--ic-border);
    margin-bottom: 4px;
  }

  .ic-rte-colorpicker__tabs {
    display: flex;
    gap: 2px;
  }

  .ic-rte-colorpicker__tab {
    padding: 2px 8px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    font-size: 10px;
    font-weight: 600;
    cursor: pointer;
  }

  .ic-rte-colorpicker__tab:hover {
    background-color: var(--ic-muted);
  }

  .ic-rte-colorpicker__tab--active {
    color: var(--ic-primary);
    background-color: rgba(66, 133, 244, 0.1);
  }

  .ic-rte-colorpicker__close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
  }

  .ic-rte-colorpicker__close:hover {
    background-color: var(--ic-muted);
  }

  .ic-rte-colorpicker__grid {
    display: grid;
    grid-template-columns: repeat(8, 1fr);
    gap: 2px;
    padding: 4px;
  }

  .ic-rte-colorpicker__swatch {
    width: 20px;
    height: 20px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    cursor: pointer;
    padding: 0;
    transition: transform 0.1s ease;
  }

  .ic-rte-colorpicker__swatch:hover {
    transform: scale(1.2);
    z-index: 1;
    box-shadow: 0 0 0 1px var(--ic-foreground);
  }

  .ic-rte-colorpicker__clear {
    width: 100%;
    padding: 4px;
    border: none;
    border-top: 1px solid var(--ic-border);
    background: transparent;
    color: var(--ic-muted-foreground);
    font-size: 10px;
    cursor: pointer;
    margin-top: 4px;
  }

  .ic-rte-colorpicker__clear:hover {
    background-color: var(--ic-muted);
    color: var(--ic-foreground);
  }
</style>
