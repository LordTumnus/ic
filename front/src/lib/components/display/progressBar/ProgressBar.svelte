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
    min = $bindable(0),
    max = $bindable(100),
    indeterminate = $bindable(false),
    striped = $bindable(false),
    animated = $bindable(false),
    size = $bindable('md'),
    variant = $bindable('primary'),
    gradient = $bindable(defaultGradient),
    showLabel = $bindable(false),
    labelFormat = $bindable('%d%%'),
    labelPosition = $bindable('right'),
    orientation = $bindable('horizontal'),
  }: {
    value?: number;
    min?: number;
    max?: number;
    indeterminate?: boolean;
    striped?: boolean;
    animated?: boolean;
    size?: string;
    variant?: string;
    gradient?: ColorStop[];
    showLabel?: boolean;
    labelFormat?: string;
    labelPosition?: string;
    orientation?: string;
  } = $props();

  const isVertical = $derived(orientation === 'vertical');

  // Derive fill percentage from value within [min, max]
  const percentage = $derived(
    max === min ? 0 : Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100))
  );

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

  // Clamp value to [min, max] for display
  const displayValue = $derived(Math.min(max, Math.max(min, value)));

  const labelText = $derived(formatLabel(labelFormat, displayValue));

  // Parse hex color to RGB
  function hexToRgb(hex: string): [number, number, number] {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result
      ? [parseInt(result[1], 16), parseInt(result[2], 16), parseInt(result[3], 16)]
      : [0, 0, 0];
  }

  // Convert RGB to hex
  function rgbToHex(r: number, g: number, b: number): string {
    return '#' + [r, g, b].map(x => Math.round(x).toString(16).padStart(2, '0')).join('');
  }

  // Interpolate between two colors
  function lerpColor(color1: string, color2: string, t: number): string {
    const [r1, g1, b1] = hexToRgb(color1);
    const [r2, g2, b2] = hexToRgb(color2);
    return rgbToHex(
      r1 + (r2 - r1) * t,
      g1 + (g2 - g1) * t,
      b1 + (b2 - b1) * t
    );
  }

  // Get interpolated color from gradient stops
  function getGradientColor(stops: ColorStop[], value: number): string {
    if (stops.length === 0) return '#000000';
    if (stops.length === 1) return stops[0].color;

    // Sort stops by position
    const sorted = [...stops].sort((a, b) => a.stop - b.stop);

    // Clamp value to stop range
    if (value <= sorted[0].stop) return sorted[0].color;
    if (value >= sorted[sorted.length - 1].stop) return sorted[sorted.length - 1].color;

    // Find the two stops to interpolate between
    for (let i = 0; i < sorted.length - 1; i++) {
      if (value >= sorted[i].stop && value <= sorted[i + 1].stop) {
        const range = sorted[i + 1].stop - sorted[i].stop;
        const t = range === 0 ? 0 : (value - sorted[i].stop) / range;
        return lerpColor(sorted[i].color, sorted[i + 1].color, t);
      }
    }

    return sorted[sorted.length - 1].color;
  }

  // Compute gradient color based on current value
  const gradientColor = $derived(
    variant === 'gradient' ? getGradientColor(gradient, percentage) : undefined
  );
</script>

<div
  class="ic-progress"
  class:ic-progress--vertical={isVertical}
  class:ic-progress--sm={size === 'sm'}
  class:ic-progress--md={size === 'md'}
  class:ic-progress--lg={size === 'lg'}
  class:ic-progress--indeterminate={indeterminate}
  role="progressbar"
  aria-valuenow={indeterminate ? undefined : displayValue}
  aria-valuemin={min}
  aria-valuemax={max}
