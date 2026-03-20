<!--
  MeterNode.svelte — Analog gauge dial sink node.
  SVG-based arc gauge with animated needle tracking signal value.
  Tick marks and value labels show the Min→Max range.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import { evaluateExpression, registerAnimationCallback } from '$lib/utils/edge-utils';
  import { onMount, onDestroy } from 'svelte';

  type InputSignal = {
    portName: string;
    expression: string;
    frequency: number;
    speed: number;
    type: string;
  };

  type MeterData = {
    label: string;
    min: number;
    max: number;
    meterUnit: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    inputSignals: InputSignal[];
  };

  type MeterNodeType = Node<MeterData, 'ic.node.Meter'>;

  let { data, selected, dragging }: NodeProps<MeterNodeType> = $props();

  let hovered = $state(false);
  let needleAngle = $state(0);
  let displayValue = $state(0);

  // Gauge geometry constants
  const CX = 50;       // center x
  const CY = 48;       // center y (slightly below mid for the arc)
  const R = 36;             // arc radius
  const ARC_START = 210;    // degrees from 3 o'clock, CCW positive (7 o'clock)
  const ARC_END = -30;      // degrees (5 o'clock)
  const ARC_SWEEP = 240;    // total sweep degrees

  const MAJOR_TICKS = 5;   // number of major tick divisions
  const MINOR_TICKS = 4;   // minor ticks between majors

  // Convert angle (degrees, 0=3 o'clock, CCW positive) to SVG coords
  function polarToXY(angle: number, radius: number): { x: number; y: number } {
    const rad = (angle * Math.PI) / 180;
    return { x: CX + radius * Math.cos(rad), y: CY - radius * Math.sin(rad) };
  }

  // Generate tick marks
  const ticks = $derived.by(() => {
    type Tick = { x1: number; y1: number; x2: number; y2: number; major: boolean; label?: string; lx?: number; ly?: number };
    const result: Tick[] = [];
    const min = data.min ?? 0;
    const max = data.max ?? 100;
    const totalTicks = MAJOR_TICKS * MINOR_TICKS;

    for (let i = 0; i <= totalTicks; i++) {
      const frac = i / totalTicks;
      const angle = ARC_START - frac * ARC_SWEEP;
      const isMajor = i % MINOR_TICKS === 0;
      const innerR = isMajor ? R - 8 : R - 5;
      const outer = polarToXY(angle, R);
      const inner = polarToXY(angle, innerR);
      const tick: Tick = {
        x1: inner.x, y1: inner.y,
        x2: outer.x, y2: outer.y,
        major: isMajor,
      };
      if (isMajor) {
        const val = min + frac * (max - min);
        tick.label = Number.isInteger(val) ? val.toString() : val.toFixed(1);
        const lp = polarToXY(angle, R - 14);
        tick.lx = lp.x;
        tick.ly = lp.y;
      }
      result.push(tick);
    }
    return result;
  });

  // Arc path for the gauge background
  const arcPath = $derived.by(() => {
    const start = polarToXY(ARC_START, R);
    const end = polarToXY(ARC_END, R);
    // Large arc flag: sweep > 180
    return `M ${start.x} ${start.y} A ${R} ${R} 0 1 1 ${end.x} ${end.y}`;
  });

  // Animate needle from inputSignals.
  // Matches SignalEdgeRenderer: value at target = expression(elapsed * BASE_SPEED * speed)
  const BASE_SPEED = 0.5;

  let unregister: (() => void) | null = null;
  let mountTime = 0;

  onMount(() => {
    mountTime = performance.now();
    unregister = registerAnimationCallback((timestamp: number) => {
      const signals = data.inputSignals;
      const min = data.min ?? 0;
      const max = data.max ?? 100;
      const range = max - min || 1;

      if (!signals || signals.length === 0) {
        // No signal connected — reset to minimum
        needleAngle = ARC_START;
        displayValue = min;
        return;
      }

      const sig = signals[0];
      if (sig.type === 'static') {
        // Static port — show constant zero
        needleAngle = ARC_START - ((0 - min) / range) * ARC_SWEEP;
        displayValue = 0;
        return;
      }
      const elapsed = (timestamp - mountTime) / 1000;
      const t = elapsed * BASE_SPEED * (sig.speed ?? 1);
      const raw = evaluateExpression(sig.expression || '0', t);
      const clamped = Math.max(min, Math.min(max, raw));
      const frac = (clamped - min) / range;

      // Map fraction to angle
      needleAngle = ARC_START - frac * ARC_SWEEP;
      displayValue = Math.round(raw * 100) / 100;
    });
  });

  onDestroy(() => {
    if (unregister) unregister();
  });

  // Needle endpoint
  const needleTip = $derived(polarToXY(needleAngle, R - 4));
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-meter"
  class:ic-ne-meter--hovered={hovered && !selected && !dragging}
  class:ic-ne-meter--selected={selected}
  class:ic-ne-meter--dragging={dragging}
  class:ic-ne-meter--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <!-- Header -->
  <div class="ic-ne-meter__header">
    <span class="ic-ne-meter__badge">&#x25D4;</span>
    <span class="ic-ne-meter__title">{data.label || 'Meter'}</span>
  </div>

  <!-- Gauge SVG -->
  <div class="ic-ne-meter__gauge-wrap">
    <svg class="ic-ne-meter__gauge" viewBox="0 0 100 72" xmlns="http://www.w3.org/2000/svg">
      <!-- Arc track -->
      <path
        d={arcPath}
        fill="none"
        stroke="var(--ic-border)"
        stroke-width="2"
        stroke-linecap="round"
      />

      <!-- Tick marks -->
      {#each ticks as tick, idx (idx)}
        <line
          x1={tick.x1} y1={tick.y1}
          x2={tick.x2} y2={tick.y2}
          stroke="var(--ic-muted-foreground)"
          stroke-width={tick.major ? 1.5 : 0.8}
          stroke-linecap="round"
        />
        {#if tick.label}
          <text
            x={tick.lx}
            y={tick.ly}
            text-anchor="middle"
            dominant-baseline="middle"
            class="ic-ne-meter__tick-label"
          >{tick.label}</text>
        {/if}
      {/each}

      <!-- Needle -->
      <line
        x1={CX}
        y1={CY}
        x2={needleTip.x}
        y2={needleTip.y}
        stroke="var(--ic-primary)"
        stroke-width="2"
        stroke-linecap="round"
      />

      <!-- Center pivot -->
      <circle cx={CX} cy={CY} r="3" fill="var(--ic-primary)" />

      <!-- Value display -->
      <text
        x={CX}
        y={CY + 14}
        text-anchor="middle"
        class="ic-ne-meter__value-text"
      >{displayValue}{data.meterUnit ? ' ' + data.meterUnit : ''}</text>
    </svg>
  </div>

  <!-- Input handle on left -->
  {#if data.inputs?.[0]}
    <Handle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-meter__label">{data.label}</div>
{/if}

<style>
  .ic-ne-meter {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    width: 130px;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    overflow: clip;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-meter--hovered {
    border-color: var(--ic-muted-foreground);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-meter--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-meter--dragging {
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.28);
  }

  .ic-ne-meter--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Header */
  .ic-ne-meter__header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    background: var(--ic-muted);
    font-weight: 600;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--ic-muted-foreground);
  }

  .ic-ne-meter__badge {
    font-size: 13px;
    opacity: 0.6;
    flex-shrink: 0;
  }

  .ic-ne-meter__title {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
  }

  /* Gauge */
  .ic-ne-meter__gauge-wrap {
    padding: 4px 6px 2px;
    display: flex;
    justify-content: center;
  }

  .ic-ne-meter__gauge {
    width: 100%;
    height: auto;
  }

  .ic-ne-meter__tick-label {
    font-family: var(--ic-font-family);
    font-size: 6px;
    fill: var(--ic-muted-foreground);
  }

  .ic-ne-meter__value-text {
    font-family: monospace;
    font-size: 8px;
    font-weight: 600;
    fill: var(--ic-foreground);
  }

  /* Label below */
  .ic-ne-meter__label {
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
    margin-top: 4px;
    pointer-events: none;
    user-select: none;
  }

  /* Hide SF's default handle visuals */
  .ic-ne-meter :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
