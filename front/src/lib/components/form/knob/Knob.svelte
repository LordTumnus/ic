<script lang="ts">
  import { onMount } from 'svelte';
  import type { Resolution } from '$lib/types';

  let {
    id = '',
    value = $bindable(0),
    min = $bindable(0),
    max = $bindable(100),
    step = $bindable(1),
    disabled = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    showValue = $bindable(false),
    showTrack = $bindable(true),
    showTicks = $bindable(false),
    tickCount = $bindable(12),
    labelFormat = $bindable('%d'),
    labelPosition = $bindable('bottom'),
    valueChanging,
    focus = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    value?: number;
    min?: number;
    max?: number;
    step?: number;
    disabled?: boolean;
    size?: string;
    variant?: string;
    showValue?: boolean;
    showTrack?: boolean;
    showTicks?: boolean;
    tickCount?: number;
    labelFormat?: string;
    labelPosition?: string;
    valueChanging?: (data?: unknown) => void;
    focus?: () => Resolution;
  } = $props();

  // --- Refs & state ---
  let knobEl: HTMLDivElement;
  let isDragging = $state(false);
  let isFocused = $state(false);

  // --- Geometry constants ---
  const viewBox = 100;
  const center = viewBox / 2;
  const knobRadius = 34;
  // Track: thin ring hugging the knob body edge
  const trackRadius = 37.5;
  const trackWidth = 2.5;
  const indicatorInner = 14;
  const indicatorOuter = 28;
  const gripRadius = 29;
  const gripDotR = 1.1;
  const gripDotCount = 12;
  const tickInnerR = 40;
  const tickOuterR = 44;

  // --- Derived values ---
  const circumference = $derived(2 * Math.PI * trackRadius);

  const percentage = $derived(
    max === min ? 0 : Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100))
  );
  const fillLength = $derived(circumference * (percentage / 100));

  // Indicator: percentage maps to 0-360° in SVG space
  // SVG rotated -90deg so position 0 = visual top
  const indicatorAngleDeg = $derived((percentage / 100) * 360);
  const indicatorRad = $derived((indicatorAngleDeg * Math.PI) / 180);
  const indX1 = $derived(center + indicatorInner * Math.cos(indicatorRad));
  const indY1 = $derived(center + indicatorInner * Math.sin(indicatorRad));
  const indX2 = $derived(center + indicatorOuter * Math.cos(indicatorRad));
  const indY2 = $derived(center + indicatorOuter * Math.sin(indicatorRad));

  // --- Sizing ---
  const sizeMap: Record<string, number> = { sm: 30, md: 48, lg: 72 };
  const pixelSize = $derived(sizeMap[size] ?? sizeMap.md);

  // --- Label ---
  function formatLabel(fmt: string, val: number): string {
    return fmt.replace(/%(\.\d+)?[df]|%%/g, (match) => {
      if (match === '%%') return '%';
      const precisionMatch = match.match(/^%\.(\d+)f$/);
      if (precisionMatch) return val.toFixed(Number(precisionMatch[1]));
      if (match === '%f') return val.toFixed(1);
      return String(Math.round(val));
    });
  }

  const displayValue = $derived(Math.min(max, Math.max(min, value)));
  const labelText = $derived(formatLabel(labelFormat, displayValue));
  // Font size for SVG-internal label (small, constrained by viewBox)
  const labelFontSizeInside = $derived(
    size === 'sm' ? 8 : size === 'lg' ? 13 : 10
  );
  // Font size for HTML label below the knob (px, can be bigger)
  const labelFontSizeBottom = $derived(
    size === 'sm' ? 10 : size === 'lg' ? 14 : 11
  );

  // --- Tick marks (evenly around 360°) ---
  const clampedTickCount = $derived(Math.min(tickCount, 60));

  function tickPosition(index: number, total: number) {
    const angleRad = ((index / total) * 360 * Math.PI) / 180;
    return {
      x1: center + tickInnerR * Math.cos(angleRad),
      y1: center + tickInnerR * Math.sin(angleRad),
      x2: center + tickOuterR * Math.cos(angleRad),
      y2: center + tickOuterR * Math.sin(angleRad),
    };
  }

  // --- Grip dots (knurling) ---
  function gripDotPosition(index: number) {
    const angleRad = ((index / gripDotCount) * 360 * Math.PI) / 180;
    return {
      cx: center + gripRadius * Math.cos(angleRad),
      cy: center + gripRadius * Math.sin(angleRad),
    };
  }

  // --- Interaction: circular drag with relative deltas ---
  let lastPointerAngle = 0;

  function snapToStep(raw: number): number {
    const stepped = Math.round((raw - min) / step) * step + min;
    return Math.min(max, Math.max(min, Number(stepped.toFixed(10))));
  }

  // Pointer angle: 0=top, CW positive, [0, 360)
  function getPointerAngle(clientX: number, clientY: number): number {
    const rect = knobEl.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    let angle = Math.atan2(clientX - cx, -(clientY - cy)) * (180 / Math.PI);
    if (angle < 0) angle += 360;
    return angle;
  }

  function handlePointerDown(e: PointerEvent) {
    if (disabled) return;
    e.preventDefault();
    isDragging = true;
    knobEl?.focus();

    // Click-to-set: absolute angle → value
    const angle = getPointerAngle(e.clientX, e.clientY);
    lastPointerAngle = angle;
    const newVal = snapToStep(min + (angle / 360) * (max - min));
    if (newVal !== value) {
      value = newVal;
      valueChanging?.({ value });
    }

    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
    document.documentElement.addEventListener('pointerleave', handlePointerUp);
  }

  function handlePointerMove(e: PointerEvent) {
    const angle = getPointerAngle(e.clientX, e.clientY);

    // Shortest-path angular delta (handles 359°→1° wrap)
    let delta = angle - lastPointerAngle;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    lastPointerAngle = angle;

    // Convert angular delta to value delta
    const valueDelta = (delta / 360) * (max - min);
    const newVal = snapToStep(value + valueDelta);
    if (newVal !== value) {
      value = newVal;
      valueChanging?.({ value });
    }
  }

  function handlePointerUp() {
    if (!isDragging) return;
    isDragging = false;
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
      valueChanging?.({ value });
    }
  }

  // --- Focus management (JS-driven, no :has()) ---
  function handleFocus() {
    isFocused = true;
  }

  function handleBlur() {
    isFocused = false;
  }

  // --- Method binding ---
  onMount(() => {
    focus = (): Resolution => {
      knobEl?.focus();
      return { success: true, data: null };
    };
  });
