<!--
  TileOverlay.svelte — Drop zone indicator for TileLayout.

  Rendered inside TileGroup's content area during drag.
  Shows which zone (center/top/bottom/left/right) will receive the tab.
-->
<script lang="ts">
  import type { DropZone } from './tile-types';

  let {
    zone = null as DropZone | null,
  }: {
    zone?: DropZone | null;
  } = $props();
</script>

{#if zone}
  <div
    class="ic-tl__overlay-zone"
    class:ic-tl__overlay-zone--center={zone === 'center'}
    class:ic-tl__overlay-zone--top={zone === 'top'}
    class:ic-tl__overlay-zone--bottom={zone === 'bottom'}
    class:ic-tl__overlay-zone--left={zone === 'left'}
    class:ic-tl__overlay-zone--right={zone === 'right'}
  ></div>
{/if}

<style>
  .ic-tl__overlay-zone {
    position: absolute;
    background-color: rgba(var(--ic-primary-rgb, 59, 130, 246), 0.10);
    border: 1px solid rgba(var(--ic-primary-rgb, 59, 130, 246), 0.30);
    pointer-events: none;
    z-index: 10;
    transition: all 0.08s ease;
  }

  /* Center: full content area */
  .ic-tl__overlay-zone--center {
    inset: 0;
  }

  /* Top: upper half */
  .ic-tl__overlay-zone--top {
    top: 0;
    left: 0;
    right: 0;
    height: 50%;
  }

  /* Bottom: lower half */
  .ic-tl__overlay-zone--bottom {
    bottom: 0;
    left: 0;
    right: 0;
    height: 50%;
  }

  /* Left: left half */
  .ic-tl__overlay-zone--left {
    top: 0;
    left: 0;
    bottom: 0;
    width: 50%;
  }

  /* Right: right half */
  .ic-tl__overlay-zone--right {
    top: 0;
    right: 0;
    bottom: 0;
    width: 50%;
  }
</style>
