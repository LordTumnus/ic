<!--
  StaticEdgeRenderer.svelte — Custom edge with configurable arrow markers.

  Uses BaseEdge from @xyflow/svelte for the path rendering, adding
  marker references for start/end arrows (arrow, diamond, circle).
  Supports the Animated prop for dash animation.
-->
<script lang="ts">
  import { BaseEdge, type EdgeProps } from '@xyflow/svelte';
  import { computeEdgePath } from '$lib/utils/edge-utils';

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
    interactionWidth,
  }: EdgeProps = $props();

  const geometry = $derived(
    (data?.geometry as string) || (data?.editorGeometry as string) || 'bezier',
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

  // Map arrow type strings to marker URLs
  function arrowMarker(type: string | undefined): string | undefined {
    switch (type) {
      case 'arrow':
        return 'url(#ic-marker-arrow)';
      case 'diamond':
        return 'url(#ic-marker-diamond)';
      case 'circle':
        return 'url(#ic-marker-circle)';
      default:
        return undefined;
    }
  }

  const markerStart = $derived(arrowMarker(data?.startArrow as string));
  const markerEnd = $derived(arrowMarker(data?.endArrow as string));
  const animated = $derived((data?.animated as boolean) ?? false);

  const edgeColor = $derived((data?.color as string) || '');
  const thickness = $derived((data?.thickness as number) ?? 1);

  const style = $derived.by(() => {
    const parts: string[] = [];
    if (selected) {
      parts.push('stroke: var(--ic-primary)');
      parts.push(`stroke-width: ${Math.max(thickness, 2)}`);
    } else {
      if (edgeColor) parts.push(`stroke: ${edgeColor}`);
      if (thickness !== 1) parts.push(`stroke-width: ${thickness}`);
    }
    return parts.join('; ');
  });
</script>

<BaseEdge
  {id}
  {path}
  {labelX}
  {labelY}
  {label}
  {markerStart}
  {markerEnd}
  {interactionWidth}
  class={animated ? 'animated' : ''}
  {style}
/>
