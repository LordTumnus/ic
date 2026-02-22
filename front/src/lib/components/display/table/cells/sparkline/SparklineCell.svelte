<script lang="ts">
  import type { SparklineConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<SparklineConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<SparklineConfig>;
    style?: string;
  } = $props();

  const SPARK_HEIGHT = 16; // px — fits comfortably in md (28px) rows

  const lineWidth = $derived(config.lineWidth ?? 1.5);
  const fillArea = $derived(config.fillArea ?? false);
  const showEndDot = $derived(config.showEndDot ?? true);
  const showLabel = $derived(config.showLabel ?? false);
  const metric = $derived(config.metric ?? 'total');
  const variant = $derived(config.variant ?? 'primary');
  const colorRules = $derived(config.colorRules as ColorRuleConfig[] | undefined);

  // Parse cell value into number array
  const data = $derived.by((): number[] => {
    if (Array.isArray(value)) return value.filter((v): v is number => typeof v === 'number');
    return [];
  });

  // Y-axis bounds: always auto-detect from data
  const yMin = $derived(data.length ? Math.min(...data) : 0);
  const yMax = $derived(data.length ? Math.max(...data) : 1);
  const yRange = $derived(yMax === yMin ? 1 : yMax - yMin);

  // First and last values
  const firstVal = $derived(data.length > 0 ? data[0] : null);
  const lastVal = $derived(data.length > 0 ? data[data.length - 1] : null);

  // Relative change (%) from first to last
  const changePct = $derived.by((): number | null => {
    if (firstVal == null || lastVal == null || data.length < 2) return null;
    if (firstVal === 0) return lastVal === 0 ? 0 : (lastVal > 0 ? Infinity : -Infinity);
    return ((lastVal - firstVal) / Math.abs(firstVal)) * 100;
  });

  // The metric value that ColorRules and label operate on
  const metricVal = $derived(
    metric === 'relative' ? changePct : lastVal
  );

  // Color: rules evaluate against the metric value
  const ruleColor = $derived(
    metricVal != null && isFinite(metricVal) && colorRules?.length
      ? evaluateColorRules(metricVal, colorRules)
      : null
  );

  // Label text depends on metric mode
  const labelText = $derived.by((): string => {
    if (metric === 'relative') {
      if (changePct == null) return '';
      const arrow = changePct > 0 ? '▲' : changePct < 0 ? '▼' : '';
      if (!isFinite(changePct)) return arrow;
      return `${arrow}\u2009${Math.abs(changePct).toFixed(1)}%`;
    }
    // total: show last value
    if (lastVal == null) return '';
    return Number.isInteger(lastVal) ? String(lastVal) : lastVal.toFixed(1);
  });

  // Normalized points in viewBox coordinates: x = [0, 100], y = [0, 100]
  const points = $derived.by((): { x: number; y: number }[] => {
    if (data.length === 0) return [];
    const n = data.length;
    return data.map((v, i) => ({
      x: n > 1 ? i / (n - 1) * 100 : 50,
      y: (1 - (v - yMin) / yRange) * 100,
    }));
  });

  const linePoints = $derived(points.map(p => `${p.x},${p.y}`).join(' '));
  const fillPoints = $derived.by(() => {
    if (points.length < 2) return '';
    return `${points.map(p => `${p.x},${p.y}`).join(' ')} ${points[points.length - 1].x},100 ${points[0].x},100`;
  });

  // Tooltip
  let title = $state('');
  function onenter() {
    if (firstVal == null || lastVal == null) return;
    const parts = [`${firstVal} → ${lastVal}`];
    if (changePct != null && isFinite(changePct)) {
      const sign = changePct >= 0 ? '+' : '';
      parts.push(`(${sign}${changePct.toFixed(1)}%)`);
    }
    title = parts.join(' ');
  }
  function onleave() { title = ''; }

  // Sparkline doesn't tint cell background
  $effect(() => { style = ''; });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-tbl-cell-spark"
  {title}
  onpointerenter={onenter}
  onpointerleave={onleave}
