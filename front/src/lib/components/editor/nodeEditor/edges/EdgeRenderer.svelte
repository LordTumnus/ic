<!--
  EdgeRenderer.svelte — Unified edge renderer that switches mode based on data.type.

  Rendering modes:
    - "static": simple stroked path with optional dash animation
    - "flow": animated particles traveling source → target
    - "signal": faded guide line + animated waveform overlay

  All modes share: path computation, marker defs, interaction zone, label.
  Uses the global clock for coherent animations across the graph.
-->
<script lang="ts">
  import type { EdgeProps } from '@xyflow/svelte';
  import {
    computeEdgePath,
    createPathSampler,
    evaluateExpression,
    registerAnimationCallback,
    markerUrl,
  } from '$lib/utils/edge-utils';
  import EdgeMarkerDefs from './EdgeMarkerDefs.svelte';

  let {
    id,
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition,
    data = {},
    selected = false,
    label,
  }: EdgeProps = $props();

  const BASE_SPEED = 0.5;

  // Common props
  const edgeType = $derived((data?.type as string) || 'static');
  const geometry = $derived(
    (data?.geometry as string) || (data?.editorGeometry as string) || 'bezier',
  );
  const edgeColor = $derived((data?.color as string) || '');
  const thickness = $derived((data?.thickness as number) ?? 1);
  const startArrow = $derived((data?.startArrow as string) || 'none');
  const endArrow = $derived((data?.endArrow as string) || 'none');
  const markerStart = $derived(markerUrl(id, startArrow));
  const markerEnd = $derived(markerUrl(id, endArrow));

  // Static-specific
  const animated = $derived((data?.animated as boolean) ?? false);

  // Flow-specific
  const particleSize = $derived((data?.particleSize as number) ?? 3);
  const particleColor = $derived(
    (data?.particleColor as string) || 'var(--ic-primary)',
  );
  const particleCount = $derived(
    Math.max(1, Math.round((data?.sourceOutputRate as number) ?? 3)),
  );

  // Signal-specific
  const expression = $derived((data?.sourceExpression as string) || 'sin(2*pi*t)');
  const amplitude = $derived((data?.amplitude as number) ?? 8);
  const frequency = $derived((data?.sourceFrequency as number) ?? 2);
  const waveColor = $derived((data?.signalColor as string) || 'var(--ic-primary)');
  const signalThickness = $derived((data?.signalThickness as number) ?? 2);

  // Speed (shared by flow + signal)
  const speed = $derived((data?.sourceSpeed as number) ?? 1);

  const pathResult = $derived(
    computeEdgePath(geometry, {
      sourceX, sourceY, sourcePosition,
      targetX, targetY, targetPosition,
    }),
  );
  const path = $derived(pathResult[0]);
  const labelX = $derived(pathResult[1]);
  const labelY = $derived(pathResult[2]);

  const strokeColor = $derived(
    selected ? 'var(--ic-primary)' : (edgeColor || 'var(--ic-muted-foreground)'),
  );

  // Animation state
  let particles: { x: number; y: number }[] = $state([]);
  let waveformPath: string = $state('');

  // Animation via shared coordinator (one rAF for all animated edges)
  // Uses global clock — no per-edge startTime
  // Reactive: re-registers when animated/edgeType changes (e.g. cascade sets type to signal)
  $effect(() => {
    const shouldAnimate = (edgeType === 'flow' || edgeType === 'signal') && animated;
    if (!shouldAnimate) {
      particles = [];
      waveformPath = '';
      return;
    }

    const sampler = createPathSampler();

    const unregister = registerAnimationCallback((globalTime) => {
      sampler.setPath(path);
      const totalLength = sampler.getTotalLength();
      if (totalLength <= 0) return;

      const currentType = edgeType;

      if (currentType === 'flow') {
        // -- Flow: animated particles --
        const frac = (globalTime * BASE_SPEED * speed) % 1;
        const offset = frac * totalLength;
        const count = particleCount;
        const spacing = totalLength / count;

        const pts: { x: number; y: number }[] = [];
        for (let i = 0; i < count; i++) {
          const len = (offset + i * spacing) % totalLength;
          const pt = sampler.getPointAtLength(len);
          pts.push({ x: pt.x, y: pt.y });
        }
        particles = pts;
        waveformPath = '';
      } else if (currentType === 'signal') {
        // -- Signal: animated waveform --
        const timeOffset = globalTime * BASE_SPEED * speed;
        const sampleCount = Math.min(200, Math.max(30, Math.round(totalLength / 3)));

        const samples: { frac: number; value: number }[] = [];
        let sum = 0;
        for (let i = 0; i <= sampleCount; i++) {
          const frac = i / sampleCount;
          const t = (1 - frac) * frequency + timeOffset;
          const value = evaluateExpression(expression, t);
          samples.push({ frac, value });
          sum += value;
        }
        const mean = sum / samples.length;

        // Normalize amplitude
        let maxAbsDev = 0;
        for (let i = 0; i <= sampleCount; i++) {
          const dev = Math.abs(samples[i].value - mean);
          if (dev > maxAbsDev) maxAbsDev = dev;
        }
        if (maxAbsDev < 0.001) maxAbsDev = 0.001;

        const points: { x: number; y: number }[] = [];
        for (let i = 0; i <= sampleCount; i++) {
          const { frac, value } = samples[i];
          const len = frac * totalLength;
          const pt = sampler.getPointAtLength(len);

          const lenBefore = Math.max(0, len - 1);
          const lenAfter = Math.min(totalLength, len + 1);
          const ptBefore = sampler.getPointAtLength(lenBefore);
          const ptAfter = sampler.getPointAtLength(lenAfter);

          const dx = ptAfter.x - ptBefore.x;
          const dy = ptAfter.y - ptBefore.y;
          const mag = Math.sqrt(dx * dx + dy * dy) || 1;

          const nx = dy / mag;
          const ny = -dx / mag;
          const displacement = amplitude * (value - mean) / maxAbsDev;

          points.push({
            x: pt.x + nx * displacement,
            y: pt.y + ny * displacement,
          });
        }

        if (points.length > 0) {
          let d = `M ${points[0].x} ${points[0].y}`;
          for (let i = 1; i < points.length; i++) {
            d += ` L ${points[i].x} ${points[i].y}`;
          }
          waveformPath = d;
        }
        particles = [];
      }
    });

    return () => {
      unregister();
      sampler.destroy();
    };
  });
