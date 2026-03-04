<script lang="ts">
  import type { ProgressBarConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';
  import { toComparable } from './utils';

  let {
    value,
    config = {} as Partial<ProgressBarConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<ProgressBarConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
  } = $props();

  const numVal = $derived(value != null ? Number(value) : null);
  const min = $derived(config.min ?? 0);
  const max = $derived(config.max ?? 100);
  const showLabel = $derived(config.showLabel ?? false);
  const labelFormat = $derived(config.labelFormat ?? '%d%%');
  const variant = $derived(config.variant ?? 'primary');
  const colorRules = $derived(config.colorRules as ColorRuleConfig[] | undefined);

  // ── Drag editing state ─────────────────────────
  let dragging = $state(false);
  let dragVal = $state<number | null>(null);

  // Active value: drag value during drag, else data value
  const activeVal = $derived(dragging && dragVal != null ? dragVal : numVal);

  const percentage = $derived(
    activeVal != null && max !== min
      ? Math.min(100, Math.max(0, ((activeVal - min) / (max - min)) * 100))
      : 0
  );

  // Clamp display value for label formatting
  const displayValue = $derived(
    activeVal != null ? Math.min(max, Math.max(min, activeVal)) : 0
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
    activeVal != null && colorRules?.length
      ? evaluateColorRules(activeVal, colorRules, toComparable)
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

  // ── Drag handlers ──────────────────────────────

  let trackEl = $state<HTMLDivElement>(null!);

  function valueFromPointer(e: PointerEvent): number {
    const rect = trackEl.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    const raw = min + ratio * (max - min);
    return Math.round(raw * 10) / 10;  // round to 1 decimal
  }

  function handlePointerDown(e: PointerEvent) {
    if (!editing) return;
    e.stopPropagation();
    e.preventDefault();
    dragging = true;
    dragVal = valueFromPointer(e);
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  }

  function handlePointerMove(e: PointerEvent) {
    if (!dragging) return;
    dragVal = valueFromPointer(e);
  }

  function handlePointerUp(e: PointerEvent) {
    if (!dragging) return;
    const finalVal = valueFromPointer(e);
    dragging = false;
    dragVal = null;
    oncommitedit?.(value, finalVal);
  }

  function handleEditKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Escape') {
      e.preventDefault();
      dragging = false;
      dragVal = null;
      oncanceledit?.();
    }
  }
</script>

<div
  bind:this={el}
  class="ic-tbl-cell-pb"
  class:ic-tbl-cell-pb--editing={editing}
  {title}
  role="slider"
  aria-valuenow={activeVal ?? 0}
  aria-valuemin={min}
  aria-valuemax={max}
  onpointerenter={onenter}
  onpointerleave={onleave}
  onkeydown={handleEditKeydown}
  tabindex={editing ? 0 : -1}
>
  <div
    bind:this={trackEl}
    class="ic-tbl-cell-pb__track"
    class:ic-tbl-cell-pb__track--interactive={editing}
    onpointerdown={handlePointerDown}
    onpointermove={handlePointerMove}
    onpointerup={handlePointerUp}
  >
    <div
      class="ic-tbl-cell-pb__bar"
      class:ic-tbl-cell-pb__bar--primary={!ruleColor && variant === 'primary'}
      class:ic-tbl-cell-pb__bar--secondary={!ruleColor && variant === 'secondary'}
      class:ic-tbl-cell-pb__bar--success={!ruleColor && variant === 'success'}
      class:ic-tbl-cell-pb__bar--warning={!ruleColor && variant === 'warning'}
      class:ic-tbl-cell-pb__bar--destructive={!ruleColor && variant === 'destructive'}
      class:ic-tbl-cell-pb__bar--dragging={dragging}
      style={barStyle}
    ></div>
    {#if editing}
      <div class="ic-tbl-cell-pb__thumb" style:left="{percentage}%"></div>
    {/if}
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
    position: relative;
    flex: 1;
    height: 6px;
    min-width: 0;
    background: var(--ic-secondary);
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
    overflow: visible;
  }
  .ic-tbl-cell-pb__track--interactive {
    cursor: ew-resize;
    height: 8px;
  }

  .ic-tbl-cell-pb__bar {
    height: 100%;
    border-radius: 2px;
    transition: width 0.15s ease;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }
  .ic-tbl-cell-pb__bar--dragging {
    transition: none;
  }

  .ic-tbl-cell-pb__bar--primary { background-color: var(--ic-primary); }
  .ic-tbl-cell-pb__bar--secondary { background-color: var(--ic-muted-foreground); }
  .ic-tbl-cell-pb__bar--success { background-color: var(--ic-success); }
  .ic-tbl-cell-pb__bar--warning { background-color: var(--ic-warning); }
  .ic-tbl-cell-pb__bar--destructive { background-color: var(--ic-destructive); }

  .ic-tbl-cell-pb__thumb {
    position: absolute;
    top: -3px;
    width: 2px;
    height: calc(100% + 6px);
    background: var(--ic-foreground);
    border-radius: 1px;
    transform: translateX(-1px);
    pointer-events: none;
  }

  .ic-tbl-cell-pb__label {
    flex-shrink: 0;
    font-size: 0.7rem;
    font-variant-numeric: tabular-nums;
    color: var(--ic-muted-foreground);
    min-width: 2.2em;
    text-align: right;
  }

  .ic-tbl-cell-pb--editing {
    outline: 1px solid var(--ic-primary);
    outline-offset: 1px;
    border-radius: 2px;
    padding: 2px 0;
  }
</style>
