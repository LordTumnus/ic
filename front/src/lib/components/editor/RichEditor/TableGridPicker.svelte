<script lang="ts">
  import type { Editor } from '@tiptap/core';

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

  let pickerEl = $state<HTMLDivElement>();
  let hoverRow = $state(0);
  let hoverCol = $state(0);

  const MAX = 10;
  const DEFAULT_ROWS = 6;
  const DEFAULT_COLS = 8;

  const visibleRows = $derived(Math.max(DEFAULT_ROWS, hoverRow + 1));
  const visibleCols = $derived(Math.max(DEFAULT_COLS, hoverCol + 1));

  function insertTable() {
    if (!editor || hoverRow === 0 || hoverCol === 0) return;
    editor
      .chain()
      .focus()
      .insertTable({ rows: hoverRow, cols: hoverCol, withHeaderRow: true })
      .run();
    close();
  }

  function close() {
    visible = false;
    hoverRow = 0;
    hoverCol = 0;
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
  <div
    class="ic-rte-tablepicker"
    style:left="{x}px"
    style:top="{y}px"
    bind:this={pickerEl}
    onmousedown={(e) => e.preventDefault()}
    onmouseleave={() => { hoverRow = 0; hoverCol = 0; }}
  >
    <div
      class="ic-rte-tablepicker__grid"
      style:grid-template-columns="repeat({Math.min(visibleCols, MAX)}, 18px)"
    >
      {#each Array(Math.min(visibleRows, MAX)) as _, ri}
        {#each Array(Math.min(visibleCols, MAX)) as _, ci}
          <!-- svelte-ignore a11y_consider_explicit_label -->
          <button
            class="ic-rte-tablepicker__cell"
            class:ic-rte-tablepicker__cell--active={ri < hoverRow && ci < hoverCol}
            onmouseenter={() => { hoverRow = ri + 1; hoverCol = ci + 1; }}
            onclick={insertTable}
          ></button>
        {/each}
      {/each}
    </div>
    <div class="ic-rte-tablepicker__label">
      {#if hoverRow > 0 && hoverCol > 0}
        {hoverCol} &times; {hoverRow}
      {:else}
        Insert table
      {/if}
    </div>
  </div>
{/if}

<style>
  .ic-rte-tablepicker {
    position: fixed;
    z-index: 40;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    padding: 8px;
  }

  .ic-rte-tablepicker__grid {
    display: grid;
    gap: 2px;
  }

  .ic-rte-tablepicker__cell {
    width: 18px;
    height: 18px;
    border: 1px solid var(--ic-border);
    border-radius: 1px;
    background-color: var(--ic-background);
    cursor: pointer;
    padding: 0;
    transition: background-color 0.05s ease, border-color 0.05s ease;
  }

  .ic-rte-tablepicker__cell--active {
    background-color: rgba(66, 133, 244, 0.18);
    border-color: var(--ic-primary);
  }

  .ic-rte-tablepicker__label {
    text-align: center;
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-muted-foreground);
    padding-top: 6px;
    min-height: 18px;
    font-variant-numeric: tabular-nums;
  }
</style>
