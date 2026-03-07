<script lang="ts">
  import type { Editor } from '@tiptap/core';

  let {
    editor,
    visible = true,
  }: {
    editor: Editor | null;
    visible?: boolean;
  } = $props();

  interface TOCItem {
    level: number;
    text: string;
    pos: number;
    id: string;
  }

  let hovered = $state(false);
  let tocItems = $state<TOCItem[]>([]);
  let activeId = $state('');
  let scrollProgress = $state(0);
  let clickLockUntil = 0; // timestamp — suppress scroll detection after click

  // Extract headings from editor document
  $effect(() => {
    if (!editor) return;
    const updateToc = () => {
      const items: TOCItem[] = [];
      editor!.state.doc.descendants((node, pos) => {
        if (node.type.name === 'heading') {
          const level = node.attrs.level as number;
          const text = node.textContent;
          const id = `heading-${pos}`;
          items.push({ level, text, pos, id });
        }
      });
      tocItems = items;
    };

    editor.on('update', updateToc);
    updateToc();
    return () => { editor!.off('update', updateToc); };
  });

  // Track scroll position for active heading + progress bar
  function handleEditorScroll(e: Event) {
    const target = e.target as HTMLElement;
    if (!target || !editor) return;

    const { scrollTop, scrollHeight, clientHeight } = target;
    scrollProgress = scrollHeight > clientHeight
      ? scrollTop / (scrollHeight - clientHeight)
      : 0;

    // Skip active detection if a click-scroll is still settling
    if (Date.now() < clickLockUntil) return;

    // Find the heading closest to the top of the editor container
    const editorRect = target.getBoundingClientRect();
    let closestId = '';
    for (const item of tocItems) {
      const coords = editor!.view.coordsAtPos(item.pos);
      // Convert viewport-relative to editor-relative
      const relTop = coords.top - editorRect.top;
      if (relTop <= 20) {
        closestId = item.id;
      }
    }
    // If no heading scrolled past yet, highlight the first one
    if (!closestId && tocItems.length > 0) {
      closestId = tocItems[0].id;
    }
    activeId = closestId;
  }

  // Scroll editor to heading position
  function scrollToHeading(item: TOCItem) {
    if (!editor) return;
    activeId = item.id;
    clickLockUntil = Date.now() + 300; // suppress scroll detection for 300ms
    editor.commands.setTextSelection(item.pos);
    const coords = editor.view.coordsAtPos(item.pos);
    const editorEl = editor.view.dom.closest('.ic-rte__editor');
    if (editorEl) {
      const editorRect = editorEl.getBoundingClientRect();
      editorEl.scrollTo({
        top: editorEl.scrollTop + coords.top - editorRect.top - 20,
        behavior: 'instant',
      });
    }
  }

  // Export the scroll handler so parent can attach it
  export { handleEditorScroll };
</script>

{#if visible}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-rte-toc"
    class:ic-rte-toc--visible={hovered}
    onmouseenter={() => { hovered = true; }}
    onmouseleave={() => { hovered = false; }}
  >
    <!-- Hover trigger strip -->
    <div class="ic-rte-toc__trigger"></div>

    <!-- Content panel -->
    <div class="ic-rte-toc__panel">
      <div class="ic-rte-toc__title">Contents</div>

      <div class="ic-rte-toc__list">
        {#each tocItems as item}
          <button
            class="ic-rte-toc__item"
            class:ic-rte-toc__item--active={item.id === activeId}
            style:padding-left="{(item.level - 1) * 8 + 8}px"
            onclick={() => scrollToHeading(item)}
          >
            {item.text}
          </button>
        {/each}
        {#if tocItems.length === 0}
          <div class="ic-rte-toc__empty">No headings</div>
        {/if}
      </div>

      <!-- Scroll progress bar -->
      <div class="ic-rte-toc__progress">
        <div class="ic-rte-toc__progress-track">
          <div class="ic-rte-toc__progress-fill" style:width="{scrollProgress * 100}%"></div>
          <!-- Graduation marks at heading positions -->
          {#each tocItems as item, i}
            <div
              class="ic-rte-toc__progress-tick"
              style:left="{(i / Math.max(tocItems.length - 1, 1)) * 100}%"
            ></div>
          {/each}
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .ic-rte-toc {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    width: 8px; /* Trigger strip width */
    z-index: 10;
    display: flex;
    align-items: stretch;
    pointer-events: auto;
  }

  .ic-rte-toc__trigger {
    width: 8px;
    flex-shrink: 0;
    cursor: pointer;
  }

  .ic-rte-toc__panel {
    position: absolute;
    right: 0;
    top: 0;
    bottom: 0;
    width: 180px;
    background-color: var(--ic-surface, var(--ic-background));
    border-left: 1px solid var(--ic-border);
    box-shadow: -2px 0 8px rgba(0, 0, 0, 0.08);
    display: flex;
    flex-direction: column;
    padding: 8px 0;
    transform: translateX(100%);
    transition: transform 0.2s ease;
    overflow: hidden;
  }

  .ic-rte-toc--visible .ic-rte-toc__panel {
    transform: translateX(0);
  }

  .ic-rte-toc__title {
    padding: 4px 12px 8px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--ic-muted-foreground);
    user-select: none;
  }

  .ic-rte-toc__list {
    flex: 1;
    overflow-y: auto;
  }

  .ic-rte-toc__item {
    display: block;
    width: 100%;
    padding: 3px 12px 3px 8px;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    font-size: 11px;
    text-align: left;
    cursor: pointer;
    border-left: 2px solid transparent;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-rte-toc__item:hover {
    color: var(--ic-foreground);
    background-color: var(--ic-muted);
  }

  .ic-rte-toc__item--active {
    color: var(--ic-primary);
    border-left-color: var(--ic-primary);
    font-weight: 600;
  }

  .ic-rte-toc__empty {
    padding: 12px;
    font-size: 11px;
    color: var(--ic-muted-foreground);
    text-align: center;
  }

  /* ── Progress bar ───────────────────────────── */
  .ic-rte-toc__progress {
    padding: 8px 12px 4px;
  }

  .ic-rte-toc__progress-track {
    position: relative;
    height: 3px;
    background-color: var(--ic-border);
    border-radius: 2px;
    box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.1);
    overflow: visible;
  }

  .ic-rte-toc__progress-fill {
    position: absolute;
    left: 0;
    top: 0;
    height: 100%;
    background-color: var(--ic-primary);
    border-radius: 2px;
    transition: width 0.1s ease;
  }

  .ic-rte-toc__progress-tick {
    position: absolute;
    top: -2px;
    width: 1px;
    height: 7px;
    background-color: var(--ic-muted-foreground);
    opacity: 0.4;
  }
</style>
