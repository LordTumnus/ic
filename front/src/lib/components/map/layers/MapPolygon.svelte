<!--
  MapPolygon.svelte — Zero-DOM polygon component.
  Creates an L.polygon on the parent map/group via context.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';

  let {
    id = '',
    positions = $bindable<number[][]>([]),
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
    positions?: number[][];
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
  let layer: L.Polygon | undefined;

  function toLatLngs(pos: number[][]): L.LatLngExpression[] {
    return pos.map(p => [p[0], p[1]] as L.LatLngTuple);
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
      const poly = L.polygon(toLatLngs(positions), styleOpts())
        .addTo(target as L.Map);

      poly.on('click', (e: L.LeafletMouseEvent) => {
        click?.({ latlng: [e.latlng.lat, e.latlng.lng] });
      });

      return poly;
    });

    return () => {
      layer?.remove();
      layer = undefined;
    };
  });

  // Sync positions
  $effect(() => {
    const p = positions;
    if (layer) layer.setLatLngs(toLatLngs(p));
  });

  // Sync style
  $effect(() => {
    const s = styleOpts();
    if (layer) layer.setStyle(s);
  });

  // Sync visibility
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (layer && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(layer)) layer.addTo(map);
      else if (!v && map.hasLayer(layer)) layer.remove();
    }
  });
</script>
