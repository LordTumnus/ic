<!--
  MapTooltip.svelte — Standalone tooltip at a fixed geographic position.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';

  let {
    id = '',
    position = $bindable<[number, number]>([0, 0]),
    content = $bindable(''),
    permanent = $bindable(true),
    direction = $bindable('auto'),
    opacity = $bindable(0.9),
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    position?: [number, number];
    content?: string;
    permanent?: boolean;
    direction?: string;
    opacity?: number;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let tooltip: L.Tooltip | undefined;

  // --- Create tooltip ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    tooltip = untrack(() => {
      const t = L.tooltip({
        permanent,
        direction: direction as L.Direction,
        opacity,
      })
        .setLatLng([position[0], position[1]])
        .setContent(content);

      if (visible) {
        t.addTo(target as L.Map);
      }

      return t;
    });

    return () => {
      tooltip?.remove();
      tooltip = undefined;
    };
  });

  // --- Sync props ---
  $effect(() => {
    const p = position;
    if (tooltip) tooltip.setLatLng([p[0], p[1]]);
  });
  $effect(() => {
    const c = content;
    if (tooltip) tooltip.setContent(c);
  });
  $effect(() => {
    const o = opacity;
    if (tooltip) tooltip.setOpacity(o);
  });
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (tooltip && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(tooltip as any)) (tooltip as any).addTo(map);
      else if (!v && map.hasLayer(tooltip as any)) tooltip.remove();
    }
  });
</script>
