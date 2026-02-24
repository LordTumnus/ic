<script lang="ts">
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import ContextMenuPanel from './ContextMenuPanel.svelte';

  let {
    entries,
    x,
    y,
    onaction,
    onclose,
  }: {
    entries: ContextMenuEntry[];
    x: number;
    y: number;
    onaction: (key: string) => void;
    onclose: () => void;
  } = $props();

  // Global listeners: click-outside, Escape, scroll → close
  $effect(() => {
    function handlePointerDown(e: PointerEvent) {
      // Click outside the menu panels → close
      const target = e.target as HTMLElement;
      if (!target.closest('.ic-ctx__panel')) {
        onclose();
      }
    }
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault();
        onclose();
      }
    }
    function handleScroll() {
      onclose();
    }

    window.addEventListener('pointerdown', handlePointerDown, true);
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('scroll', handleScroll, true);

    return () => {
      window.removeEventListener('pointerdown', handlePointerDown, true);
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('scroll', handleScroll, true);
    };
  });
</script>

<ContextMenuPanel {entries} {x} {y} {onaction} {onclose} />
