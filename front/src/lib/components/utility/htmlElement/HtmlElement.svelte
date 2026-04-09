<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution, ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    tag = $bindable('div'),
    innerText = $bindable(''),
    innerHTML = $bindable(''),
    className = $bindable(''),
    title: titleAttr = $bindable(''),
    hidden = $bindable(false),
    childEntries = [] as ChildEntries,
    clicked,
    doubleClicked,
    mouseEntered,
    mouseLeft,
    contextMenuOpened,
    keyPressed,
    focusGained,
    focusLost,
    scrolled,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
    blur = $bindable((): Resolution => ({ success: true, data: null })),
    click: clickMethod = $bindable((): Resolution => ({ success: true, data: null })),
    scrollIntoView = $bindable((): Resolution => ({ success: true, data: null })),
    setAttribute: setAttributeMethod = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
    removeAttribute: removeAttributeMethod = $bindable((_data?: unknown): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    tag?: string;
    innerText?: string;
    innerHTML?: string;
    className?: string;
    title?: string;
    hidden?: boolean;
    childEntries?: ChildEntries;
    clicked?: (data?: unknown) => void;
    doubleClicked?: (data?: unknown) => void;
    mouseEntered?: (data?: unknown) => void;
    mouseLeft?: (data?: unknown) => void;
    contextMenuOpened?: (data?: unknown) => void;
    keyPressed?: (data?: unknown) => void;
    focusGained?: (data?: unknown) => void;
    focusLost?: (data?: unknown) => void;
    scrolled?: (data?: unknown) => void;
    focus?: () => Resolution;
    blur?: () => Resolution;
    click?: () => Resolution;
    scrollIntoView?: () => Resolution;
    setAttribute?: (data?: unknown) => Resolution;
    removeAttribute?: (data?: unknown) => Resolution;
  } = $props();

  let elRef: Element;

  const hasInnerHTML = $derived(innerHTML !== '');

  onMount(() => {
    focus = (): Resolution => {
      (elRef as HTMLElement)?.focus();
      return { success: true, data: null };
    };

    blur = (): Resolution => {
      (elRef as HTMLElement)?.blur();
      return { success: true, data: null };
    };

    clickMethod = (): Resolution => {
      (elRef as HTMLElement)?.click();
      return { success: true, data: null };
    };

    scrollIntoView = (): Resolution => {
      elRef?.scrollIntoView({ behavior: 'smooth' });
      return { success: true, data: null };
    };

    setAttributeMethod = (data?: unknown): Resolution => {
      const d = data as { name: string; value: string };
      if (d?.name) {
        elRef?.setAttribute(d.name, d.value ?? '');
      }
      return { success: true, data: null };
    };

    removeAttributeMethod = (data?: unknown): Resolution => {
      const d = data as { name: string };
      if (d?.name) {
        elRef?.removeAttribute(d.name);
      }
      return { success: true, data: null };
    };
  });

  function handleClick() {
    clicked?.({ timestamp: Date.now() });
  }

  function handleDblClick() {
    doubleClicked?.({ timestamp: Date.now() });
  }

  function handleMouseEnter() {
    mouseEntered?.();
  }

  function handleMouseLeave() {
    mouseLeft?.();
  }

  function handleContextMenu(e: MouseEvent) {
    contextMenuOpened?.({ x: e.clientX, y: e.clientY });
  }

  function handleKeyDown(e: KeyboardEvent) {
    keyPressed?.({
      key: e.key,
      code: e.code,
      shiftKey: e.shiftKey,
      ctrlKey: e.ctrlKey,
      altKey: e.altKey,
      metaKey: e.metaKey,
    });
  }

  function handleFocus() {
    focusGained?.();
  }

  function handleBlur() {
    focusLost?.();
  }

  function handleScroll() {
    const el = elRef as HTMLElement;
    scrolled?.({
      scrollTop: el?.scrollTop ?? 0,
      scrollLeft: el?.scrollLeft ?? 0,
    });
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<svelte:element this={tag}
  {id}
  bind:this={elRef}
  class="ic-el {className}"
  title={titleAttr}
  {hidden}
  onclick={handleClick}
  ondblclick={handleDblClick}
  onmouseenter={handleMouseEnter}
  onmouseleave={handleMouseLeave}
  oncontextmenu={handleContextMenu}
  onkeydown={handleKeyDown}
  onfocus={handleFocus}
  onblur={handleBlur}
  onscroll={handleScroll}
>
  {#if hasInnerHTML}
    {@html innerHTML}
  {:else}
    {innerText}
    {#each childEntries as child (child.id)}
      <DynamicChild entry={child} />
    {/each}
  {/if}
</svelte:element>

