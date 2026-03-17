<!--
  StaticEdgeRenderer.svelte — Custom edge with configurable arrow markers.

  Uses BaseEdge from @xyflow/svelte for the path rendering, adding
  marker references for start/end arrows (arrow, diamond, circle).
  Supports the Animated prop for dash animation.
-->
<script lang="ts">
  import { BaseEdge, type EdgeProps } from '@xyflow/svelte';
  import { computeEdgePath, markerUrl } from '$lib/utils/edge-utils';
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

  const startArrow = $derived((data?.startArrow as string) || 'none');
  const endArrow = $derived((data?.endArrow as string) || 'none');
  const markerStart = $derived(markerUrl(id, startArrow));
  const markerEnd = $derived(markerUrl(id, endArrow));
  const animated = $derived((data?.animated as boolean) ?? false);

  const edgeColor = $derived((data?.color as string) || '');
  const thickness = $derived((data?.thickness as number) ?? 1);

  const resolvedColor = $derived(
    selected ? 'var(--ic-primary)' : (edgeColor || 'var(--ic-muted-foreground)'),
  );

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

<EdgeMarkerDefs edgeId={id} color={resolvedColor} {startArrow} {endArrow} />
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
