<!--
  SignalNode.svelte — Oscilloscope source node with embedded waveform preview.
  Evaluates a JS math expression f(t) via expr-eval and renders the result
  on a mini canvas. Y-axis auto-scales to show all points.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import { evaluateExpression } from '$lib/utils/edge-utils';

  type SignalData = {
    label: string;
    expression: string;
    frequency: number;
    previewTime: number;
    disabled: boolean;
    locked: boolean;
    outputs: PortDef[];
  };

  type SignalNodeType = Node<SignalData, 'ic.node.Signal'>;

  let { data, selected, dragging }: NodeProps<SignalNodeType> = $props();

  let hovered = $state(false);
  let canvas: HTMLCanvasElement | undefined = $state();

  const CANVAS_W = 140;
  const CANVAS_H = 56;
  const SAMPLE_COUNT = 200;

  // Redraw waveform when expression or previewTime changes
  $effect(() => {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const expr = data.expression || 'sin(2*pi*t)';
    const previewTime = data.previewTime ?? 2;

    // Sample the expression
    const values: number[] = [];
    for (let i = 0; i <= SAMPLE_COUNT; i++) {
      const t = (i / SAMPLE_COUNT) * previewTime;
      values.push(evaluateExpression(expr, t));
    }

    // Auto-scale Y
    let yMin = Infinity;
    let yMax = -Infinity;
    for (const v of values) {
      if (v < yMin) yMin = v;
      if (v > yMax) yMax = v;
    }
    if (!isFinite(yMin) || !isFinite(yMax) || yMin === yMax) {
      yMin = -1;
      yMax = 1;
    }
    const yPad = (yMax - yMin) * 0.1 || 0.1;
    yMin -= yPad;
    yMax += yPad;
    const yRange = yMax - yMin;

    // Get device pixel ratio for sharp rendering
    const dpr = window.devicePixelRatio || 1;
    canvas.width = CANVAS_W * dpr;
    canvas.height = CANVAS_H * dpr;
    ctx.scale(dpr, dpr);

    // Background
    const bgStyle = getComputedStyle(canvas).getPropertyValue('--ic-muted').trim() || '#1e1e2e';
    ctx.fillStyle = bgStyle;
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

    // Grid lines (horizontal)
    const gridColor = 'rgba(128, 128, 128, 0.15)';
    ctx.strokeStyle = gridColor;
    ctx.lineWidth = 0.5;
    for (let i = 1; i < 4; i++) {
      const gy = (i / 4) * CANVAS_H;
      ctx.beginPath();
      ctx.moveTo(0, gy);
      ctx.lineTo(CANVAS_W, gy);
      ctx.stroke();
    }
    // Vertical grid
    for (let i = 1; i < 6; i++) {
      const gx = (i / 6) * CANVAS_W;
      ctx.beginPath();
      ctx.moveTo(gx, 0);
      ctx.lineTo(gx, CANVAS_H);
      ctx.stroke();
    }

    // Zero line (if visible in range)
    if (yMin < 0 && yMax > 0) {
      const zeroY = CANVAS_H - ((0 - yMin) / yRange) * CANVAS_H;
      ctx.strokeStyle = 'rgba(128, 128, 128, 0.3)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(0, zeroY);
      ctx.lineTo(CANVAS_W, zeroY);
      ctx.stroke();
    }

    // Waveform
    const primaryStyle = getComputedStyle(canvas).getPropertyValue('--ic-primary').trim() || '#3b82f6';
    ctx.strokeStyle = primaryStyle;
    ctx.lineWidth = 1.5;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.beginPath();
    for (let i = 0; i <= SAMPLE_COUNT; i++) {
      const x = (i / SAMPLE_COUNT) * CANVAS_W;
      const y = CANVAS_H - ((values[i] - yMin) / yRange) * CANVAS_H;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-signal"
  class:ic-ne-signal--hovered={hovered && !selected && !dragging}
  class:ic-ne-signal--selected={selected}
  class:ic-ne-signal--dragging={dragging}
  class:ic-ne-signal--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <!-- Header -->
  <div class="ic-ne-signal__header">
    <span class="ic-ne-signal__badge">~</span>
    <span class="ic-ne-signal__title">{data.label || 'Signal'}</span>
  </div>

  <!-- Expression text -->
  {#if data.expression}
    <div class="ic-ne-signal__expression">
      <span class="ic-ne-signal__expr-text">{data.expression}</span>
    </div>
  {/if}

  <!-- Oscilloscope canvas -->
  <div class="ic-ne-signal__scope">
    <canvas
      bind:this={canvas}
      class="ic-ne-signal__canvas"
      style="width: {CANVAS_W}px; height: {CANVAS_H}px;"
    ></canvas>
  </div>

  <!-- Output handle on right, centered on canvas area -->
  {#if data.outputs?.[0]}
    <Handle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-signal__label">{data.label}</div>
{/if}

<style>
  .ic-ne-signal {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    width: 160px;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    overflow: clip;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-signal--hovered {
    border-color: var(--ic-muted-foreground);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-signal--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-signal--dragging {
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.28);
  }

  .ic-ne-signal--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Header */
  .ic-ne-signal__header {
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

  .ic-ne-signal__badge {
    font-family: monospace;
    font-size: 14px;
    font-weight: 700;
    opacity: 0.6;
    flex-shrink: 0;
  }

  .ic-ne-signal__title {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
  }

  /* Expression */
  .ic-ne-signal__expression {
    padding: 2px 8px;
    border-bottom: 1px solid rgba(128, 128, 128, 0.1);
  }

  .ic-ne-signal__expr-text {
    font-family: monospace;
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
    display: block;
  }

  /* Oscilloscope */
  .ic-ne-signal__scope {
    padding: 4px 6px 6px;
    display: flex;
    justify-content: center;
  }

  .ic-ne-signal__canvas {
    border-radius: 2px;
    border: 1px solid rgba(128, 128, 128, 0.15);
    display: block;
  }

  /* Label below */
  .ic-ne-signal__label {
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
  .ic-ne-signal :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
