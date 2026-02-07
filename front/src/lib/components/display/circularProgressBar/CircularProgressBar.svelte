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
  } = $props();

  // --- Geometry ---
  const viewBox = 100;
  const center = viewBox / 2;

  // Radius accounts for stroke width so it doesn't clip
  const radius = $derived(center - strokeWidth - 1);
  const circumference = $derived(2 * Math.PI * radius);

  // Clamp value between 0 and 100
  const percentage = $derived(Math.min(100, Math.max(0, value)));

  // SVG stroke-dashoffset drives the arc length
  const dashOffset = $derived(circumference - (percentage / 100) * circumference);

  // --- Sizing ---
  const sizeMap: Record<string, number> = {
    sm: 48,
    md: 72,
    lg: 112,
  };
  const pixelSize = $derived(sizeMap[size] ?? sizeMap.md);

  // --- Label (sprintf-style: %d, %f, %.Nf, %%) ---
  function formatLabel(fmt: string, val: number): string {
    return fmt.replace(/%(\.\d+)?[df]|%%/g, (match) => {
      if (match === '%%') return '%';
      const precisionMatch = match.match(/^%\.(\d+)f$/);
      if (precisionMatch) return val.toFixed(Number(precisionMatch[1]));
      if (match === '%f') return val.toFixed(1);
      return String(Math.round(val)); // %d
    });
  }

  const labelText = $derived(formatLabel(labelFormat, percentage));

  // Font size scales with ring size
  const fontSize = $derived(
    size === 'sm' ? '0.625rem' : size === 'lg' ? '1.125rem' : '0.8125rem'
  );

  // --- Gradient color interpolation (same algorithm as ProgressBar) ---
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
    const angle = (index / total) * 2 * Math.PI - Math.PI / 2; // start at top
    const outerR = center - 1;
    const innerR = outerR - 4;
    return {
      x1: center + outerR * Math.cos(angle),
      y1: center + outerR * Math.sin(angle),
      x2: center + innerR * Math.cos(angle),
      y2: center + innerR * Math.sin(angle),
    };
  }
</script>

<div
  class="ic-circular-progress"
  class:ic-circular-progress--indeterminate={indeterminate}
  role="progressbar"
  aria-valuenow={indeterminate ? undefined : percentage}
  aria-valuemin={0}
  aria-valuemax={100}
  style:width="{pixelSize}px"
  style:height="{pixelSize}px"
>
  <svg
    viewBox="0 0 {viewBox} {viewBox}"
    class="ic-circular-progress__svg"
  >
    <!-- Tick marks (graduation lines) -->
    {#if showTicks}
      {#each Array(clampedTickCount) as _, i (i)}
        {@const pos = tickPosition(i, clampedTickCount)}
        <line
          x1={pos.x1}
          y1={pos.y1}
          x2={pos.x2}
          y2={pos.y2}
          class="ic-circular-progress__tick"
        />
      {/each}
    {/if}

    <!-- Track (background ring) -->
    <circle
      cx={center}
      cy={center}
      r={radius}
      fill="none"
      class="ic-circular-progress__track"
      style:stroke-width="{strokeWidth}"
    />

    <!-- Progress arc -->
    <circle
      cx={center}
      cy={center}
      r={radius}
      fill="none"
      class="ic-circular-progress__bar"
      class:ic-circular-progress__bar--primary={variant === 'primary'}
      class:ic-circular-progress__bar--secondary={variant === 'secondary'}
      class:ic-circular-progress__bar--success={variant === 'success'}
      class:ic-circular-progress__bar--warning={variant === 'warning'}
      class:ic-circular-progress__bar--destructive={variant === 'destructive'}
      class:ic-circular-progress__bar--indeterminate={indeterminate}
      style:stroke-width="{strokeWidth}"
      style:stroke-dasharray={indeterminate ? undefined : `${circumference}`}
      style:stroke-dashoffset={indeterminate ? undefined : `${dashOffset}`}
      style:stroke-linecap={lineCap}
      style:stroke={gradientColor ?? undefined}
    />
  </svg>

  <!-- Center label -->
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

  /* Track ring — recessed channel look */
  .ic-circular-progress__track {
    stroke: var(--ic-secondary);
    filter: drop-shadow(0px 0.5px 0.5px rgba(0, 0, 0, 0.1));
  }

  /* Progress arc */
  .ic-circular-progress__bar {
    transition: stroke-dashoffset 0.15s ease;
    opacity: 0.85;
  }

  /* Variant colors */
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

  /* Indeterminate spinner */
  .ic-circular-progress--indeterminate .ic-circular-progress__svg {
    animation: ic-circular-spin 2s linear infinite;
  }

  .ic-circular-progress__bar--indeterminate {
    animation: ic-circular-dash 1.5s ease-in-out infinite;
  }

  @keyframes ic-circular-spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  @keyframes ic-circular-dash {
    0% {
      stroke-dasharray: 1, 300;
      stroke-dashoffset: 0;
    }
    50% {
      stroke-dasharray: 100, 300;
      stroke-dashoffset: -90;
    }
    100% {
      stroke-dasharray: 1, 300;
      stroke-dashoffset: -280;
    }
  }

  /* Graduation tick marks */
  .ic-circular-progress__tick {
    stroke: var(--ic-muted-foreground);
    stroke-width: 0.8;
    opacity: 0.3;
  }

  /* Center label */
  .ic-circular-progress__label {
    position: absolute;
    font-weight: 600;
    color: var(--ic-foreground);
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
    user-select: none;
  }
</style>
