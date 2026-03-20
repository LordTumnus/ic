<!--
  DisplayNode.svelte — Multi-channel oscilloscope sink node.
  Real-time scrolling waveform from connected signal edges.
  Input ports are visible as small dots on the left edge (no labels).
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

  type DisplayData = {
    label: string;
    inputNumber: number;
    previewTime: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    inputSignals: InputSignal[];
  };

  type DisplayNodeType = Node<DisplayData, 'ic.node.Display'>;

  let { data, selected, dragging }: NodeProps<DisplayNodeType> = $props();

  let hovered = $state(false);
  let canvas: HTMLCanvasElement | undefined = $state();

  const CANVAS_W = 180;
  const CANVAS_H = 80;
  const SAMPLE_COUNT = 200;

  // Matches SignalEdgeRenderer: value at target = expression(elapsed * BASE_SPEED * speed)
  const BASE_SPEED = 0.5;

  // Channel colors (CSS variable names resolved at draw time)
  const CHANNEL_CSS_VARS = [
    '--ic-primary',
    '--ic-success',
    '--ic-warning',
    '--ic-destructive',
  ];
  const CHANNEL_FALLBACKS = ['#3b82f6', '#22c55e', '#f59e0b', '#ef4444'];

  // Cache DPR and computed style to avoid re-querying every frame
  let cachedStyle: CSSStyleDeclaration | null = null;
  let cachedDpr = 1;
  let dprSet = false;

  function drawFrame(timestamp: number) {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const previewTime = data.previewTime ?? 2;
    const signals = data.inputSignals ?? [];

    // Set up DPR once (or on resize)
    const dpr = window.devicePixelRatio || 1;
    if (!dprSet || dpr !== cachedDpr) {
      cachedDpr = dpr;
      canvas.width = CANVAS_W * dpr;
      canvas.height = CANVAS_H * dpr;
      dprSet = true;
    }

    // Reset transform and scale for this frame
    ctx.setTransform(cachedDpr, 0, 0, cachedDpr, 0, 0);

    // Cache computed style
    if (!cachedStyle) cachedStyle = getComputedStyle(canvas);
    const style = cachedStyle;

    // Background
    const bgColor = style.getPropertyValue('--ic-muted').trim() || '#1e1e2e';
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

    // Grid lines
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
    for (let i = 1; i < 8; i++) {
      const gx = (i / 8) * CANVAS_W;
      ctx.beginPath();
      ctx.moveTo(gx, 0);
      ctx.lineTo(gx, CANVAS_H);
      ctx.stroke();
    }

    if (signals.length === 0) {
      // No signal — draw flat zero line
      ctx.strokeStyle = 'rgba(128, 128, 128, 0.3)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(0, CANVAS_H / 2);
      ctx.lineTo(CANVAS_W, CANVAS_H / 2);
      ctx.stroke();
      return;
    }

    // Elapsed since mount — matches signal edge's time base
    const elapsed = (timestamp - mountTime) / 1000;

    // Sample all channels over a sliding window to find global Y range.
    // Each channel uses its own speed: t = elapsed * BASE_SPEED * speed.
    // The window spans [now - previewTime, now] in the channel's own time scale.
    const allChannels: number[][] = [];
    for (const sig of signals) {
      const values: number[] = [];
      if (sig.type === 'static') {
        // Static port — flat zero line
        for (let i = 0; i <= SAMPLE_COUNT; i++) values.push(0);
      } else {
        const expr = sig.expression || 'sin(2*pi*t)';
        const speed = sig.speed ?? 1;
        const tNow = elapsed * BASE_SPEED * speed;
        const tStart = tNow - previewTime;
        for (let i = 0; i <= SAMPLE_COUNT; i++) {
          const t = tStart + (i / SAMPLE_COUNT) * previewTime;
          values.push(evaluateExpression(expr, t));
        }
      }
      allChannels.push(values);
    }

    // Auto-scale Y across all channels
    let yMin = Infinity;
    let yMax = -Infinity;
    for (const values of allChannels) {
      for (const v of values) {
        if (v < yMin) yMin = v;
        if (v > yMax) yMax = v;
      }
    }
    if (!isFinite(yMin) || !isFinite(yMax) || yMin === yMax) {
      yMin = -1;
      yMax = 1;
    }
    const yPad = (yMax - yMin) * 0.1 || 0.1;
    yMin -= yPad;
    yMax += yPad;
    const yRange = yMax - yMin;

    // Zero line
    if (yMin < 0 && yMax > 0) {
      const zeroY = CANVAS_H - ((0 - yMin) / yRange) * CANVAS_H;
      ctx.strokeStyle = 'rgba(128, 128, 128, 0.3)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(0, zeroY);
      ctx.lineTo(CANVAS_W, zeroY);
      ctx.stroke();
    }

    // Draw each channel waveform
    for (let ch = 0; ch < allChannels.length; ch++) {
      const values = allChannels[ch];
      const cssVar = CHANNEL_CSS_VARS[ch % CHANNEL_CSS_VARS.length];
      const fallback = CHANNEL_FALLBACKS[ch % CHANNEL_FALLBACKS.length];
      const color = style.getPropertyValue(cssVar).trim() || fallback;

      ctx.strokeStyle = color;
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
    }
  }

  let unregister: (() => void) | null = null;
  let mountTime = 0;

  onMount(() => {
    mountTime = performance.now();
    unregister = registerAnimationCallback(drawFrame);
  });

  onDestroy(() => {
    if (unregister) unregister();
  });

  // Compute port vertical positions (evenly distributed along left edge)
  function portTopPercent(index: number, total: number): string {
    if (total <= 1) return '50%';
    const start = 30;
    const end = 70;
    const pct = start + (index / (total - 1)) * (end - start);
    return `${pct}%`;
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-display"
  class:ic-ne-display--hovered={hovered && !selected && !dragging}
  class:ic-ne-display--selected={selected}
  class:ic-ne-display--dragging={dragging}
  class:ic-ne-display--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <!-- Header -->
  <div class="ic-ne-display__header">
    <span class="ic-ne-display__badge">&#x229F;</span>
    <span class="ic-ne-display__title">{data.label || 'Display'}</span>
  </div>

  <!-- Oscilloscope canvas -->
  <div class="ic-ne-display__scope">
    <canvas
      bind:this={canvas}
      class="ic-ne-display__canvas"
      style="width: {CANVAS_W}px; height: {CANVAS_H}px;"
    ></canvas>
  </div>

  <!-- Input port dots (no labels, small, positioned on left edge) -->
  {#if data.inputs?.length}
    {#each data.inputs as port, i (port.name)}
      <div
        class="ic-ne-display__port-dot"
        style:top={portTopPercent(i, data.inputs.length)}
      >
        <Handle
          type="target"
          position={Position.Left}
          id={port.name}
          style="top: 0; left: 0; transform: none;"
        />
      </div>
    {/each}
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-display__label">{data.label}</div>
{/if}

<style>
  .ic-ne-display {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    width: 200px;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    overflow: clip;
    position: relative;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-display--hovered {
    border-color: var(--ic-muted-foreground);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-display--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-display--dragging {
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.28);
  }

  .ic-ne-display--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Header */
  .ic-ne-display__header {
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

  .ic-ne-display__badge {
    font-family: monospace;
    font-size: 14px;
    font-weight: 700;
    opacity: 0.6;
    flex-shrink: 0;
  }

  .ic-ne-display__title {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
  }

  /* Oscilloscope */
  .ic-ne-display__scope {
    padding: 4px 6px 6px;
    display: flex;
    justify-content: center;
  }

  .ic-ne-display__canvas {
    border-radius: 2px;
    border: 1px solid rgba(128, 128, 128, 0.15);
    display: block;
  }

  /* Port dots — small, positioned on left edge */
  .ic-ne-display__port-dot {
    position: absolute;
    left: -4px;
    width: 7px;
    height: 7px;
    border-radius: 2px;
    background: var(--ic-border);
    border: 1px solid rgba(0, 0, 0, 0.2);
    transform: translateY(-50%);
    transition: transform 0.12s ease, border-color 0.12s ease;
  }

  .ic-ne-display__port-dot:hover {
    transform: translateY(-50%) scale(1.4);
    border-color: rgba(0, 0, 0, 0.4);
  }

  /* Label below */
  .ic-ne-display__label {
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
    margin-top: 4px;
    pointer-events: none;
    user-select: none;
  }

  /* Handle hitbox — invisible but large enough to grab */
  .ic-ne-display__port-dot :global(.svelte-flow__handle) {
    width: 14px;
    height: 14px;
    border-radius: 2px;
    background: transparent;
    border: none;
    transform: translate(-50%, -50%);
    top: 50% !important;
    left: 50% !important;
  }
</style>
