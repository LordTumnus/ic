<script lang="ts">
  import type { Editor } from '@tiptap/core';
  import type { RequestFn } from '$lib/types';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    editor,
    request,
    visible = $bindable(false),
    x = 0,
    y = 0,
  }: {
    editor: Editor | null;
    request?: RequestFn;
    visible?: boolean;
    x?: number;
    y?: number;
  } = $props();

  let url = $state('');
  let alt = $state('');
  let loading = $state(false);
  let error = $state('');
  let dialogEl = $state<HTMLDivElement>();

  const icX = resolveIcon('x', 14);
  const icFolder = resolveIcon('folder-open', 14);

  function close() {
    visible = false;
    url = '';
    alt = '';
    error = '';
    loading = false;
  }

  /** Ask MATLAB to show a file picker dialog, returns the selected file path */
  async function browseFile() {
    if (!request) return;
    loading = true;
    error = '';
    try {
      const res = await request('browseImage', {});
      if (res.success && res.data) {
        const data = res.data as { dataUri?: string; path?: string };
        if (data.dataUri) {
          // MATLAB returned the image directly as base64
          if (editor) {
            editor.chain().focus().setImage({ src: data.dataUri, alt }).run();
            close();
          }
        } else if (data.path) {
          url = data.path;
        }
      }
      // If result was empty/cancelled, do nothing
    } catch {
      error = 'Browse cancelled or failed';
    } finally {
      loading = false;
    }
  }

  async function insertImage() {
    if (!editor || !url.trim()) return;

    const src = url.trim();

    // If it's a data URI, insert directly
    if (src.startsWith('data:')) {
      editor.chain().focus().setImage({ src, alt }).run();
      close();
      return;
    }

    // Otherwise, fetch via MATLAB (handles URLs and file paths)
    if (request) {
      loading = true;
      error = '';
      try {
        const res = await request('fetchImage', { url: src });
        if (res.success && res.data) {
          const dataUri = (res.data as { dataUri: string }).dataUri;
          editor.chain().focus().setImage({ src: dataUri, alt }).run();
          close();
        } else {
          error = 'Failed to fetch image';
        }
      } catch {
        error = 'Failed to fetch image';
      } finally {
        loading = false;
      }
    } else {
      // No request function — insert URL directly (may not display in MATLAB)
      editor.chain().focus().setImage({ src, alt }).run();
      close();
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      insertImage();
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
    // Delay listener to avoid catching the opening click
    const timer = setTimeout(() => window.addEventListener('mousedown', onMouseDown), 0);
    return () => {
      clearTimeout(timer);
      window.removeEventListener('mousedown', onMouseDown);
    };
  });
</script>

{#if visible}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="ic-rte-imgdlg" style:left="{x}px" style:top="{y}px" bind:this={dialogEl} onkeydown={handleKeyDown}>
    <div class="ic-rte-imgdlg__header">
      <span class="ic-rte-imgdlg__title">Insert Image</span>
      <button class="ic-rte-imgdlg__close" onclick={close}>{@html icX}</button>
    </div>

    <div class="ic-rte-imgdlg__body">
      <div class="ic-rte-imgdlg__url-row">
        <input
          class="ic-rte-imgdlg__input"
          type="text"
          placeholder="URL or file path"
          bind:value={url}
        />
        {#if request}
          <button class="ic-rte-imgdlg__browse" onclick={browseFile} title="Browse files" disabled={loading}>
            {@html icFolder}
          </button>
        {/if}
      </div>
      <input
        class="ic-rte-imgdlg__input"
        type="text"
        placeholder="Alt text (optional)"
        bind:value={alt}
      />
      {#if error}
        <div class="ic-rte-imgdlg__error">{error}</div>
      {/if}
      <button
        class="ic-rte-imgdlg__submit"
        onclick={insertImage}
        disabled={!url.trim() || loading}
      >
        {loading ? 'Loading...' : 'Insert'}
      </button>
    </div>
  </div>
{/if}

<style>
  .ic-rte-imgdlg {
    position: fixed;
    z-index: 40;
    width: 280px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .ic-rte-imgdlg__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 8px;
    border-bottom: 1px solid var(--ic-border);
  }

  .ic-rte-imgdlg__title {
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
  }

  .ic-rte-imgdlg__close {
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

  .ic-rte-imgdlg__close:hover {
    background-color: var(--ic-muted);
    color: var(--ic-foreground);
  }

  .ic-rte-imgdlg__body {
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .ic-rte-imgdlg__url-row {
    display: flex;
    gap: 4px;
  }

  .ic-rte-imgdlg__input {
    width: 100%;
    padding: 4px 8px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background-color: var(--ic-background);
    color: var(--ic-foreground);
    font-size: 12px;
    outline: none;
    box-sizing: border-box;
    flex: 1;
    min-width: 0;
  }

  .ic-rte-imgdlg__input:focus {
    border-color: var(--ic-primary);
  }

  .ic-rte-imgdlg__browse {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 26px;
    flex-shrink: 0;
    padding: 0;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
  }

  .ic-rte-imgdlg__browse:hover {
    background-color: var(--ic-muted);
    color: var(--ic-foreground);
  }

  .ic-rte-imgdlg__browse:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .ic-rte-imgdlg__error {
    font-size: 11px;
    color: var(--ic-destructive);
  }

  .ic-rte-imgdlg__submit {
    padding: 4px 12px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background-color: var(--ic-primary);
    color: var(--ic-primary-foreground);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
  }

  .ic-rte-imgdlg__submit:hover {
    opacity: 0.9;
  }

  .ic-rte-imgdlg__submit:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
