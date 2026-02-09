<script lang="ts">
  let {
    hue = 0,
    saturation = $bindable(100),
    valueBrightness = $bindable(100),
    disabled = false,
    onchange,
  }: {
    hue?: number;
    saturation?: number;
    valueBrightness?: number;
    disabled?: boolean;
    onchange?: () => void;
  } = $props();

  let padEl: HTMLDivElement;
  let isDragging = $state(false);

  const cursorX = $derived(saturation);
  const cursorY = $derived(100 - valueBrightness);

  const pureHueColor = $derived(`hsl(${hue}, 100%, 50%)`);

  function getSVFromPointer(clientX: number, clientY: number): { s: number; v: number } {
    if (!padEl) return { s: saturation, v: valueBrightness };
    const rect = padEl.getBoundingClientRect();
    const x = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    const y = Math.max(0, Math.min(1, (clientY - rect.top) / rect.height));
    return {
      s: Math.round(x * 100),
      v: Math.round((1 - y) * 100),
    };
  }

  function update(s: number, v: number) {
    if (s !== saturation || v !== valueBrightness) {
      saturation = s;
      valueBrightness = v;
      onchange?.();
    }
  }

  function handlePointerDown(e: PointerEvent) {
    if (disabled) return;
    e.preventDefault();
    isDragging = true;
    const { s, v } = getSVFromPointer(e.clientX, e.clientY);
    update(s, v);
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  }

  function handlePointerMove(e: PointerEvent) {
    const { s, v } = getSVFromPointer(e.clientX, e.clientY);
    update(s, v);
  }

  function handlePointerUp() {
    isDragging = false;
    document.removeEventListener('pointermove', handlePointerMove);
    document.removeEventListener('pointerup', handlePointerUp);
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (disabled) return;
    const step = e.shiftKey ? 10 : 1;
    let s = saturation;
    let v = valueBrightness;

    switch (e.key) {
      case 'ArrowRight': s = Math.min(100, s + step); break;
      case 'ArrowLeft': s = Math.max(0, s - step); break;
      case 'ArrowUp': v = Math.min(100, v + step); break;
      case 'ArrowDown': v = Math.max(0, v - step); break;
      default: return;
    }

    e.preventDefault();
    update(s, v);
  }
</script>

<div
  class="ic-cp-pad"
  class:ic-cp-pad--dragging={isDragging}
  bind:this={padEl}
  style="--cp-hue-color: {pureHueColor}"
  onpointerdown={handlePointerDown}
  onkeydown={handleKeyDown}
  tabindex={disabled ? -1 : 0}
  role="slider"
  aria-label="Saturation and brightness"
  aria-valuenow={saturation}
>
  <div class="ic-cp-pad__white"></div>
  <div class="ic-cp-pad__black"></div>
  <div
    class="ic-cp-pad__cursor"
    style="left: {cursorX}%; top: {cursorY}%"
  ></div>
</div>

<style>
  .ic-cp-pad {
    position: relative;
    width: 100%;
    aspect-ratio: 4 / 3;
    border-radius: 0;
    background-color: var(--cp-hue-color);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
    cursor: crosshair;
    touch-action: none;
    user-select: none;
    outline: none;
    overflow: hidden;
  }

  .ic-cp-pad:focus-visible {
    box-shadow:
      inset 0 1px 3px rgba(0, 0, 0, 0.15),
      0 0 0 1px var(--ic-primary);
  }

  .ic-cp-pad__white {
    position: absolute;
    inset: 0;
    background: linear-gradient(to right, #fff, transparent);
    border-radius: inherit;
  }

  .ic-cp-pad__black {
    position: absolute;
    inset: 0;
    background: linear-gradient(to bottom, transparent, #000);
    border-radius: inherit;
  }

  .ic-cp-pad__cursor {
    position: absolute;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    border: 2px solid #fff;
    box-shadow:
      0 0 0 1px rgba(0, 0, 0, 0.3),
      inset 0 0 0 1px rgba(0, 0, 0, 0.2);
    transform: translate(-50%, -50%);
    pointer-events: none;
  }

  .ic-cp-pad--dragging {
    cursor: crosshair;
  }
</style>
