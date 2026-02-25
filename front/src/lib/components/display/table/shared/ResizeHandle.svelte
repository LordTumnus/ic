<script lang="ts">
  let {
    onresize,
    onresizeend,
  }: {
    onresize?: (delta: number) => void;
    onresizeend?: () => void;
  } = $props();

  let dragging = $state(false);
  let startX = 0;

  function handlePointerDown(e: PointerEvent) {
    e.stopPropagation();
    e.preventDefault();
    dragging = true;
    startX = e.clientX;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  }

  function handlePointerMove(e: PointerEvent) {
    if (!dragging) return;
    const delta = e.clientX - startX;
    startX = e.clientX;
    onresize?.(delta);
  }

  function handlePointerUp(e: PointerEvent) {
    if (!dragging) return;
    dragging = false;
    (e.target as HTMLElement).releasePointerCapture(e.pointerId);
    onresizeend?.();
  }
</script>

<div
  class="ic-tbl__resize"
  class:ic-tbl__resize--active={dragging}
  onpointerdown={handlePointerDown}
  onpointermove={handlePointerMove}
  onpointerup={handlePointerUp}
  role="separator"
  aria-orientation="vertical"
></div>

<style>
  .ic-tbl__resize {
    position: absolute;
    right: -2px;
    top: 2px;
    bottom: 2px;
    width: 5px;
    cursor: col-resize;
    z-index: 3;
    user-select: none;
    touch-action: none;
    border-radius: 1px;
  }
  .ic-tbl__resize:hover {
    background: rgba(0, 0, 0, 0.08);
    box-shadow: inset 1px 0 0 rgba(0, 0, 0, 0.1), inset -1px 0 0 rgba(0, 0, 0, 0.1);
  }
  .ic-tbl__resize--active {
    background: var(--ic-primary);
    opacity: 0.4;
    box-shadow: none;
  }
</style>
