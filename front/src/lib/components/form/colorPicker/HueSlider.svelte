<script lang="ts">
  let {
    hue = $bindable(0),
    disabled = false,
    onchange,
  }: {
    hue?: number;
    disabled?: boolean;
    onchange?: () => void;
  } = $props();

  let trackEl: HTMLDivElement;
  let isDragging = $state(false);

  const percent = $derived((hue / 360) * 100);

  function getHueFromPointer(clientX: number): number {
    if (!trackEl) return hue;
    const rect = trackEl.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    return Math.round(ratio * 360);
  }

  function update(newHue: number) {
    if (newHue !== hue) {
      hue = newHue;
      onchange?.();
    }
  }

  function handlePointerDown(e: PointerEvent) {
    if (disabled) return;
    e.preventDefault();
    isDragging = true;
    update(getHueFromPointer(e.clientX));
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  }

  function handlePointerMove(e: PointerEvent) {
    update(getHueFromPointer(e.clientX));
  }

  function handlePointerUp() {
    isDragging = false;
    document.removeEventListener('pointermove', handlePointerMove);
    document.removeEventListener('pointerup', handlePointerUp);
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (disabled) return;
    const step = e.shiftKey ? 10 : 1;
    let newHue = hue;

    switch (e.key) {
      case 'ArrowRight':
      case 'ArrowUp':
        newHue = Math.min(360, hue + step);
        break;
      case 'ArrowLeft':
      case 'ArrowDown':
        newHue = Math.max(0, hue - step);
        break;
      case 'Home':
        newHue = 0;
        break;
      case 'End':
        newHue = 360;
        break;
      default:
        return;
    }

    e.preventDefault();
    update(newHue);
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ic-cp-hue">
  <span class="ic-cp-hue__label">H</span>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-cp-hue__track"
    bind:this={trackEl}
    onpointerdown={handlePointerDown}
  >
    <div
      class="ic-cp-hue__thumb"
      class:ic-cp-hue__thumb--dragging={isDragging}
      style="left: {percent}%"
      tabindex={disabled ? -1 : 0}
      onkeydown={handleKeyDown}
      role="slider"
      aria-valuenow={Math.round(hue)}
      aria-valuemin={0}
      aria-valuemax={360}
      aria-label="Hue"
    >
      <span class="ic-cp-hue__grip"></span>
    </div>
  </div>
</div>

<style>
  .ic-cp-hue {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .ic-cp-hue__label {
    font-size: 0.65rem;
    font-weight: 600;
    color: var(--ic-muted-foreground);
    width: 1.2ch;
    text-align: center;
    user-select: none;
  }

  .ic-cp-hue__track {
    position: relative;
    flex: 1;
    height: 12px;
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    cursor: pointer;
    touch-action: none;
    user-select: none;
    background: linear-gradient(to right,
      hsl(0, 100%, 50%),
      hsl(60, 100%, 50%),
      hsl(120, 100%, 50%),
      hsl(180, 100%, 50%),
      hsl(240, 100%, 50%),
      hsl(300, 100%, 50%),
      hsl(360, 100%, 50%)
    );
  }

  .ic-cp-hue__thumb {
    position: absolute;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 8px;
    height: 18px;
    border-radius: 2px;
    background-color: #fff;
    border: 1px solid rgba(0, 0, 0, 0.25);
    outline: none;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: box-shadow 0.1s ease;
    cursor: grab;
  }

  .ic-cp-hue__thumb:hover,
  .ic-cp-hue__thumb:focus-visible {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
  }

  .ic-cp-hue__thumb--dragging {
    cursor: grabbing;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
  }

  .ic-cp-hue__grip {
    display: block;
    width: 60%;
    height: 1px;
    background: rgba(0, 0, 0, 0.15);
    box-shadow: 0 2px 0 rgba(0, 0, 0, 0.15), 0 -2px 0 rgba(0, 0, 0, 0.15);
    pointer-events: none;
  }
</style>
