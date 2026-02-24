<script lang="ts">
  import type { ProgressBarConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';
  import { toComparable } from './utils';

  let {
    value,
    config = {} as Partial<ProgressBarConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<ProgressBarConfig>;
    style?: string;
  } = $props();

  const numVal = $derived(value != null ? Number(value) : null);
  const min = $derived(config.min ?? 0);
  const max = $derived(config.max ?? 100);
  const showLabel = $derived(config.showLabel ?? false);
  const labelFormat = $derived(config.labelFormat ?? '%d%%');
  const variant = $derived(config.variant ?? 'primary');
  const colorRules = $derived(config.colorRules as ColorRuleConfig[] | undefined);

  const percentage = $derived(
    numVal != null && max !== min
      ? Math.min(100, Math.max(0, ((numVal - min) / (max - min)) * 100))
      : 0
  );

  // Clamp display value for label formatting
  const displayValue = $derived(
    numVal != null ? Math.min(max, Math.max(min, numVal)) : 0
  );

  // sprintf-style label: %d, %f, %.Nf, %% for literal %
  function formatLabel(fmt: string, val: number): string {
    return fmt.replace(/%(\.\d+)?[df]|%%/g, (match) => {
      if (match === '%%') return '%';
      const precisionMatch = match.match(/^%\.(\d+)f$/);
      if (precisionMatch) return val.toFixed(Number(precisionMatch[1]));
      if (match === '%f') return val.toFixed(1);
      return String(Math.round(val));
    });
  }

  const labelText = $derived(showLabel ? formatLabel(labelFormat, displayValue) : '');

  // Color rules override variant — set bar color dynamically
  const ruleColor = $derived(
    numVal != null && colorRules?.length
      ? evaluateColorRules(numVal, colorRules, toComparable)
      : null
  );

  // Bar fill uses rule color if matched, otherwise variant CSS variable
  const barStyle = $derived(
    ruleColor
      ? `width: ${percentage}%; background-color: ${ruleColor};`
      : `width: ${percentage}%;`
  );

  // Tooltip: always show raw value
  let el = $state<HTMLDivElement>(null!);
  let title = $state('');

  function onenter() {
    title = numVal != null ? String(numVal) : '';
  }
  function onleave() { title = ''; }

  // Progress bar doesn't set cell background — style stays empty
  $effect(() => { style = ''; });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={el}
  class="ic-tbl-cell-pb"
  {title}
  onpointerenter={onenter}
  onpointerleave={onleave}
>
  <div class="ic-tbl-cell-pb__track">
    <div
      class="ic-tbl-cell-pb__bar"
      class:ic-tbl-cell-pb__bar--primary={!ruleColor && variant === 'primary'}
      class:ic-tbl-cell-pb__bar--secondary={!ruleColor && variant === 'secondary'}
      class:ic-tbl-cell-pb__bar--success={!ruleColor && variant === 'success'}
      class:ic-tbl-cell-pb__bar--warning={!ruleColor && variant === 'warning'}
      class:ic-tbl-cell-pb__bar--destructive={!ruleColor && variant === 'destructive'}
      style={barStyle}
    ></div>
  </div>
  {#if showLabel}
    <span class="ic-tbl-cell-pb__label">{labelText}</span>
  {/if}
</div>

<style>
  .ic-tbl-cell-pb {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    min-width: 0;
  }

  .ic-tbl-cell-pb__track {
    flex: 1;
    height: 6px;
    min-width: 0;
    background: var(--ic-secondary);
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
    overflow: hidden;
  }

  .ic-tbl-cell-pb__bar {
    height: 100%;
    border-radius: 2px;
    transition: width 0.15s ease;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  .ic-tbl-cell-pb__bar--primary { background-color: var(--ic-primary); }
  .ic-tbl-cell-pb__bar--secondary { background-color: var(--ic-muted-foreground); }
  .ic-tbl-cell-pb__bar--success { background-color: var(--ic-success); }
  .ic-tbl-cell-pb__bar--warning { background-color: var(--ic-warning); }
  .ic-tbl-cell-pb__bar--destructive { background-color: var(--ic-destructive); }

  .ic-tbl-cell-pb__label {
    flex-shrink: 0;
    font-size: 0.7rem;
    font-variant-numeric: tabular-nums;
    color: var(--ic-muted-foreground);
    min-width: 2.2em;
    text-align: right;
  }
</style>
