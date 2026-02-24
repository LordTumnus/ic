<script lang="ts">
  let {
    alpha = $bindable(1),
    color = 'hsl(0, 100%, 50%)',
    disabled = false,
    onchange,
  }: {
    alpha?: number;
    color?: string;
    disabled?: boolean;
    onchange?: () => void;
  } = $props();

  let trackEl: HTMLDivElement;
  let isDragging = $state(false);

  const percent = $derived(alpha * 100);

  function getAlphaFromPointer(clientX: number): number {
    if (!trackEl) return alpha;
    const rect = trackEl.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    return Math.round(ratio * 100) / 100;
  }

  function update(newAlpha: number) {
    if (newAlpha !== alpha) {
      alpha = newAlpha;
      onchange?.();
    }
  }

  function handlePointerDown(e: PointerEvent) {
    if (disabled) return;
    e.preventDefault();
    isDragging = true;
    update(getAlphaFromPointer(e.clientX));
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  }

  function handlePointerMove(e: PointerEvent) {
    update(getAlphaFromPointer(e.clientX));
  }

  function handlePointerUp() {
    isDragging = false;
    document.removeEventListener('pointermove', handlePointerMove);
    document.removeEventListener('pointerup', handlePointerUp);
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (disabled) return;
    const step = e.shiftKey ? 0.1 : 0.01;
    let newAlpha = alpha;

    switch (e.key) {
      case 'ArrowRight':
      case 'ArrowUp':
        newAlpha = Math.min(1, Math.round((alpha + step) * 100) / 100);
        break;
      case 'ArrowLeft':
      case 'ArrowDown':
        newAlpha = Math.max(0, Math.round((alpha - step) * 100) / 100);
        break;
      case 'Home':
        newAlpha = 0;
        break;
      case 'End':
        newAlpha = 1;
        break;
      default:
        return;
    }

    e.preventDefault();
    update(newAlpha);
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ic-cp-alpha">
  <span class="ic-cp-alpha__label">A</span>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-cp-alpha__track"
    bind:this={trackEl}
    onpointerdown={handlePointerDown}
  >
    <div class="ic-cp-alpha__checker"></div>
    <div
      class="ic-cp-alpha__gradient"
      style="background: linear-gradient(to right, transparent, {color})"
    ></div>
    <div
      class="ic-cp-alpha__thumb"
      class:ic-cp-alpha__thumb--dragging={isDragging}
      style="left: {percent}%"
      tabindex={disabled ? -1 : 0}
      onkeydown={handleKeyDown}
      role="slider"
      aria-valuenow={alpha}
      aria-valuemin={0}
      aria-valuemax={1}
      aria-label="Alpha"
    >
      <span class="ic-cp-alpha__grip"></span>
    </div>
  </div>
</div>

<style>
  .ic-cp-alpha {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .ic-cp-alpha__label {
    font-size: 0.65rem;
    font-weight: 600;
    color: var(--ic-muted-foreground);
    width: 1.2ch;
    text-align: center;
    user-select: none;
  }

  .ic-cp-alpha__track {
    position: relative;
    flex: 1;
    height: 12px;
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    cursor: pointer;
    touch-action: none;
    user-select: none;
    overflow: hidden;
  }

  .ic-cp-alpha__checker {
    position: absolute;
    inset: 0;
    border-radius: inherit;
    background-image:
      linear-gradient(45deg, #ccc 25%, transparent 25%),
      linear-gradient(-45deg, #ccc 25%, transparent 25%),
      linear-gradient(45deg, transparent 75%, #ccc 75%),
      linear-gradient(-45deg, transparent 75%, #ccc 75%);
    background-size: 8px 8px;
    background-position: 0 0, 0 4px, 4px -4px, -4px 0px;
  }

  .ic-cp-alpha__gradient {
    position: absolute;
    inset: 0;
    border-radius: inherit;
  }

  .ic-cp-alpha__thumb {
    position: absolute;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 8px;
    height: 18px;
    border-radius: 2px;
    background-color: #fff;
    border: 1px solid rgba(0, 0, 0, 0.25);
    outline: none;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: box-shadow 0.1s ease;
    cursor: grab;
    z-index: 1;
  }

  .ic-cp-alpha__thumb:hover,
  .ic-cp-alpha__thumb:focus-visible {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
  }

  .ic-cp-alpha__thumb--dragging {
    cursor: grabbing;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
  }

  .ic-cp-alpha__grip {
    display: block;
    width: 60%;
    height: 1px;
    background: rgba(0, 0, 0, 0.15);
    box-shadow: 0 2px 0 rgba(0, 0, 0, 0.15), 0 -2px 0 rgba(0, 0, 0, 0.15);
    pointer-events: none;
  }
</style>