</script>

<g class="ic-ne-edge" class:ic-ne-edge--selected={selected}>
  <EdgeMarkerDefs edgeId={id} color={strokeColor} {startArrow} {endArrow} />

  <!-- Base edge path -->
  <path
    d={path}
    fill="none"
    stroke={strokeColor}
    stroke-width={selected ? Math.max(thickness, 2) : thickness}
    stroke-opacity={edgeType === 'signal' && animated ? 0.2 : 1}
    stroke-dasharray={edgeType === 'static' && animated ? '6 4' : undefined}
    marker-start={markerStart}
    marker-end={markerEnd}
    class="ic-ne-edge__path"
    class:ic-ne-edge__path--animated={edgeType === 'static' && animated}
  />

  <!-- Signal: animated waveform overlay -->
  {#if edgeType === 'signal' && animated && waveformPath}
    <path
      d={waveformPath}
      fill="none"
      stroke={selected ? 'var(--ic-primary)' : waveColor}
      stroke-width={signalThickness}
      stroke-linecap="round"
      stroke-linejoin="round"
      class="ic-ne-edge__waveform"
    />
  {/if}

  <!-- Flow: animated particles -->
  {#if edgeType === 'flow' && animated}
    {#each particles as p, i (i)}
      <circle
        cx={p.x}
        cy={p.y}
        r={particleSize}
        fill={particleColor}
        class="ic-ne-edge__particle"
      />
    {/each}
  {/if}

  <!-- Invisible interaction zone -->
  <path
    d={path}
    fill="none"
    stroke="transparent"
    stroke-width="20"
    class="ic-ne-edge__interaction"
  />

  <!-- Label -->
  {#if label}
    <foreignObject
      x={labelX - 50}
      y={labelY - 10}
      width="100"
      height="20"
      class="ic-ne-edge__label"
    >
      <div
        xmlns="http://www.w3.org/1999/xhtml"
        style="font-size: 10px; text-align: center; color: var(--ic-muted-foreground);"
      >
        {label}
      </div>
    </foreignObject>
  {/if}
</g>

<style>
  .ic-ne-edge__waveform,
  .ic-ne-edge__particle {
    pointer-events: none;
  }

  @keyframes dash-flow {
    to { stroke-dashoffset: -20; }
  }

  .ic-ne-edge__path--animated {
    animation: dash-flow 0.8s linear infinite;
  }
</style>