>
  {#if data.length > 0}
    <div class="ic-tbl-cell-spark__wrap" style="height: {SPARK_HEIGHT}px;">
      <svg
        class="ic-tbl-cell-spark__svg"
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        width="100%"
        height={SPARK_HEIGHT}
      >
        {#if fillArea && points.length >= 2}
          <polygon
            points={fillPoints}
            class="ic-tbl-cell-spark__fill"
            class:ic-tbl-cell-spark__fill--primary={!ruleColor && variant === 'primary'}
            class:ic-tbl-cell-spark__fill--secondary={!ruleColor && variant === 'secondary'}
            class:ic-tbl-cell-spark__fill--success={!ruleColor && variant === 'success'}
            class:ic-tbl-cell-spark__fill--warning={!ruleColor && variant === 'warning'}
            class:ic-tbl-cell-spark__fill--destructive={!ruleColor && variant === 'destructive'}
            style={ruleColor ? `fill: ${ruleColor};` : null}
          />
        {/if}
        {#if points.length >= 2}
          <polyline
            points={linePoints}
            class="ic-tbl-cell-spark__line"
            class:ic-tbl-cell-spark__line--primary={!ruleColor && variant === 'primary'}
            class:ic-tbl-cell-spark__line--secondary={!ruleColor && variant === 'secondary'}
            class:ic-tbl-cell-spark__line--success={!ruleColor && variant === 'success'}
            class:ic-tbl-cell-spark__line--warning={!ruleColor && variant === 'warning'}
            class:ic-tbl-cell-spark__line--destructive={!ruleColor && variant === 'destructive'}
            style={ruleColor ? `stroke: ${ruleColor};` : null}
            stroke-width={lineWidth}
          />
        {/if}
      </svg>
      {#if showEndDot && points.length > 0}
        {@const last = points[points.length - 1]}
        <span
          class="ic-tbl-cell-spark__dot"
          class:ic-tbl-cell-spark__dot--primary={!ruleColor && variant === 'primary'}
          class:ic-tbl-cell-spark__dot--secondary={!ruleColor && variant === 'secondary'}
          class:ic-tbl-cell-spark__dot--success={!ruleColor && variant === 'success'}
          class:ic-tbl-cell-spark__dot--warning={!ruleColor && variant === 'warning'}
          class:ic-tbl-cell-spark__dot--destructive={!ruleColor && variant === 'destructive'}
          style="left: {last.x}%; top: {last.y / 100 * SPARK_HEIGHT}px;{ruleColor ? ` background-color: ${ruleColor};` : ''}"
        ></span>
      {/if}
    </div>
    {#if showLabel && labelText}
      <span
        class="ic-tbl-cell-spark__label"
        class:ic-tbl-cell-spark__label--primary={!ruleColor && variant === 'primary'}
        class:ic-tbl-cell-spark__label--secondary={!ruleColor && variant === 'secondary'}
        class:ic-tbl-cell-spark__label--success={!ruleColor && variant === 'success'}
        class:ic-tbl-cell-spark__label--warning={!ruleColor && variant === 'warning'}
        class:ic-tbl-cell-spark__label--destructive={!ruleColor && variant === 'destructive'}
        style={ruleColor ? `color: ${ruleColor};` : null}
      >{labelText}</span>
    {/if}
  {/if}
</div>

<style>
  .ic-tbl-cell-spark {
    display: flex;
    align-items: center;
    gap: 4px;
    width: 100%;
    min-width: 0;
  }

  .ic-tbl-cell-spark__wrap {
    position: relative;
    flex: 1;
    min-width: 0;
  }

  .ic-tbl-cell-spark__svg {
    display: block;
    overflow: visible;
  }

  /* Line */
  .ic-tbl-cell-spark__line {
    fill: none;
    stroke-linejoin: round;
    stroke-linecap: round;
    vector-effect: non-scaling-stroke;
  }
  .ic-tbl-cell-spark__line--primary   { stroke: var(--ic-primary); }
  .ic-tbl-cell-spark__line--secondary { stroke: var(--ic-muted-foreground); }
  .ic-tbl-cell-spark__line--success   { stroke: var(--ic-success); }
  .ic-tbl-cell-spark__line--warning   { stroke: var(--ic-warning); }
  .ic-tbl-cell-spark__line--destructive { stroke: var(--ic-destructive); }

  /* Fill area */
  .ic-tbl-cell-spark__fill {
    opacity: 0.12;
  }
  .ic-tbl-cell-spark__fill--primary   { fill: var(--ic-primary); }
  .ic-tbl-cell-spark__fill--secondary { fill: var(--ic-muted-foreground); }
  .ic-tbl-cell-spark__fill--success   { fill: var(--ic-success); }
  .ic-tbl-cell-spark__fill--warning   { fill: var(--ic-warning); }
  .ic-tbl-cell-spark__fill--destructive { fill: var(--ic-destructive); }

  /* End dot — HTML element positioned over the SVG */
  .ic-tbl-cell-spark__dot {
    position: absolute;
    width: 5px;
    height: 5px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    pointer-events: none;
  }
  .ic-tbl-cell-spark__dot--primary   { background-color: var(--ic-primary); }
  .ic-tbl-cell-spark__dot--secondary { background-color: var(--ic-muted-foreground); }
  .ic-tbl-cell-spark__dot--success   { background-color: var(--ic-success); }
  .ic-tbl-cell-spark__dot--warning   { background-color: var(--ic-warning); }
  .ic-tbl-cell-spark__dot--destructive { background-color: var(--ic-destructive); }

  /* Metric label */
  .ic-tbl-cell-spark__label {
    flex-shrink: 0;
    font-size: 0.6rem;
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    line-height: 1;
  }
  .ic-tbl-cell-spark__label--primary   { color: var(--ic-primary); }
  .ic-tbl-cell-spark__label--secondary { color: var(--ic-muted-foreground); }
  .ic-tbl-cell-spark__label--success   { color: var(--ic-success); }
  .ic-tbl-cell-spark__label--warning   { color: var(--ic-warning); }
  .ic-tbl-cell-spark__label--destructive { color: var(--ic-destructive); }
</style>
