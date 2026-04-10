<!--
  MapCircle.svelte — Zero-DOM circle component (radius in meters).
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';

  let {
    id = '',
    center = $bindable<[number, number]>([0, 0]),
    radius = $bindable(100),
    color = $bindable('#3388ff'),
    weight = $bindable(3),
    dashArray = $bindable(''),
    lineCap = $bindable('round'),
    lineJoin = $bindable('round'),
    fill = $bindable(true),
    fillColor = $bindable(''),
    visible = $bindable(true),
    layerIndex = $bindable(0),
    click,
  }: {
    id?: string;
    center?: [number, number];
    radius?: number;
    color?: string;
    weight?: number;
    dashArray?: string;
    lineCap?: string;
    lineJoin?: string;
    fill?: boolean;
    fillColor?: string;
    visible?: boolean;
    layerIndex?: number;
    click?: (data: { latlng: [number, number] }) => void;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let layer: L.Circle | undefined;

  function styleOpts() {
    return {
      color, weight,
      dashArray: dashArray || undefined,
      lineCap: lineCap as L.LineCapShape,
      lineJoin: lineJoin as L.LineJoinShape,
      fill,
      fillColor: fillColor || color,
    };
  }

  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    layer = untrack(() => {
      const c = L.circle([center[0], center[1]], { radius, ...styleOpts() })
        .addTo(target as L.Map);
      c.on('click', (e: L.LeafletMouseEvent) => {
        click?.({ latlng: [e.latlng.lat, e.latlng.lng] });
      });
      return c;
    });

    return () => { layer?.remove(); layer = undefined; };
  });

  $effect(() => { const c = center; if (layer) layer.setLatLng([c[0], c[1]]); });
  $effect(() => { const r = radius; if (layer) layer.setRadius(r); });
  $effect(() => { const s = styleOpts(); if (layer) layer.setStyle(s); });
  $effect(() => {
    const v = visible; const target = mapCtx.target;
    if (layer && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(layer)) layer.addTo(map);
      else if (!v && map.hasLayer(layer)) layer.remove();
    }
  });
</script>
