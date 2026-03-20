<!--
  NoteNode.svelte — Sticky note annotation node.
  Resizable, colored, with editable text content. No ports.
-->
<script lang="ts">
  import { NodeResizer, type NodeProps, type Node } from '@xyflow/svelte';

  type NoteData = {
    content: string;
    color: string;
    width: number;
    height: number;
    disabled: boolean;
    locked: boolean;
    onNodeResize?: (nodeId: string, width: number, height: number) => void;
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type NoteNodeType = Node<NoteData, 'ic.node.Note'>;

  let { id, data, selected, dragging }: NodeProps<NoteNodeType> = $props();

  let hovered = $state(false);
  let editing = $state(false);
  let editText = $state('');

  const bgColor = $derived(data.color || '#fef9c3');

  function startEdit(e: MouseEvent) {
    e.stopPropagation();
    editText = data.content || '';
    editing = true;
    // Focus the textarea on next tick
    requestAnimationFrame(() => {
      const el = document.querySelector(`[data-note-id="${id}"] textarea`) as HTMLTextAreaElement;
      el?.focus();
    });
  }

  function commitEdit() {
    editing = false;
    if (editText !== data.content) {
      data.onpropchange?.('content', editText);
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      editing = false;
    }
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-note"
  class:ic-ne-note--selected={selected}
  class:ic-ne-note--dragging={dragging}
  data-note-id={id}
  style:--note-bg={bgColor}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <NodeResizer
    minWidth={80}
    minHeight={40}
    isVisible={selected}
    lineClass="ic-ne-note__resize-line"
    handleClass="ic-ne-note__resize-handle"
    onResizeEnd={(_e, params) => data.onNodeResize?.(id, params.width, params.height)}
  />

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  {#if editing}
    <textarea
      class="ic-ne-note__textarea nodrag"
      bind:value={editText}
      onblur={commitEdit}
      onkeydown={handleKeydown}
    ></textarea>
  {:else}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="ic-ne-note__content" ondblclick={startEdit}>
      {#if data.content}
        {data.content}
      {:else}
        <span class="ic-ne-note__placeholder">Double-click to edit...</span>
      {/if}
    </div>
  {/if}

  <!-- Fold corner -->
  <svg class="ic-ne-note__fold" viewBox="0 0 12 12">
    <path d="M 0 0 L 12 0 L 0 12 Z" fill="rgba(0,0,0,0.08)" />
  </svg>
</div>

<style>
  .ic-ne-note {
    position: relative;
    width: 100%;
    height: 100%;
    background: var(--note-bg);
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 1px;
    font-family: var(--ic-font-family);
    font-size: 12px;
    color: rgba(0, 0, 0, 0.75);
    box-shadow: 1px 2px 4px rgba(0, 0, 0, 0.1);
    transition: box-shadow 0.15s ease;
    overflow: clip;
  }

  .ic-ne-note--selected {
    border-color: var(--ic-primary);
    box-shadow: 0 0 0 1px var(--ic-primary), 1px 2px 6px rgba(0, 0, 0, 0.15);
  }

  .ic-ne-note--dragging {
    box-shadow: 2px 4px 12px rgba(0, 0, 0, 0.25);
  }

  .ic-ne-note__content {
    padding: 8px 10px;
    white-space: pre-wrap;
    word-break: break-word;
    width: 100%;
    height: 100%;
    cursor: text;
    line-height: 1.4;
    box-sizing: border-box;
  }

  .ic-ne-note__placeholder {
    color: rgba(0, 0, 0, 0.3);
    font-style: italic;
  }

  .ic-ne-note__textarea {
    width: 100%;
    height: 100%;
    padding: 8px 10px;
    border: none;
    background: transparent;
    font-family: var(--ic-font-family);
    font-size: 12px;
    color: rgba(0, 0, 0, 0.75);
    line-height: 1.4;
    resize: none;
    outline: none;
    box-sizing: border-box;
  }

  .ic-ne-note__fold {
    position: absolute;
    top: 0;
    right: 0;
    width: 12px;
    height: 12px;
    pointer-events: none;
  }

  /* Resize handles */
  .ic-ne-note :global(.ic-ne-note__resize-line) {
    border-color: transparent;
  }

  .ic-ne-note :global(.ic-ne-note__resize-handle) {
    width: 6px;
    height: 6px;
    background: transparent;
    border: 2px solid rgba(0, 0, 0, 0.25);
    border-radius: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, border-color 0.15s ease;
  }

  .ic-ne-note :global(.ic-ne-note__resize-handle:hover) {
    border-color: var(--ic-primary);
    opacity: 1;
  }

  .ic-ne-note :global(.ic-ne-note__resize-handle.top.left) {
    border-right: none; border-bottom: none;
  }
  .ic-ne-note :global(.ic-ne-note__resize-handle.top.right) {
    border-left: none; border-bottom: none;
  }
  .ic-ne-note :global(.ic-ne-note__resize-handle.bottom.left) {
    border-right: none; border-top: none;
  }
  .ic-ne-note :global(.ic-ne-note__resize-handle.bottom.right) {
    border-left: none; border-top: none;
  }
</style>
