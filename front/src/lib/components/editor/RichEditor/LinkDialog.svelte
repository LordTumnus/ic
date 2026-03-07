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

  let url = $state('');
  let text = $state('');
  let dialogEl = $state<HTMLDivElement>();

  const icX = resolveIcon('x', 14);
  const icUnlink = resolveIcon('unlink', 14);

  const isLink = $derived(editor?.isActive('link') ?? false);

  // Pre-fill when opening on an existing link
  $effect(() => {
    if (visible && editor) {
      if (isLink) {
        const attrs = editor.getAttributes('link');
        url = attrs.href || '';
      } else {
        // Check clipboard for URL
        url = '';
      }
      // Get selected text
      const { from, to } = editor.state.selection;
      text = editor.state.doc.textBetween(from, to, ' ');
    }
  });

  function close() {
    visible = false;
    url = '';
    text = '';
  }

  function setLink() {
    if (!editor || !url.trim()) return;

    editor
      .chain()
      .focus()
      .extendMarkRange('link')
      .setLink({ href: url.trim() })
      .run();
    close();
  }

  function unlink() {
    if (!editor) return;
    editor.chain().focus().extendMarkRange('link').unsetLink().run();
    close();
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      setLink();
    } else if (e.key === 'Escape') {
      close();
    }
  }

  // Click-outside-to-close
  $effect(() => {
    if (!visible) return;
    const onMouseDown = (e: MouseEvent) => {
      if (dialogEl && !dialogEl.contains(e.target as Node)) {
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
  <div class="ic-rte-linkdlg" style:left="{x}px" style:top="{y}px" bind:this={dialogEl} onkeydown={handleKeyDown}>
    <div class="ic-rte-linkdlg__header">
      <span class="ic-rte-linkdlg__title">{isLink ? 'Edit Link' : 'Insert Link'}</span>
      <button class="ic-rte-linkdlg__close" onclick={close}>{@html icX}</button>
    </div>

    <div class="ic-rte-linkdlg__body">
      <input
        class="ic-rte-linkdlg__input"
        type="text"
        placeholder="URL"
        bind:value={url}
      />
      <div class="ic-rte-linkdlg__actions">
        <button
          class="ic-rte-linkdlg__submit"
          onclick={setLink}
          disabled={!url.trim()}
        >
          {isLink ? 'Update' : 'Insert'}
        </button>
        {#if isLink}
          <button class="ic-rte-linkdlg__unlink" onclick={unlink} title="Remove link">
            {@html icUnlink} Unlink
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .ic-rte-linkdlg {
    position: fixed;
    z-index: 40;
    width: 260px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .ic-rte-linkdlg__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 8px;
    border-bottom: 1px solid var(--ic-border);
  }

  .ic-rte-linkdlg__title {
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
  }

  .ic-rte-linkdlg__close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
  }

  .ic-rte-linkdlg__close:hover {
    background-color: var(--ic-muted);
    color: var(--ic-foreground);
  }

  .ic-rte-linkdlg__body {
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .ic-rte-linkdlg__input {
    width: 100%;
    padding: 4px 8px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background-color: var(--ic-background);
    color: var(--ic-foreground);
    font-size: 12px;
    outline: none;
    box-sizing: border-box;
  }

  .ic-rte-linkdlg__input:focus {
    border-color: var(--ic-primary);
  }

  .ic-rte-linkdlg__actions {
    display: flex;
    gap: 4px;
  }

  .ic-rte-linkdlg__submit {
    flex: 1;
    padding: 4px 12px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
  }

  .ic-rte-linkdlg__submit:hover {
    opacity: 0.9;
  }

  .ic-rte-linkdlg__submit:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .ic-rte-linkdlg__unlink {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 8px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: transparent;
    color: var(--ic-destructive);
    font-size: 12px;
    cursor: pointer;
  }

  .ic-rte-linkdlg__unlink:hover {
    background-color: rgba(239, 68, 68, 0.08);
  }
</style>