>
  {#if showLabel && !indeterminate && labelPosition === 'left'}
    <span class="ic-progress__label">{labelText}</span>
  {/if}

  <div class="ic-progress__track">
    <div
      class="ic-progress__bar"
      class:ic-progress__bar--primary={variant === 'primary'}
      class:ic-progress__bar--secondary={variant === 'secondary'}
      class:ic-progress__bar--success={variant === 'success'}
      class:ic-progress__bar--warning={variant === 'warning'}
      class:ic-progress__bar--destructive={variant === 'destructive'}
      class:ic-progress__bar--striped={striped}
      class:ic-progress__bar--animated={striped && animated}
      class:ic-progress__bar--indeterminate={indeterminate}
      style:width={indeterminate || isVertical ? undefined : `${percentage}%`}
      style:height={indeterminate || !isVertical ? undefined : `${percentage}%`}
      style:background-color={gradientColor}
    ></div>
  </div>

  {#if showLabel && !indeterminate && labelPosition === 'right'}
    <span class="ic-progress__label">{labelText}</span>
  {/if}
</div>

<style>
  .ic-progress {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    width: 100%;
  }

  .ic-progress--vertical {
    flex-direction: column;
    width: auto;
    height: 100%;
  }

  .ic-progress__track {
    flex: 1;
    background-color: var(--ic-secondary);
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
    overflow: hidden;
    position: relative;
  }

  /* Size variants */
  .ic-progress--sm .ic-progress__track {
    height: 0.375rem;
  }

  .ic-progress--md .ic-progress__track {
    height: 0.625rem;
  }

  .ic-progress--lg .ic-progress__track {
    height: 1rem;
  }

  /* Vertical track: swap width/height */
  .ic-progress--vertical .ic-progress__track {
    width: auto;
    height: 100%;
  }

  .ic-progress--vertical.ic-progress--sm .ic-progress__track {
    width: 0.375rem;
    height: 100%;
  }

  .ic-progress--vertical.ic-progress--md .ic-progress__track {
    width: 0.625rem;
    height: 100%;
  }

  .ic-progress--vertical.ic-progress--lg .ic-progress__track {
    width: 1rem;
    height: 100%;
  }

  /* Progress bar fill */
  .ic-progress__bar {
    height: 100%;
    border-radius: 2px;
    transition: width 0.15s ease, height 0.15s ease;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.15);
    opacity: 0.85;
  }

  .ic-progress--vertical .ic-progress__bar {
    width: 100%;
    height: 0%;
    position: absolute;
    bottom: 0;
    left: 0;
  }

  .ic-progress--vertical .ic-progress__track {
    position: relative;
  }

  /* Color variants using theme variables */
  .ic-progress__bar--primary {
    background-color: var(--ic-primary);
  }

  .ic-progress__bar--secondary {
    background-color: var(--ic-muted-foreground);
  }

  .ic-progress__bar--success {
    background-color: var(--ic-success);
  }

  .ic-progress__bar--warning {
    background-color: var(--ic-warning);
  }

  .ic-progress__bar--destructive {
    background-color: var(--ic-destructive);
  }

  /* Striped pattern - larger stripes for smoother look */
  .ic-progress__bar--striped {
    background-image: linear-gradient(
      45deg,
      rgba(255, 255, 255, 0.15) 25%,
      transparent 25%,
      transparent 50%,
      rgba(255, 255, 255, 0.15) 50%,
      rgba(255, 255, 255, 0.15) 75%,
      transparent 75%,
      transparent
    );
    background-size: 2rem 2rem;
  }

  /* Animated stripes - slower and smoother */
  .ic-progress__bar--animated {
    animation: ic-progress-stripes 2s linear infinite;
  }

  @keyframes ic-progress-stripes {
    from {
      background-position: 2rem 0;
    }
    to {
      background-position: 0 0;
    }
  }

  /* Indeterminate animation - continuous flow from left to right */
  .ic-progress__bar--indeterminate {
    width: 40% !important;
    animation: ic-progress-indeterminate 1.5s linear infinite;
  }

  .ic-progress--vertical .ic-progress__bar--indeterminate {
    width: 100% !important;
    height: 40% !important;
    animation: ic-progress-indeterminate-vertical 1.5s linear infinite;
  }

  @keyframes ic-progress-indeterminate {
    0% {
      transform: translateX(-100%);
    }
    100% {
      transform: translateX(250%);
    }
  }

  @keyframes ic-progress-indeterminate-vertical {
    0% {
      transform: translateY(100%);
    }
    100% {
      transform: translateY(-250%);
    }
  }

  /* Label */
  .ic-progress__label {
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--ic-muted-foreground);
    min-width: 2.5rem;
    font-variant-numeric: tabular-nums;
  }
</style>
