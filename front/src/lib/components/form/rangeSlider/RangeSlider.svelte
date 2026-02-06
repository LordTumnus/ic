<script lang="ts">
  import type { Resolution } from '$lib/types';

  let {
    low = $bindable(0),
    high = $bindable(100),
    min = $bindable(0),
    max = $bindable(100),
    step = $bindable(1),
    disabled = $bindable(false),
    orientation = $bindable('horizontal'),
    showValue = $bindable(false),
    labelPosition = $bindable('top'),
    size = $bindable('md'),
    variant = $bindable('primary'),
    thumb = $bindable('fader'),
    showTicks = $bindable(false),
    tickInterval = $bindable(0),
    lowChanging,
    highChanging,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    low?: number;
    high?: number;
    min?: number;
    max?: number;
    step?: number;
    disabled?: boolean;
    orientation?: string;
    showValue?: boolean;
    labelPosition?: string;
    size?: string;
    variant?: string;
    thumb?: string;
    showTicks?: boolean;
    tickInterval?: number;
    lowChanging?: (data?: unknown) => void;
    highChanging?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  let trackEl: HTMLDivElement;
  let thumbLowEl: HTMLDivElement;
  let thumbHighEl: HTMLDivElement;
  let dragging = $state<'low' | 'high' | null>(null);

  const decimals = $derived(step % 1 === 0 ? 0 : (step.toString().split('.')[1]?.length ?? 0));
  const displayLow = $derived(low.toFixed(decimals));
  const displayHigh = $derived(high.toFixed(decimals));

  const percentLow = $derived(
    max !== min ? ((low - min) / (max - min)) * 100 : 0
  );
  const percentHigh = $derived(
    max !== min ? ((high - min) / (max - min)) * 100 : 0
  );

  const isVertical = $derived(orientation === 'vertical');
  const isSideLabel = $derived(labelPosition === 'side');

  // Fixed label width from the widest possible value string
  const labelWidth = $derived.by(() => {
    const dec = step % 1 === 0 ? 0 : (step.toString().split('.')[1]?.length ?? 0);
    const longest = [min, max].reduce((a, b) =>
      b.toFixed(dec).length > a.toFixed(dec).length ? b : a
    );
    return longest.toFixed(dec).length;
  });

  // Tick mark positions as percentages
  const ticks = $derived.by(() => {
    if (!showTicks) return [];
    const interval = tickInterval > 0 ? tickInterval : step;
    const count = Math.round((max - min) / interval);
    if (count > 200 || count < 1) return [];
    const result: number[] = [];
    for (let i = 0; i <= count; i++) {
      result.push(((i * interval) / (max - min)) * 100);
    }
    return result;
  });

  function snapToStep(raw: number): number {
    const stepped = Math.round((raw - min) / step) * step + min;
    return Math.min(max, Math.max(min, Number(stepped.toFixed(10))));
  }

  function getValueFromPointer(clientX: number, clientY: number): number {
    if (!trackEl) return low;
    const rect = trackEl.getBoundingClientRect();
    let ratio: number;
    if (isVertical) {
      ratio = 1 - (clientY - rect.top) / rect.height;
    } else {
      ratio = (clientX - rect.left) / rect.width;
    }
    ratio = Math.max(0, Math.min(1, ratio));
    return snapToStep(min + ratio * (max - min));
  }

  function nearestThumb(val: number): 'low' | 'high' {
    const distLow = Math.abs(val - low);
    const distHigh = Math.abs(val - high);
    // When equidistant, prefer the thumb in the direction of the click
    if (distLow < distHigh) return 'low';
    if (distHigh < distLow) return 'high';
    // Equal distance: prefer the side the value is on
    return val <= low ? 'low' : 'high';
  }

  function updateThumb(which: 'low' | 'high', newVal: number) {
    if (which === 'low') {
      const clamped = Math.min(newVal, high);
      if (clamped !== low) {
        low = clamped;
        lowChanging?.({ value: low });
      }
    } else {
      const clamped = Math.max(newVal, low);
      if (clamped !== high) {
        high = clamped;
        highChanging?.({ value: high });
      }
    }
  }

  function handlePointerDown(e: PointerEvent) {
    if (disabled) return;
    e.preventDefault();
    const newVal = getValueFromPointer(e.clientX, e.clientY);
    const which = nearestThumb(newVal);
    dragging = which;
    updateThumb(which, newVal);
    (which === 'low' ? thumbLowEl : thumbHighEl)?.focus();
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
    document.documentElement.addEventListener('pointerleave', handlePointerUp);
  }

  function handlePointerMove(e: PointerEvent) {
    if (!dragging) return;
    const newVal = getValueFromPointer(e.clientX, e.clientY);
    updateThumb(dragging, newVal);
  }

  function handlePointerUp() {
    if (!dragging) return;
    dragging = null;
    document.removeEventListener('pointermove', handlePointerMove);
    document.removeEventListener('pointerup', handlePointerUp);
    document.documentElement.removeEventListener('pointerleave', handlePointerUp);
  }

  function handleKeyDown(which: 'low' | 'high', e: KeyboardEvent) {
    if (disabled) return;
    const current = which === 'low' ? low : high;
    let newValue = current;
    const bigStep = step * 10;

    switch (e.key) {
      case 'ArrowRight':
      case 'ArrowUp':
        newValue = snapToStep(current + step);
        break;
      case 'ArrowLeft':
      case 'ArrowDown':
        newValue = snapToStep(current - step);
        break;
      case 'PageUp':
        newValue = snapToStep(current + bigStep);
        break;
      case 'PageDown':
        newValue = snapToStep(current - bigStep);
        break;
      case 'Home':
        newValue = min;
        break;
      case 'End':
        newValue = max;
        break;
      default:
        return;
    }

    e.preventDefault();
    updateThumb(which, newValue);
  }

  $effect(() => {
    focus = (): Resolution => {
      thumbLowEl?.focus();
      return { success: true, data: null };
    };
  });
</script>

<div
  class="ic-range-slider"
  class:ic-range-slider--vertical={isVertical}
  class:ic-range-slider--sm={size === 'sm'}
  class:ic-range-slider--md={size === 'md'}
  class:ic-range-slider--lg={size === 'lg'}
  class:ic-range-slider--disabled={disabled}
  class:ic-range-slider--dragging={dragging !== null}
  class:ic-range-slider--primary={variant === 'primary'}
  class:ic-range-slider--secondary={variant === 'secondary'}
  class:ic-range-slider--success={variant === 'success'}
  class:ic-range-slider--warning={variant === 'warning'}
  class:ic-range-slider--destructive={variant === 'destructive'}
  class:ic-range-slider--ticks={showTicks && ticks.length > 0}
  class:ic-range-slider--thumb-fader={thumb === 'fader'}
  class:ic-range-slider--thumb-circle={thumb === 'circle'}
  class:ic-range-slider--thumb-square={thumb === 'square'}
>
  {#if showValue && isSideLabel}
    <span class="ic-range-slider__label ic-range-slider__label--side" style="width: {labelWidth}ch">{isVertical ? displayHigh : displayLow}</span>
  {/if}

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-range-slider__track"
    bind:this={trackEl}
    onpointerdown={handlePointerDown}
  >
    <!-- Fill between the two thumbs -->
    <div
      class="ic-range-slider__fill"
      style={isVertical
        ? `bottom: ${percentLow}%; height: ${percentHigh - percentLow}%`
        : `left: ${percentLow}%; width: ${percentHigh - percentLow}%`}
    ></div>

    <!-- Low thumb -->
    <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
    <div
      class="ic-range-slider__thumb"
      class:ic-range-slider__thumb--active={dragging === 'low'}
      bind:this={thumbLowEl}
      tabindex={disabled ? -1 : 0}
      onkeydown={(e) => handleKeyDown('low', e)}
      style={isVertical ? `bottom: ${percentLow}%` : `left: ${percentLow}%`}
    >
      <span class="ic-range-slider__grip"></span>
      {#if showValue && !isSideLabel}
        <span
          class="ic-range-slider__label ic-range-slider__label--floating"
          class:ic-range-slider__label--bottom={labelPosition === 'bottom'}
        >{displayLow}</span>
      {/if}
    </div>

    <!-- High thumb -->
    <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
    <div
      class="ic-range-slider__thumb"
      class:ic-range-slider__thumb--active={dragging === 'high'}
      bind:this={thumbHighEl}
      tabindex={disabled ? -1 : 0}
      onkeydown={(e) => handleKeyDown('high', e)}
      style={isVertical ? `bottom: ${percentHigh}%` : `left: ${percentHigh}%`}
    >
      <span class="ic-range-slider__grip"></span>
      {#if showValue && !isSideLabel}
        <span
          class="ic-range-slider__label ic-range-slider__label--floating"
          class:ic-range-slider__label--bottom={labelPosition === 'bottom'}
        >{displayHigh}</span>
      {/if}
    </div>

    {#if showTicks && ticks.length > 0}
      <div class="ic-range-slider__ticks">
        {#each ticks as pct (pct)}
          <div
            class="ic-range-slider__tick"
            style={isVertical ? `bottom: ${pct}%` : `left: ${pct}%`}
          ></div>
        {/each}
      </div>
    {/if}
  </div>

  {#if showValue && isSideLabel}
    <span class="ic-range-slider__label ic-range-slider__label--side" style="width: {labelWidth}ch">{isVertical ? displayLow : displayHigh}</span>
  {/if}
</div>

<style>
  .ic-range-slider {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    width: 100%;
    touch-action: none;
    user-select: none;
  }

  .ic-range-slider--vertical {
    flex-direction: column;
    width: auto;
    height: 100%;
  }

  /* ── Variant accent colors ────────────── */
  .ic-range-slider--primary    { --slider-accent: var(--ic-primary); }
  .ic-range-slider--secondary  { --slider-accent: var(--ic-muted-foreground); }
  .ic-range-slider--success    { --slider-accent: #22c55e; }
  .ic-range-slider--warning    { --slider-accent: #f59e0b; }
  .ic-range-slider--destructive { --slider-accent: var(--ic-destructive); }

  /* ── Track ─────────────────────────────── */
  .ic-range-slider__track {
    position: relative;
    flex: 1;
    border-radius: 2px;
    background-color: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    cursor: pointer;
  }

  .ic-range-slider:not(.ic-range-slider--vertical) .ic-range-slider__track {
    height: var(--slider-track);
    width: 100%;
  }

  .ic-range-slider--vertical .ic-range-slider__track {
    width: var(--slider-track);
    height: 100%;
  }

  /* ── Fill (between the two thumbs) ──────── */
  .ic-range-slider__fill {
    position: absolute;
    border-radius: 2px;
    background-color: var(--slider-accent);
    pointer-events: none;
    opacity: 0.85;
  }

  .ic-range-slider:not(.ic-range-slider--vertical) .ic-range-slider__fill {
    top: 0;
    height: 100%;
  }

  .ic-range-slider--vertical .ic-range-slider__fill {
    left: 0;
    width: 100%;
  }

  /* ── Thumb ──────────────────────────────── */
  .ic-range-slider__thumb {
    position: absolute;
    width: var(--slider-thumb-w);
    height: var(--slider-thumb-h);
    border-radius: 2px;
    background-color: var(--slider-accent);
    border: none;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
    outline: none;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: box-shadow 0.1s ease;
    z-index: 1;
  }

  .ic-range-slider__thumb--active {
    z-index: 2;
  }

  .ic-range-slider:not(.ic-range-slider--vertical) .ic-range-slider__thumb {
    top: 50%;
    transform: translate(-50%, -50%);
  }

  .ic-range-slider--vertical .ic-range-slider__thumb {
    left: 50%;
    transform: translate(-50%, 50%);
  }

  .ic-range-slider:not(.ic-range-slider--disabled) .ic-range-slider__thumb:hover {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.28),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-range-slider__thumb:focus-visible {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.28),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-range-slider--dragging .ic-range-slider__thumb--active {
    box-shadow:
      0 2px 8px rgba(0, 0, 0, 0.32),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* ── Grip lines (center grooves) ──────── */
  .ic-range-slider__grip {
    display: block;
    pointer-events: none;
  }

  .ic-range-slider:not(.ic-range-slider--vertical) .ic-range-slider__grip {
    width: 60%;
    height: 1px;
    background: rgba(255, 255, 255, 0.3);
    box-shadow: 0 2px 0 rgba(255, 255, 255, 0.3), 0 -2px 0 rgba(255, 255, 255, 0.3);
  }

  .ic-range-slider--vertical .ic-range-slider__grip {
    height: 60%;
    width: 1px;
    background: rgba(255, 255, 255, 0.3);
    box-shadow: 2px 0 0 rgba(255, 255, 255, 0.3), -2px 0 0 rgba(255, 255, 255, 0.3);
  }

  /* ── Tick marks ────────────────────────── */
  .ic-range-slider__ticks {
    position: absolute;
    pointer-events: none;
  }

  .ic-range-slider:not(.ic-range-slider--vertical) .ic-range-slider__ticks {
    top: calc(100% + 3px);
    left: 0;
    right: 0;
    height: var(--slider-tick-h);
  }

  .ic-range-slider--vertical .ic-range-slider__ticks {
    left: calc(100% + 3px);
    top: 0;
    bottom: 0;
    width: var(--slider-tick-h);
  }

  .ic-range-slider__tick {
    position: absolute;
    background: var(--ic-muted-foreground);
    opacity: 0.35;
  }

  .ic-range-slider:not(.ic-range-slider--vertical) .ic-range-slider__tick {
    width: 1px;
    height: 100%;
    transform: translateX(-50%);
  }

  .ic-range-slider--vertical .ic-range-slider__tick {
    height: 1px;
    width: 100%;
    transform: translateY(50%);
  }

  /* Reserve space below track when ticks are shown */
  .ic-range-slider--ticks:not(.ic-range-slider--vertical) {
    padding-bottom: calc(var(--slider-tick-h) + 4px);
  }

  .ic-range-slider--ticks.ic-range-slider--vertical {
    padding-right: calc(var(--slider-tick-h) + 4px);
  }

  /* ── Labels ────────────────────────────── */
  .ic-range-slider__label {
    font-size: 0.75rem;
    font-family: inherit;
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    color: var(--ic-muted-foreground);
  }

  /* Side labels (left / right) */
  .ic-range-slider__label--side {
    text-align: right;
  }

  /* Floating labels (top / bottom) — appear on hover/drag */
  .ic-range-slider__label--floating {
    position: absolute;
    bottom: calc(100% + 6px);
    left: 50%;
    transform: translateX(-50%);
    padding: 2px 6px;
    border-radius: 2px;
    background-color: var(--ic-foreground);
    color: var(--ic-background);
    font-size: 0.7rem;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.15s ease;
  }

  .ic-range-slider__label--floating.ic-range-slider__label--bottom {
    bottom: auto;
    top: calc(100% + 6px);
  }

  .ic-range-slider--vertical .ic-range-slider__label--floating {
    bottom: auto;
    left: calc(100% + 8px);
    top: 50%;
    transform: translateY(-50%);
  }

  .ic-range-slider--vertical .ic-range-slider__label--floating.ic-range-slider__label--bottom {
    left: auto;
    right: calc(100% + 8px);
    top: 50%;
    transform: translateY(-50%);
  }

  .ic-range-slider__thumb:hover .ic-range-slider__label--floating,
  .ic-range-slider__thumb--active .ic-range-slider__label--floating {
    opacity: 1;
  }

  /* ── Size variants ─────────────────────── */
  .ic-range-slider--sm {
    --slider-track: 4px;
    --slider-thumb-w: 8px;
    --slider-thumb-h: 18px;
    --slider-thumb-size: 14px;
    --slider-thumb-radius: 3px;
    --slider-tick-h: 5px;
  }
  .ic-range-slider--md {
    --slider-track: 5px;
    --slider-thumb-w: 10px;
    --slider-thumb-h: 22px;
    --slider-thumb-size: 16px;
    --slider-thumb-radius: 4px;
    --slider-tick-h: 6px;
  }
  .ic-range-slider--lg {
    --slider-track: 6px;
    --slider-thumb-w: 12px;
    --slider-thumb-h: 26px;
    --slider-thumb-size: 20px;
    --slider-thumb-radius: 5px;
    --slider-tick-h: 8px;
  }

  /* Vertical fader: swap thumb dimensions */
  .ic-range-slider--vertical.ic-range-slider--thumb-fader.ic-range-slider--sm { --slider-thumb-w: 18px; --slider-thumb-h: 8px; }
  .ic-range-slider--vertical.ic-range-slider--thumb-fader.ic-range-slider--md { --slider-thumb-w: 22px; --slider-thumb-h: 10px; }
  .ic-range-slider--vertical.ic-range-slider--thumb-fader.ic-range-slider--lg { --slider-thumb-w: 26px; --slider-thumb-h: 12px; }

  /* ── Thumb style: circle ───────────────── */
  .ic-range-slider--thumb-circle .ic-range-slider__thumb {
    width: var(--slider-thumb-size);
    height: var(--slider-thumb-size);
    border-radius: 50%;
  }

  .ic-range-slider--thumb-circle .ic-range-slider__grip { display: none; }

  /* ── Thumb style: square ───────────────── */
  .ic-range-slider--thumb-square .ic-range-slider__thumb {
    width: var(--slider-thumb-size);
    height: var(--slider-thumb-size);
    border-radius: var(--slider-thumb-radius);
  }

  .ic-range-slider--thumb-square .ic-range-slider__grip { display: none; }

  /* ── Disabled ──────────────────────────── */
  .ic-range-slider--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-range-slider--disabled .ic-range-slider__track {
    cursor: not-allowed;
  }
</style>
