<!--
  MapRectangle.svelte — Zero-DOM rectangle component.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';

  let {
    id = '',
    bounds = $bindable<number[][]>([[0, 0], [0, 0]]),
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
    bounds?: number[][];
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
  let layer: L.Rectangle | undefined;

  function toBounds(b: number[][]): L.LatLngBoundsExpression {
    return [[b[0][0], b[0][1]], [b[1][0], b[1][1]]];
  }

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
      const r = L.rectangle(toBounds(bounds), styleOpts())
        .addTo(target as L.Map);
      r.on('click', (e: L.LeafletMouseEvent) => {
        click?.({ latlng: [e.latlng.lat, e.latlng.lng] });
      });
      return r;
    });

    return () => { layer?.remove(); layer = undefined; };
  });

  $effect(() => { const b = bounds; if (layer) layer.setBounds(toBounds(b)); });
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
