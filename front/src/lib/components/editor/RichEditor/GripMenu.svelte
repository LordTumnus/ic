<script lang="ts">
  import type { Editor } from '@tiptap/core';
  import type { GripMenuEvent } from './BlockGrip';
  import { resolveIcon } from '$lib/utils/icons';

  let {
    editor,
    visible = $bindable(false),
    event = $bindable<GripMenuEvent | null>(null),
  }: {
    editor: Editor | null;
    visible?: boolean;
    event?: GripMenuEvent | null;
  } = $props();

  const icons = {
    arrowUp: resolveIcon('arrow-up', 14),
    arrowDown: resolveIcon('arrow-down', 14),
    copy: resolveIcon('copy', 14),
    trash: resolveIcon('trash-2', 14),
    pilcrow: resolveIcon('pilcrow', 14),
    h1: resolveIcon('heading-1', 14),
    h2: resolveIcon('heading-2', 14),
    h3: resolveIcon('heading-3', 14),
    list: resolveIcon('list', 14),
    listOrdered: resolveIcon('list-ordered', 14),
    quote: resolveIcon('quote', 14),
    info: resolveIcon('info', 14),
    code: resolveIcon('code-2', 14),
    chevronRight: resolveIcon('chevron-right', 12),
  };

  let turnIntoOpen = $state(false);
  let menuEl = $state<HTMLDivElement>();

  // Flip submenu to left when main menu is near right edge
  const submenuFlipLeft = $derived(menuX + 150 + 160 > window.innerWidth);

  // Smart positioning: prefer left of grip, flip right if near left edge
  const menuX = $derived.by(() => {
    if (!event) return 0;
    const w = 150;
    const gap = 4;
    let x = event.left - w - 10; // left of grip
    if (x < gap) x = event.left + 20; // flip to right
    if (x + w > window.innerWidth - gap) x = window.innerWidth - w - gap;
    return x;
  });
  const menuY = $derived.by(() => {
    if (!event) return 0;
    const h = 250; // approximate total height
    const gap = 4;
    let y = event.top;
    if (y + h > window.innerHeight - gap) y = Math.max(gap, window.innerHeight - h - gap);
    return y;
  });

  // Click-outside-to-close
  $effect(() => {
    if (!visible) return;
    const onMouseDown = (e: MouseEvent) => {
      if (menuEl && !menuEl.contains(e.target as Node)) {
        close();
      }
    };
    const timer = setTimeout(() => window.addEventListener('mousedown', onMouseDown), 0);
    return () => {
      clearTimeout(timer);
      window.removeEventListener('mousedown', onMouseDown);
    };
  });

  function close() {
    visible = false;
    turnIntoOpen = false;
    event = null;
  }

  function moveUp() {
    if (!editor || !event) return;
    const { pos } = event;
    const resolved = editor.state.doc.resolve(pos);
    if (resolved.index(0) === 0) { close(); return; }
    const prevNode = editor.state.doc.child(resolved.index(0) - 1);
    const prevPos = pos - prevNode.nodeSize;

    const node = editor.state.doc.nodeAt(pos);
    if (!node) { close(); return; }

    editor.chain()
      .command(({ tr }) => {
        const slice = editor!.state.doc.slice(pos, pos + node.nodeSize);
        tr.delete(pos, pos + node.nodeSize);
        tr.insert(prevPos, slice.content);
        return true;
      })
      .run();
    close();
  }

  function moveDown() {
    if (!editor || !event) return;
    const { pos } = event;
    const node = editor.state.doc.nodeAt(pos);
    if (!node) { close(); return; }

    const resolved = editor.state.doc.resolve(pos);
    if (resolved.index(0) >= editor.state.doc.childCount - 1) { close(); return; }
    const nextNode = editor.state.doc.child(resolved.index(0) + 1);
    const nextEnd = pos + node.nodeSize + nextNode.nodeSize;

    editor.chain()
      .command(({ tr }) => {
        const slice = editor!.state.doc.slice(pos, pos + node.nodeSize);
        tr.insert(nextEnd, slice.content);
        tr.delete(pos, pos + node.nodeSize);
        return true;
      })
      .run();
    close();
  }

  function duplicate() {
    if (!editor || !event) return;
    const { pos } = event;
    const node = editor.state.doc.nodeAt(pos);
    if (!node) { close(); return; }
    const endPos = pos + node.nodeSize;

    editor.chain()
      .command(({ tr }) => {
        const slice = editor!.state.doc.slice(pos, endPos);
        tr.insert(endPos, slice.content);
        return true;
      })
      .run();
    close();
  }

  function deleteBlock() {
    if (!editor || !event) return;
    const { pos } = event;
    const node = editor.state.doc.nodeAt(pos);
    if (!node) { close(); return; }

    editor.chain()
      .command(({ tr }) => {
        tr.delete(pos, pos + node.nodeSize);
        return true;
      })
      .run();
    close();
  }

  function turnInto(type: string, attrs?: Record<string, unknown>) {
    if (!editor || !event) return;
    const { pos } = event;
    const node = editor.state.doc.nodeAt(pos);
    if (!node) { close(); return; }

    // Select the block, then convert
    editor.chain()
      .setTextSelection({ from: pos + 1, to: pos + node.nodeSize - 1 })
      .run();

    switch (type) {
      case 'paragraph': editor.chain().focus().setParagraph().run(); break;
      case 'heading': editor.chain().focus().setHeading(attrs as { level: 1|2|3 }).run(); break;
      case 'bulletList': editor.chain().focus().toggleBulletList().run(); break;
      case 'orderedList': editor.chain().focus().toggleOrderedList().run(); break;
      case 'blockquote': editor.chain().focus().toggleBlockquote().run(); break;
      case 'codeBlock': editor.chain().focus().toggleCodeBlock().run(); break;
      case 'callout': editor.chain().focus().setCallout({ type: 'info' }).run(); break;
    }
    close();
  }
