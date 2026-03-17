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
  } from '$lib/utils/edge-utils';

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

  const SAMPLE_COUNT = 200;
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
  function arrowMarker(type: string | undefined): string | undefined {
    switch (type) {
      case 'arrow': return 'url(#ic-marker-arrow)';
      case 'diamond': return 'url(#ic-marker-diamond)';
      case 'circle': return 'url(#ic-marker-circle)';
      default: return undefined;
    }
  }
  const markerStart = $derived(arrowMarker(data?.startArrow as string));
  const markerEnd = $derived(arrowMarker(data?.endArrow as string));

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

  onMount(() => {
    const sampler = createPathSampler();
    let rafId: number;
    let startTime = performance.now();

    function animate() {
      sampler.setPath(path);
      const totalLength = sampler.getTotalLength();
      if (totalLength <= 0) {
        rafId = requestAnimationFrame(animate);
        return;
      }

      const elapsed = (performance.now() - startTime) / 1000;
      // Phase offset: moves the waveform from source toward target
      // Time-based (not distance-based) so speed is consistent regardless of path length
      const timeOffset = elapsed * BASE_SPEED * speed;

      // Sample points along the edge path
      const points: { x: number; y: number }[] = [];

      for (let i = 0; i <= SAMPLE_COUNT; i++) {
        const frac = i / SAMPLE_COUNT;
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

        // Perpendicular normal (rotated 90° CCW)
        const nx = -dy / mag;
        const ny = dx / mag;

        // Adding timeOffset keeps t ≥ 0 (stable for exp-decay expressions).
        // Using (1 - frac) flips the spatial axis so the pattern travels
        // source → target while t stays non-negative.
        const t = (1 - frac) * frequency + timeOffset;
        const value = evaluateExpression(expression, t);
        const displacement = amplitude * value;

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

      rafId = requestAnimationFrame(animate);
    }

    rafId = requestAnimationFrame(animate);

    return () => {
      cancelAnimationFrame(rafId);
      sampler.destroy();
    };
  });

  const guideColor = $derived(
    selected ? 'var(--ic-primary)' : (guideEdgeColor || 'var(--ic-muted-foreground)'),
  );
</script>

<g class="ic-ne-signal-edge">
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
