<!--
  SignalEdgeRenderer.svelte — Waveform edge with math expression evaluation.

  Renders a faded guide line + animated waveform overlay. The waveform shape
  is defined by a math expression f(t) evaluated via expr-eval. The waveform
  travels from source to target, creating a propagating signal effect.

  Two-layer rendering:
    1. Faded guide line (same path, reduced opacity) — always shows the route
    2. Animated waveform displaced perpendicular to the path
-->
<script lang="ts">
  import { onMount } from 'svelte';
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

  const BASE_SPEED = 0.5; // path-traversals per second at speed=1

  const geometry = $derived(
    (data?.geometry as string) || (data?.editorGeometry as string) || 'bezier',
  );
  const expression = $derived((data?.sourceExpression as string) || 'sin(2*pi*t)');
  const amplitude = $derived((data?.amplitude as number) ?? 8);
  const frequency = $derived((data?.sourceFrequency as number) ?? 2);
  const speed = $derived((data?.sourceSpeed as number) ?? 1);
  const waveColor = $derived((data?.signalColor as string) || 'var(--ic-primary)');
  const signalThickness = $derived((data?.signalThickness as number) ?? 2);

  // Base Edge props (guide line)
  const guideEdgeColor = $derived((data?.color as string) || '');
  const guideThickness = $derived((data?.thickness as number) ?? 1);

  // Arrow markers (from base Edge — rendered on guide line)
  const startArrow = $derived((data?.startArrow as string) || 'none');
  const endArrow = $derived((data?.endArrow as string) || 'none');
  const markerStart = $derived(markerUrl(id, startArrow));
  const markerEnd = $derived(markerUrl(id, endArrow));

  const pathResult = $derived(
    computeEdgePath(geometry, {
      sourceX,
      sourceY,
      sourcePosition,
      targetX,
      targetY,
      targetPosition,
    }),
  );

  const path = $derived(pathResult[0]);
  const labelX = $derived(pathResult[1]);
  const labelY = $derived(pathResult[2]);

  // Waveform path (updated each frame)
  let waveformPath: string = $state('');

  // Animation via shared coordinator (one rAF for all animated edges)
  onMount(() => {
    const sampler = createPathSampler();
    const startTime = performance.now();

    const unregister = registerAnimationCallback((timestamp) => {
      sampler.setPath(path);
      const totalLength = sampler.getTotalLength();
      if (totalLength <= 0) return;

      const elapsed = (timestamp - startTime) / 1000;
      const timeOffset = elapsed * BASE_SPEED * speed;

      // Dynamic sample count: scale with edge length, clamp to [30, 200]
      const sampleCount = Math.min(200, Math.max(30, Math.round(totalLength / 3)));
      const points: { x: number; y: number }[] = [];

      // Two-pass: evaluate expression at all samples, center around mean (remove DC offset)
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

      for (let i = 0; i <= sampleCount; i++) {
        const { frac, value } = samples[i];
        const len = frac * totalLength;
        const pt = sampler.getPointAtLength(len);

        // Compute tangent from adjacent points for perpendicular normal
        const lenBefore = Math.max(0, len - 1);
        const lenAfter = Math.min(totalLength, len + 1);
        const ptBefore = sampler.getPointAtLength(lenBefore);
        const ptAfter = sampler.getPointAtLength(lenAfter);

        const dx = ptAfter.x - ptBefore.x;
        const dy = ptAfter.y - ptBefore.y;
        const mag = Math.sqrt(dx * dx + dy * dy) || 1;

        const nx = -dy / mag;
        const ny = dx / mag;

        // Subtract mean so waveform is centered on the guide line
        const displacement = amplitude * (value - mean);

        points.push({
          x: pt.x + nx * displacement,
          y: pt.y + ny * displacement,
        });
      }

      // Build SVG path from displaced points
      if (points.length > 0) {
        let d = `M ${points[0].x} ${points[0].y}`;
        for (let i = 1; i < points.length; i++) {
          d += ` L ${points[i].x} ${points[i].y}`;
        }
        waveformPath = d;
      }
    });

    return () => {
      unregister();
      sampler.destroy();
    };
  });

  const guideColor = $derived(
    selected ? 'var(--ic-primary)' : (guideEdgeColor || 'var(--ic-muted-foreground)'),
  );
</script>

<g class="ic-ne-signal-edge">
  <EdgeMarkerDefs edgeId={id} color={guideColor} {startArrow} {endArrow} />
  <!-- Faded guide line (always shows the connection route) -->
  <path
    d={path}
    fill="none"
    stroke={guideColor}
    stroke-width={selected ? Math.max(guideThickness, 2) : guideThickness}
    stroke-opacity="0.2"
    marker-start={markerStart}
    marker-end={markerEnd}
    class="ic-ne-signal-edge__guide"
  />

  <!-- Animated waveform overlay -->
  {#if waveformPath}
    <path
      d={waveformPath}
      fill="none"
      stroke={selected ? 'var(--ic-primary)' : waveColor}
      stroke-width={signalThickness}
      stroke-linecap="round"
      stroke-linejoin="round"
      class="ic-ne-signal-edge__waveform"
    />
  {/if}

  <!-- Invisible interaction zone -->
  <path
    d={path}
    fill="none"
    stroke="transparent"
    stroke-width="20"
    class="ic-ne-signal-edge__interaction"
  />

  <!-- Label -->
  {#if label}
    <foreignObject
      x={labelX - 50}
      y={labelY - 10}
      width="100"
      height="20"
      class="ic-ne-signal-edge__label"
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
  .ic-ne-signal-edge__waveform {
    pointer-events: none;
  }
</style>
