<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';

  let {
    value = $bindable(0),
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
    valueChanging,
    valueChanged,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    value?: number;
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
    valueChanging?: (data?: unknown) => void;
    valueChanged?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  let trackEl: HTMLDivElement;
  let thumbEl: HTMLDivElement;
  let isDragging = $state(false);

  const decimals = $derived(step % 1 === 0 ? 0 : (step.toString().split('.')[1]?.length ?? 0));
  const displayValue = $derived(value.toFixed(decimals));
  const percentage = $derived(
    max !== min ? ((value - min) / (max - min)) * 100 : 0
  );

  const isVertical = $derived(orientation === 'vertical');
  const isSideLabel = $derived(labelPosition === 'left' || labelPosition === 'right');

  // Compute fixed label width from the widest possible value string
  const labelWidth = $derived.by(() => {
    const dec = step % 1 === 0 ? 0 : (step.toString().split('.')[1]?.length ?? 0);
    const longest = [min, max].reduce((a, b) =>
      b.toFixed(dec).length > a.toFixed(dec).length ? b : a
    );
    return longest.toFixed(dec).length;
  });

  // Compute tick mark positions as percentages
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
    if (!trackEl) return value;
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

  function handlePointerDown(e: PointerEvent) {
    if (disabled) return;
    e.preventDefault();
    isDragging = true;
    const newVal = getValueFromPointer(e.clientX, e.clientY);
    if (newVal !== value) {
      value = newVal;
      valueChanging?.({ value });
    }
    thumbEl?.focus();
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
    document.documentElement.addEventListener('pointerleave', handlePointerUp);
  }

  function handlePointerMove(e: PointerEvent) {
    const newVal = getValueFromPointer(e.clientX, e.clientY);
    if (newVal !== value) {
      value = newVal;
      valueChanging?.({ value });
    }
  }

  function handlePointerUp() {
    if (!isDragging) return;
    isDragging = false;
    valueChanged?.({ value });
    document.removeEventListener('pointermove', handlePointerMove);
    document.removeEventListener('pointerup', handlePointerUp);
    document.documentElement.removeEventListener('pointerleave', handlePointerUp);
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (disabled) return;
    let newValue = value;
    const bigStep = step * 10;

    switch (e.key) {
      case 'ArrowRight':
      case 'ArrowUp':
        newValue = snapToStep(value + step);
        break;
      case 'ArrowLeft':
      case 'ArrowDown':
        newValue = snapToStep(value - step);
        break;
      case 'PageUp':
        newValue = snapToStep(value + bigStep);
        break;
      case 'PageDown':
        newValue = snapToStep(value - bigStep);
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
    if (newValue !== value) {
      value = newValue;
      valueChanged?.({ value });
    }
  }

  onMount(() => {
    focus = (): Resolution => {
      thumbEl?.focus();
      return { success: true, data: null };
    };
  });
</script>

<div
  class="ic-slider"
  class:ic-slider--vertical={isVertical}
  class:ic-slider--sm={size === 'sm'}
  class:ic-slider--md={size === 'md'}
  class:ic-slider--lg={size === 'lg'}
  class:ic-slider--disabled={disabled}
  class:ic-slider--dragging={isDragging}
  class:ic-slider--primary={variant === 'primary'}
  class:ic-slider--secondary={variant === 'secondary'}
  class:ic-slider--success={variant === 'success'}
  class:ic-slider--warning={variant === 'warning'}
  class:ic-slider--destructive={variant === 'destructive'}
  class:ic-slider--ticks={showTicks && ticks.length > 0}
  class:ic-slider--thumb-fader={thumb === 'fader'}
  class:ic-slider--thumb-circle={thumb === 'circle'}
  class:ic-slider--thumb-square={thumb === 'square'}
>
  {#if showValue && labelPosition === 'left'}
    <span class="ic-slider__label ic-slider__label--side" style="width: {labelWidth}ch">{displayValue}</span>
  {/if}

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-slider__track"
    bind:this={trackEl}
    onpointerdown={handlePointerDown}
  >
    <div
      class="ic-slider__fill"
      style={isVertical ? `height: ${percentage}%` : `width: ${percentage}%`}
    ></div>
    <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
    <div
      class="ic-slider__thumb"
      bind:this={thumbEl}
      tabindex={disabled ? -1 : 0}
      onkeydown={handleKeyDown}
      style={isVertical ? `bottom: ${percentage}%` : `left: ${percentage}%`}
    >
      <span class="ic-slider__grip"></span>
      {#if showValue && !isSideLabel}
        <span
          class="ic-slider__label ic-slider__label--floating"
          class:ic-slider__label--bottom={labelPosition === 'bottom'}
        >{displayValue}</span>
      {/if}
    </div>

    {#if showTicks && ticks.length > 0}
      <div class="ic-slider__ticks">
        {#each ticks as pct (pct)}
          <div
            class="ic-slider__tick"
            style={isVertical ? `bottom: ${pct}%` : `left: ${pct}%`}
          ></div>
        {/each}
      </div>
    {/if}
  </div>

  {#if showValue && labelPosition === 'right'}
    <span class="ic-slider__label ic-slider__label--side" style="width: {labelWidth}ch">{displayValue}</span>
  {/if}
</div>

<style>
  .ic-slider {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    width: 100%;
    touch-action: none;
    user-select: none;
  }

  .ic-slider--vertical {
    flex-direction: column;
    width: auto;
    height: 100%;
  }

  /* ── Variant accent colors ────────────── */
  .ic-slider--primary    { --slider-accent: var(--ic-primary); }
  .ic-slider--secondary  { --slider-accent: var(--ic-muted-foreground); }
  .ic-slider--success    { --slider-accent: #22c55e; }
  .ic-slider--warning    { --slider-accent: #f59e0b; }
  .ic-slider--destructive { --slider-accent: var(--ic-destructive); }

  /* ── Track ─────────────────────────────── */
  .ic-slider__track {
    position: relative;
    flex: 1;
    border-radius: 2px;
    background-color: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    cursor: pointer;
  }

  .ic-slider:not(.ic-slider--vertical) .ic-slider__track {
    height: var(--slider-track);
    width: 100%;
  }

  .ic-slider--vertical .ic-slider__track {
    width: var(--slider-track);
    height: 100%;
  }

  /* ── Fill ──────────────────────────────── */
  .ic-slider__fill {
    position: absolute;
    border-radius: 2px;
    background-color: var(--slider-accent);
    pointer-events: none;
    opacity: 0.85;
  }

  .ic-slider:not(.ic-slider--vertical) .ic-slider__fill {
    left: 0;
    top: 0;
    height: 100%;
  }

  .ic-slider--vertical .ic-slider__fill {
    bottom: 0;
    left: 0;
    width: 100%;
  }

  /* ── Thumb (fader-style) ───────────────── */
  .ic-slider__thumb {
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
  }

  .ic-slider:not(.ic-slider--vertical) .ic-slider__thumb {
    top: 50%;
    transform: translate(-50%, -50%);
  }

  .ic-slider--vertical .ic-slider__thumb {
    left: 50%;
    transform: translate(-50%, 50%);
  }

  .ic-slider:not(.ic-slider--disabled) .ic-slider__thumb:hover {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.28),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-slider__thumb:focus-visible {
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.28),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-slider--dragging .ic-slider__thumb {
    box-shadow:
      0 2px 8px rgba(0, 0, 0, 0.32),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* ── Grip lines (center grooves) ──────── */
  .ic-slider__grip {
    display: block;
    pointer-events: none;
  }

  .ic-slider:not(.ic-slider--vertical) .ic-slider__grip {
    width: 60%;
    height: 1px;
    background: rgba(255, 255, 255, 0.3);
    box-shadow: 0 2px 0 rgba(255, 255, 255, 0.3), 0 -2px 0 rgba(255, 255, 255, 0.3);
  }

  .ic-slider--vertical .ic-slider__grip {
    height: 60%;
    width: 1px;
    background: rgba(255, 255, 255, 0.3);
    box-shadow: 2px 0 0 rgba(255, 255, 255, 0.3), -2px 0 0 rgba(255, 255, 255, 0.3);
  }

  /* ── Tick marks ────────────────────────── */
  .ic-slider__ticks {
    position: absolute;
    pointer-events: none;
  }

  .ic-slider:not(.ic-slider--vertical) .ic-slider__ticks {
    top: calc(100% + 3px);
    left: 0;
    right: 0;
    height: var(--slider-tick-h);
  }

  .ic-slider--vertical .ic-slider__ticks {
    left: calc(100% + 3px);
    top: 0;
    bottom: 0;
    width: var(--slider-tick-h);
  }

  .ic-slider__tick {
    position: absolute;
    background: var(--ic-muted-foreground);
    opacity: 0.35;
  }

  .ic-slider:not(.ic-slider--vertical) .ic-slider__tick {
    width: 1px;
    height: 100%;
    transform: translateX(-50%);
  }

  .ic-slider--vertical .ic-slider__tick {
    height: 1px;
    width: 100%;
    transform: translateY(50%);
  }

  /* Reserve space below track when ticks are shown */
  .ic-slider--ticks:not(.ic-slider--vertical) {
    padding-bottom: calc(var(--slider-tick-h) + 4px);
  }

  .ic-slider--ticks.ic-slider--vertical {
    padding-right: calc(var(--slider-tick-h) + 4px);
  }

  /* ── Labels ────────────────────────────── */
  .ic-slider__label {
    font-size: 0.75rem;
    font-family: inherit;
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    color: var(--ic-muted-foreground);
  }

  /* Side labels (left / right) — always visible, width set inline */
  .ic-slider__label--side {
    text-align: right;
  }

  /* Floating labels (top / bottom) — appear on hover/drag */
  .ic-slider__label--floating {
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

  .ic-slider__label--floating.ic-slider__label--bottom {
    bottom: auto;
    top: calc(100% + 6px);
  }

  .ic-slider--vertical .ic-slider__label--floating {
    bottom: auto;
    left: calc(100% + 8px);
    top: 50%;
    transform: translateY(-50%);
  }

  .ic-slider--vertical .ic-slider__label--floating.ic-slider__label--bottom {
    left: auto;
    right: calc(100% + 8px);
    top: 50%;
    transform: translateY(-50%);
  }

  .ic-slider__thumb:hover .ic-slider__label--floating,
  .ic-slider--dragging .ic-slider__label--floating {
    opacity: 1;
  }

  /* ── Size variants ─────────────────────── */
  .ic-slider--sm {
    --slider-track: 4px;
    --slider-thumb-w: 8px;
    --slider-thumb-h: 18px;
    --slider-thumb-size: 14px;
    --slider-thumb-radius: 3px;
    --slider-tick-h: 5px;
  }
  .ic-slider--md {
    --slider-track: 5px;
    --slider-thumb-w: 10px;
    --slider-thumb-h: 22px;
    --slider-thumb-size: 16px;
    --slider-thumb-radius: 4px;
    --slider-tick-h: 6px;
  }
  .ic-slider--lg {
    --slider-track: 6px;
    --slider-thumb-w: 12px;
    --slider-thumb-h: 26px;
    --slider-thumb-size: 20px;
    --slider-thumb-radius: 5px;
    --slider-tick-h: 8px;
  }

  /* Vertical fader: swap thumb dimensions */
  .ic-slider--vertical.ic-slider--thumb-fader.ic-slider--sm { --slider-thumb-w: 18px; --slider-thumb-h: 8px; }
  .ic-slider--vertical.ic-slider--thumb-fader.ic-slider--md { --slider-thumb-w: 22px; --slider-thumb-h: 10px; }
  .ic-slider--vertical.ic-slider--thumb-fader.ic-slider--lg { --slider-thumb-w: 26px; --slider-thumb-h: 12px; }

  /* ── Thumb style: circle ───────────────── */
  .ic-slider--thumb-circle .ic-slider__thumb {
    width: var(--slider-thumb-size);
    height: var(--slider-thumb-size);
    border-radius: 50%;
  }

  .ic-slider--thumb-circle .ic-slider__grip { display: none; }

  /* ── Thumb style: square ───────────────── */
  .ic-slider--thumb-square .ic-slider__thumb {
    width: var(--slider-thumb-size);
    height: var(--slider-thumb-size);
    border-radius: var(--slider-thumb-radius);
  }

  .ic-slider--thumb-square .ic-slider__grip { display: none; }

  /* ── Disabled ──────────────────────────── */
  .ic-slider--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-slider--disabled .ic-slider__track {
    cursor: not-allowed;
  }
</style>