</script>

<div {id}
  class="ic-knob"
  class:ic-knob--primary={variant === 'primary'}
  class:ic-knob--secondary={variant === 'secondary'}
  class:ic-knob--success={variant === 'success'}
  class:ic-knob--warning={variant === 'warning'}
  class:ic-knob--destructive={variant === 'destructive'}
  class:ic-knob--disabled={disabled}
>
  <div
    bind:this={knobEl}
    class="ic-knob__dial"
    class:ic-knob__dial--sm={size === 'sm'}
    class:ic-knob__dial--md={size === 'md'}
    class:ic-knob__dial--lg={size === 'lg'}
    class:ic-knob__dial--dragging={isDragging}
    class:ic-knob__dial--focused={isFocused}
    role="slider"
    aria-valuenow={displayValue}
    aria-valuemin={min}
    aria-valuemax={max}
    tabindex={disabled ? -1 : 0}
    style:width="{pixelSize}px"
    style:height="{pixelSize}px"
    onpointerdown={handlePointerDown}
    onkeydown={handleKeyDown}
    onfocus={handleFocus}
    onblur={handleBlur}
  >
    <svg viewBox="0 0 {viewBox} {viewBox}" class="ic-knob__svg">
      <defs>
        <!-- Inset shadow for recessed track -->
        <filter id="ic-knob-inset" x="-50%" y="-50%" width="200%" height="200%">
          <feFlood flood-color="rgba(0,0,0,0.15)" />
          <feComposite in2="SourceGraphic" operator="in" />
          <feGaussianBlur stdDeviation="0.8" />
          <feOffset dx="0" dy="0.5" />
          <feComposite in2="SourceGraphic" operator="atop" />
        </filter>
        <!-- Elevation shadow for knob body -->
        <filter id="ic-knob-elevation" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="1" stdDeviation="1.5" flood-color="rgba(0,0,0,0.25)" />
        </filter>
        <!-- Top highlight for knob body -->
        <filter id="ic-knob-highlight" x="-50%" y="-50%" width="200%" height="200%">
          <feFlood flood-color="rgba(255,255,255,0.12)" />
          <feComposite in2="SourceGraphic" operator="in" />
          <feGaussianBlur stdDeviation="0.4" />
          <feOffset dx="0" dy="-0.6" />
          <feComposite in2="SourceGraphic" operator="atop" />
        </filter>
      </defs>

      <!-- Tick marks (evenly around full circle) -->
      {#if showTicks && clampedTickCount > 0}
        {#each Array(clampedTickCount) as _, i (i)}
          {@const pos = tickPosition(i, clampedTickCount)}
          <line
            x1={pos.x1} y1={pos.y1}
            x2={pos.x2} y2={pos.y2}
            class="ic-knob__tick"
          />
        {/each}
      {/if}

      <!-- Knob body (elevated circle) -->
      <circle
        cx={center} cy={center} r={knobRadius}
        class="ic-knob__body"
      />

      <!-- Knob body highlight overlay -->
      <circle
        cx={center} cy={center} r={knobRadius}
        class="ic-knob__body-highlight"
      />

      {#if showTrack}
        <!-- Track (thin ring hugging knob edge) -->
        <circle
          cx={center} cy={center} r={trackRadius} fill="none"
          class="ic-knob__track"
          style:stroke-width="{trackWidth}"
        />

        <!-- Fill arc (value indicator, starts at top) -->
        <circle
          cx={center} cy={center} r={trackRadius} fill="none"
          class="ic-knob__fill"
          style:stroke-width="{trackWidth}"
          style:stroke-dasharray="{fillLength}, {circumference}"
        />
      {/if}

      <!-- Focus ring (visible only when focused, rendered in SVG) -->
      {#if isFocused}
        <circle
          cx={center} cy={center} r={knobRadius + 2}
          class="ic-knob__focus-ring"
        />
      {/if}

      <!-- Grip dots (knurling texture) -->
      {#each Array(gripDotCount) as _, i (i)}
        {@const pos = gripDotPosition(i)}
        <circle
          cx={pos.cx} cy={pos.cy} r={gripDotR}
          class="ic-knob__grip-dot"
        />
      {/each}

      <!-- Indicator line -->
      <line
        x1={indX1} y1={indY1}
        x2={indX2} y2={indY2}
        class="ic-knob__indicator"
      />

      <!-- Value label inside the knob -->
      {#if showValue && labelPosition === 'inside'}
        <text
          x={center} y={center}
          class="ic-knob__label-inside"
          text-anchor="middle"
          dominant-baseline="central"
          style:font-size="{labelFontSizeInside}px"
        >
          {labelText}
        </text>
      {/if}
    </svg>
  </div>

  <!-- Value label below the knob -->
  {#if showValue && labelPosition === 'bottom'}
    <span
      class="ic-knob__label-bottom"
      style:font-size="{labelFontSizeBottom}px"
    >
      {labelText}
    </span>
  {/if}
</div>

<style>
  /* ── Outer wrapper (layout) ─────────────── */
  .ic-knob {
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }

  /* ── Variant accent colors ────────────── */
  .ic-knob--primary    { --knob-accent: var(--ic-primary); }
  .ic-knob--secondary  { --knob-accent: var(--ic-muted-foreground); }
  .ic-knob--success    { --knob-accent: var(--ic-success); }
  .ic-knob--warning    { --knob-accent: var(--ic-warning); }
  .ic-knob--destructive { --knob-accent: var(--ic-destructive); }

  /* ── Dial (interactive knob area) ───────── */
  .ic-knob__dial {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    touch-action: none;
    user-select: none;
    cursor: grab;
    outline: none;
  }

  .ic-knob__dial--dragging {
    cursor: grabbing;
  }

  .ic-knob__svg {
    width: 100%;
    height: 100%;
    transform: rotate(-90deg);
  }

  /* ── Track (thin ring at knob edge) ──────── */
  .ic-knob__track {
    stroke: var(--ic-secondary);
    filter: url(#ic-knob-inset);
  }

  /* ── Fill (value arc) ──────────────────── */
  .ic-knob__fill {
    stroke: var(--knob-accent, var(--ic-primary));
    opacity: 0.85;
    transition: stroke-dasharray 0.1s ease;
  }

  /* ── Knob body (elevated disc) ─────────── */
  .ic-knob__body {
    fill: var(--ic-secondary);
    filter: url(#ic-knob-elevation);
  }

  .ic-knob__body-highlight {
    fill: var(--ic-secondary);
    filter: url(#ic-knob-highlight);
  }

  /* ── Focus ring (SVG-based) ────────────── */
  .ic-knob__focus-ring {
    fill: none;
    stroke: var(--knob-accent, var(--ic-primary));
    stroke-width: 1;
    opacity: 0.5;
  }

  /* ── Indicator line ────────────────────── */
  .ic-knob__indicator {
    stroke: var(--knob-accent, var(--ic-primary));
    stroke-width: 2.5;
    stroke-linecap: round;
  }

  /* ── Grip dots (knurling) ──────────────── */
  .ic-knob__grip-dot {
    fill: var(--ic-muted-foreground);
    opacity: 0.2;
  }

  /* ── Tick marks ────────────────────────── */
  .ic-knob__tick {
    stroke: var(--ic-muted-foreground);
    stroke-width: 0.8;
    opacity: 0.35;
  }

  /* ── Value label (inside knob, SVG text) ── */
  .ic-knob__label-inside {
    fill: var(--ic-foreground);
    font-family: inherit;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
    /* Undo SVG rotation for text readability */
    transform: rotate(90deg);
    transform-origin: 50px 50px;
  }

  /* ── Value label (below knob, HTML) ─────── */
  .ic-knob__label-bottom {
    color: var(--ic-foreground);
    font-family: inherit;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
    line-height: 1;
    white-space: nowrap;
  }

  /* ── Disabled ──────────────────────────── */
  .ic-knob--disabled {
    opacity: 0.5;
    pointer-events: none;
    cursor: not-allowed;
  }
</style>
