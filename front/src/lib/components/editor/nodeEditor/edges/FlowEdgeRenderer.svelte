<!--
  FlowEdgeRenderer.svelte — Animated particle edge.

  Dots travel from source to target along the edge path.
  Particle count comes from the source node's OutputRate (via data.sourceOutputRate).
  Speed, size, and color are per-edge properties.

  Animation: requestAnimationFrame loop with getPointAtLength sampling.
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import type { EdgeProps } from '@xyflow/svelte';
  import { computeEdgePath, createPathSampler } from '$lib/utils/edge-utils';

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
  const speed = $derived((data?.sourceSpeed as number) ?? 1);
  const particleSize = $derived((data?.particleSize as number) ?? 3);
  const particleColor = $derived(
    (data?.particleColor as string) || 'var(--ic-primary)',
  );
  const edgeColor = $derived(
    (data?.color as string) || 'var(--ic-muted-foreground)',
  );
  const thickness = $derived((data?.thickness as number) ?? 1);

  // Arrow markers (from base Edge)
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

  const particleCount = $derived(
    Math.max(1, Math.round((data?.sourceOutputRate as number) ?? 3)),
  );

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

  // Particle positions (updated each frame)
  let particles: { x: number; y: number }[] = $state([]);

  // Animation loop
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
      // Fraction of path traversed (0→1), then scaled to pixel offset
      const frac = (elapsed * BASE_SPEED * speed) % 1;
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

      rafId = requestAnimationFrame(animate);
    }

    rafId = requestAnimationFrame(animate);

    return () => {
      cancelAnimationFrame(rafId);
      sampler.destroy();
    };
  });

  const strokeColor = $derived(selected ? 'var(--ic-primary)' : edgeColor);
</script>

<g class="ic-ne-flow-edge">
  <!-- Base edge path (muted line) -->
  <path
    d={path}
    fill="none"
    stroke={strokeColor}
    stroke-width={selected ? Math.max(thickness, 2) : thickness}
    marker-start={markerStart}
    marker-end={markerEnd}
    class="ic-ne-flow-edge__path"
  />

  <!-- Invisible interaction zone -->
  <path
    d={path}
    fill="none"
    stroke="transparent"
    stroke-width="20"
    class="ic-ne-flow-edge__interaction"
  />

  <!-- Animated particles -->
  {#each particles as p, i (i)}
    <circle
      cx={p.x}
      cy={p.y}
      r={particleSize}
      fill={particleColor}
      class="ic-ne-flow-edge__particle"
    />
  {/each}

  <!-- Label -->
  {#if label}
    <foreignObject
      x={labelX - 50}
      y={labelY - 10}
      width="100"
      height="20"
      class="ic-ne-flow-edge__label"
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
  .ic-ne-flow-edge__particle {
    pointer-events: none;
  }
</style>