</script>

{#if visible && event}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-rte-gripmenu"
    style:top="{menuY}px"
    style:left="{menuX}px"
    bind:this={menuEl}
    onmouseleave={close}
  >
    <button class="ic-rte-gripmenu__item" onclick={moveUp}>
      {@html icons.arrowUp} Move Up
    </button>
    <button class="ic-rte-gripmenu__item" onclick={moveDown}>
      {@html icons.arrowDown} Move Down
    </button>
    <button class="ic-rte-gripmenu__item" onclick={duplicate}>
      {@html icons.copy} Duplicate
    </button>
    <button class="ic-rte-gripmenu__item ic-rte-gripmenu__item--danger" onclick={deleteBlock}>
      {@html icons.trash} Delete
    </button>

    <div class="ic-rte-gripmenu__sep"></div>

    <!-- Turn Into submenu -->
    <div class="ic-rte-gripmenu__submenu-wrap">
      <button
        class="ic-rte-gripmenu__item"
        onmouseenter={() => { turnIntoOpen = true; }}
      >
        Turn Into {@html icons.chevronRight}
      </button>
      {#if turnIntoOpen}
        <div class="ic-rte-gripmenu__submenu" class:ic-rte-gripmenu__submenu--left={submenuFlipLeft} onmouseleave={() => { turnIntoOpen = false; }}>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('paragraph')}>
            {@html icons.pilcrow} Paragraph
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('heading', { level: 1 })}>
            {@html icons.h1} Heading 1
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('heading', { level: 2 })}>
            {@html icons.h2} Heading 2
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('heading', { level: 3 })}>
            {@html icons.h3} Heading 3
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('bulletList')}>
            {@html icons.list} Bullet List
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('orderedList')}>
            {@html icons.listOrdered} Ordered List
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('blockquote')}>
            {@html icons.quote} Blockquote
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('callout')}>
            {@html icons.info} Callout
          </button>
          <button class="ic-rte-gripmenu__item" onclick={() => turnInto('codeBlock')}>
            {@html icons.code} Code Block
          </button>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .ic-rte-gripmenu {
    position: fixed;
    z-index: 40;
    min-width: 150px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    padding: 4px;
  }

  .ic-rte-gripmenu__item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 5px 8px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-foreground);
    font-size: 12px;
    cursor: pointer;
    text-align: left;
    white-space: nowrap;
  }

  .ic-rte-gripmenu__item:hover {
    background-color: var(--ic-muted);
  }

  .ic-rte-gripmenu__item--danger {
    color: var(--ic-destructive);
  }

  .ic-rte-gripmenu__sep {
    height: 1px;
    background-color: var(--ic-border);
    margin: 3px 4px;
  }

  .ic-rte-gripmenu__submenu-wrap {
    position: relative;
  }

  .ic-rte-gripmenu__submenu {
    position: absolute;
    left: 100%;
    top: -4px;
    min-width: 150px;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    padding: 4px;
  }

  .ic-rte-gripmenu__submenu--left {
    left: auto;
    right: 100%;
  }
</style>
