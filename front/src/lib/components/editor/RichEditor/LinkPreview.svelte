<script lang="ts">
  import type { Editor } from '@tiptap/core';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    editor,
    onEdit,
    onOpen,
  }: {
    editor: Editor;
    onEdit: (e: MouseEvent) => void;
    onOpen: (url: string) => void;
  } = $props();

  const icExternalLink = resolveIcon('external-link', 13);
  const icPencil = resolveIcon('pencil', 13);
  const icUnlink = resolveIcon('unlink', 13);

  let previewEl = $state<HTMLDivElement>();
  let visible = $state(false);
  let href = $state('');
  let posX = $state(0);
  let posY = $state(0);

  // Track cursor entering/leaving links
  $effect(() => {
    if (!editor) return;

    const onTransaction = () => {
      const isLink = editor.isActive('link');
      if (isLink) {
        const attrs = editor.getAttributes('link');
        href = attrs.href || '';
        if (!href) {
          visible = false;
          return;
        }
        // Find the link DOM element under cursor
        const { from } = editor.state.selection;
        const resolvedPos = editor.view.domAtPos(from);
        const domNode = resolvedPos.node as HTMLElement;
        const linkEl =
          domNode.nodeType === Node.ELEMENT_NODE
            ? (domNode as HTMLElement).closest('a')
            : domNode.parentElement?.closest('a');
        if (linkEl) {
          const rect = linkEl.getBoundingClientRect();
          posX = rect.left;
          posY = rect.bottom + 4;
        }
        visible = true;
      } else {
        visible = false;
      }
    };

    editor.on('transaction', onTransaction);
    return () => { editor.off('transaction', onTransaction); };
  });

  function handleOpen() {
    onOpen(href);
  }

  function handleEdit(e: MouseEvent) {
    visible = false;
    onEdit(e);
  }

  function handleUnlink() {
    editor.chain().focus().extendMarkRange('link').unsetLink().run();
    visible = false;
  }

  function truncateUrl(url: string, max = 35): string {
    if (url.length <= max) return url;
    return url.slice(0, max - 1) + '\u2026';
  }

  // Click-outside-to-close
  $effect(() => {
    if (!visible) return;
    const onMouseDown = (e: MouseEvent) => {
      if (previewEl && !previewEl.contains(e.target as Node)) {
        visible = false;
      }
    };
    const timer = setTimeout(() => window.addEventListener('mousedown', onMouseDown), 0);
    return () => {
      clearTimeout(timer);
      window.removeEventListener('mousedown', onMouseDown);
    };
  });
</script>

{#if visible && href}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-rte-linkprev"
    style:left="{posX}px"
    style:top="{posY}px"
    bind:this={previewEl}
    onmousedown={(e) => e.preventDefault()}
  >
    <span class="ic-rte-linkprev__url" title={href}>{truncateUrl(href)}</span>
    <div class="ic-rte-linkprev__sep"></div>
    <button class="ic-rte-linkprev__btn" onclick={handleOpen} title="Open link">
      {@html icExternalLink}
    </button>
    <button class="ic-rte-linkprev__btn" onclick={(e) => handleEdit(e)} title="Edit link">
      {@html icPencil}
    </button>
    <button class="ic-rte-linkprev__btn ic-rte-linkprev__btn--danger" onclick={handleUnlink} title="Remove link">
      {@html icUnlink}
    </button>
  </div>
{/if}

<style>
  .ic-rte-linkprev {
    position: fixed;
    z-index: 45;
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 3px 6px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
    font-size: 11px;
    white-space: nowrap;
  }

  .ic-rte-linkprev__url {
    color: var(--ic-primary);
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-rte-linkprev__sep {
    width: 1px;
    height: 14px;
    background-color: var(--ic-border);
    margin: 0 3px;
  }

  .ic-rte-linkprev__btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    padding: 0;
    border: 1px solid transparent;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    line-height: 0;
  }

  .ic-rte-linkprev__btn:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
  }

  .ic-rte-linkprev__btn--danger:hover {
    color: var(--ic-destructive);
    background-color: rgba(239, 68, 68, 0.08);
  }
</style>
