<script lang="ts">
  interface ColorStop {
    color: string;
    stop: number;
  }

  const defaultGradient: ColorStop[] = [
    { color: '#ef4444', stop: 0 },
    { color: '#f59e0b', stop: 50 },
    { color: '#22c55e', stop: 100 }
  ];

  let {
    value = $bindable(0),
    indeterminate = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    gradient = $bindable(defaultGradient),
    showLabel = $bindable(false),
    labelFormat = $bindable('%d%%'),
    strokeWidth = $bindable(4),
    lineCap = $bindable('butt'),
    showTicks = $bindable(false),
    tickCount = $bindable(12),
    startAngle = $bindable(0),
    sweepAngle = $bindable(360),
  }: {
    value?: number;
    indeterminate?: boolean;
    size?: string;
    variant?: string;
    gradient?: ColorStop[];
    showLabel?: boolean;
    labelFormat?: string;
    strokeWidth?: number;
    lineCap?: string;
    showTicks?: boolean;
    tickCount?: number;
    startAngle?: number;
    sweepAngle?: number;
  } = $props();

  // --- Geometry ---
  const viewBox = 100;
  const center = viewBox / 2;
  const radius = $derived(center - strokeWidth - 1);
  const circumference = $derived(2 * Math.PI * radius);

  // Arc parameters
  const clampedSweep = $derived(Math.min(360, Math.max(1, sweepAngle)));
  const isFullCircle = $derived(clampedSweep >= 360);
  const arcLength = $derived(circumference * (clampedSweep / 360));

  // Position arc start via stroke-dashoffset
  // With SVG rotated -90deg, path position 0 = visual top (our 0°)
  const arcStartOffset = $derived(-(startAngle / 360) * circumference);

  const percentage = $derived(Math.min(100, Math.max(0, value)));
  const fillLength = $derived(arcLength * (percentage / 100));

  // --- Sizing ---
  const sizeMap: Record<string, number> = { sm: 48, md: 72, lg: 112 };
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

  const labelText = $derived(formatLabel(labelFormat, percentage));
  const fontSize = $derived(
    size === 'sm' ? '0.625rem' : size === 'lg' ? '1.125rem' : '0.8125rem'
  );

  // --- Gradient color interpolation ---
  function hexToRgb(hex: string): [number, number, number] {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result
      ? [parseInt(result[1], 16), parseInt(result[2], 16), parseInt(result[3], 16)]
      : [0, 0, 0];
  }

  function rgbToHex(r: number, g: number, b: number): string {
    return '#' + [r, g, b].map(x => Math.round(x).toString(16).padStart(2, '0')).join('');
  }

  function lerpColor(color1: string, color2: string, t: number): string {
    const [r1, g1, b1] = hexToRgb(color1);
    const [r2, g2, b2] = hexToRgb(color2);
    return rgbToHex(
      r1 + (r2 - r1) * t,
      g1 + (g2 - g1) * t,
      b1 + (b2 - b1) * t
    );
  }

  function getGradientColor(stops: ColorStop[], val: number): string {
    if (stops.length === 0) return '#000000';
    if (stops.length === 1) return stops[0].color;
    const sorted = [...stops].sort((a, b) => a.stop - b.stop);
    if (val <= sorted[0].stop) return sorted[0].color;
    if (val >= sorted[sorted.length - 1].stop) return sorted[sorted.length - 1].color;
    for (let i = 0; i < sorted.length - 1; i++) {
      if (val >= sorted[i].stop && val <= sorted[i + 1].stop) {
        const range = sorted[i + 1].stop - sorted[i].stop;
        const t = range === 0 ? 0 : (val - sorted[i].stop) / range;
        return lerpColor(sorted[i].color, sorted[i + 1].color, t);
      }
    }
    return sorted[sorted.length - 1].color;
  }

  const gradientColor = $derived(
    variant === 'gradient' ? getGradientColor(gradient, percentage) : undefined
  );

  // --- Tick marks ---
  const clampedTickCount = $derived(Math.min(tickCount, 60));

  function tickPosition(index: number, total: number) {
    // Distribute ticks from startAngle to startAngle + sweep (inclusive endpoints)
    const fraction = total <= 1 ? 0 : index / (total - 1);
    const alpha = startAngle + fraction * clampedSweep;
    const alphaRad = (alpha * Math.PI) / 180;
    const outerR = center - 1;
    const innerR = outerR - 4;
    // SVG coords that appear at visual angle alpha after -90deg CSS rotation
    return {
      x1: center + outerR * Math.cos(alphaRad),
      y1: center + outerR * Math.sin(alphaRad),
      x2: center + innerR * Math.cos(alphaRad),
      y2: center + innerR * Math.sin(alphaRad),
    };
  }

  // --- Indeterminate animation (JS-driven for arc-aware behavior) ---
  function easeInOut(t: number): number {
    return 0.5 - 0.5 * Math.cos(t * Math.PI);
  }

  let animPhase = $state(0);

  $effect(() => {
    if (!indeterminate) {
      animPhase = 0;
      return;
    }
    let frameId: number;
    let start: number | null = null;
    const duration = 1500;

    function step(timestamp: number) {
      if (start === null) start = timestamp;
      animPhase = ((timestamp - start) % duration) / duration;
      frameId = requestAnimationFrame(step);
    }

    frameId = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frameId);
  });

  const indeterminateBar = $derived.by(() => {
    if (!indeterminate) return { dasharray: '', dashoffset: '' };

    const minDash = 2;
    const maxDash = Math.max(minDash + 1, arcLength * 0.35);

    // Dash: grow then shrink (triangle wave, eased)
    const dashT = animPhase < 0.5 ? animPhase * 2 : 2 - animPhase * 2;
    const dash = minDash + (maxDash - minDash) * easeInOut(dashT);

    let travelOffset: number;
    if (isFullCircle) {
      // Full circle: monotonic advance, wraps seamlessly
      travelOffset = -easeInOut(animPhase) * (circumference - dash);
    } else {
      // Partial arc: bounce back and forth within the arc
      const bounceT = animPhase < 0.5 ? animPhase * 2 : 2 - animPhase * 2;
      travelOffset = -easeInOut(bounceT) * Math.max(0, arcLength - dash);
    }

    return {
      dasharray: `${dash}, ${circumference}`,
      dashoffset: `${arcStartOffset + travelOffset}`,
    };
  });

  // Computed bar styles
  const barDasharray = $derived(
    indeterminate ? indeterminateBar.dasharray : `${fillLength}, ${circumference}`
  );
  const barDashoffset = $derived(
    indeterminate ? indeterminateBar.dashoffset : `${arcStartOffset}`
  );
</script>

<div
  class="ic-circular-progress"
  role="progressbar"
  aria-valuenow={indeterminate ? undefined : percentage}
  aria-valuemin={0}
  aria-valuemax={100}
  style:width="{pixelSize}px"
  style:height="{pixelSize}px"
>
  <svg viewBox="0 0 {viewBox} {viewBox}" class="ic-circular-progress__svg">
    {#if showTicks}
      {#each Array(clampedTickCount) as _, i (i)}
        {@const pos = tickPosition(i, clampedTickCount)}
        <line
          x1={pos.x1} y1={pos.y1}
          x2={pos.x2} y2={pos.y2}
          class="ic-circular-progress__tick"
        />
      {/each}
    {/if}

    <circle
      cx={center} cy={center} r={radius} fill="none"
      class="ic-circular-progress__track"
      style:stroke-width="{strokeWidth}"
      style:stroke-dasharray={isFullCircle ? undefined : `${arcLength}, ${circumference}`}
      style:stroke-dashoffset={isFullCircle ? undefined : `${arcStartOffset}`}
      style:stroke-linecap={isFullCircle ? undefined : lineCap}
    />

    <circle
      cx={center} cy={center} r={radius} fill="none"
      class="ic-circular-progress__bar"
      class:ic-circular-progress__bar--primary={variant === 'primary'}
      class:ic-circular-progress__bar--secondary={variant === 'secondary'}
      class:ic-circular-progress__bar--success={variant === 'success'}
      class:ic-circular-progress__bar--warning={variant === 'warning'}
      class:ic-circular-progress__bar--destructive={variant === 'destructive'}
      class:ic-circular-progress__bar--indeterminate={indeterminate}
      style:stroke-width="{strokeWidth}"
      style:stroke-dasharray={barDasharray}
      style:stroke-dashoffset={barDashoffset}
      style:stroke-linecap={lineCap}
      style:stroke={gradientColor ?? undefined}
    />
  </svg>

  {#if showLabel && !indeterminate}
    <span
      class="ic-circular-progress__label"
      style:font-size={fontSize}
    >
      {labelText}
    </span>
  {/if}
</div>

<style>
  .ic-circular-progress {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  .ic-circular-progress__svg {
    width: 100%;
    height: 100%;
    transform: rotate(-90deg);
  }

  .ic-circular-progress__track {
    stroke: var(--ic-secondary);
    filter: drop-shadow(0px 0.5px 0.5px rgba(0, 0, 0, 0.1));
  }

  .ic-circular-progress__bar {
    transition: stroke-dasharray 0.15s ease;
    opacity: 0.85;
  }

  /* Disable transition during JS-driven indeterminate animation */
  .ic-circular-progress__bar--indeterminate {
    transition: none;
  }

  .ic-circular-progress__bar--primary {
    stroke: var(--ic-primary);
  }
  .ic-circular-progress__bar--secondary {
    stroke: var(--ic-muted-foreground);
  }
  .ic-circular-progress__bar--success {
    stroke: var(--ic-success);
  }
  .ic-circular-progress__bar--warning {
    stroke: var(--ic-warning);
  }
  .ic-circular-progress__bar--destructive {
    stroke: var(--ic-destructive);
  }

  .ic-circular-progress__tick {
    stroke: var(--ic-muted-foreground);
    stroke-width: 0.8;
    opacity: 0.3;
  }

  .ic-circular-progress__label {
    position: absolute;
    font-weight: 600;
    color: var(--ic-foreground);
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
    user-select: none;
  }
</style>
