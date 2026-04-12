<!--
  MapHeatLayer.svelte — Zero-DOM heatmap layer component.
  Uses leaflet.heat to render point data with intensity as a heatmap overlay.
-->
<script lang="ts">
  import L from 'leaflet';
  import 'leaflet.heat';
  import { getContext, untrack } from 'svelte';
  import type { MapContext, LayerRegistry } from '../Map.svelte';
  import logger from '$lib/core/logger';

  let {
    id = '',
    data = $bindable<number[][]>([]),
    radius = $bindable(25),
    maxIntensity = $bindable(0),
    minOpacity = $bindable(0.05),
    blur = $bindable(15),
    gradientPositions = $bindable<number[]>([0.4, 0.65, 1]),
    gradientColors = $bindable<string[]>(['blue', 'lime', 'red']),
    name = $bindable(''),
    visible = $bindable(true),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    data?: number[][];
    radius?: number;
    maxIntensity?: number;
    minOpacity?: number;
    blur?: number;
    gradientPositions?: number[];
    gradientColors?: string[];
    name?: string;
    visible?: boolean;
    layerIndex?: number;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  const layerRegistry = getContext<LayerRegistry>('ic-map-layers');

  let layer: L.HeatLayer | undefined;

  /** Convert parallel position/color arrays to leaflet.heat gradient object */
  function buildGradient(
    positions: number[],
    colors: string[],
  ): Record<number, string> | undefined {
    if (!positions.length || positions.length !== colors.length) return undefined;
    const gradient: Record<number, string> = {};
    for (let i = 0; i < positions.length; i++) {
      gradient[positions[i]] = colors[i];
    }
    return gradient;
  }

  /** Convert data matrix to leaflet.heat latlngs format */
  function convertData(
    raw: number[][],
  ): Array<[number, number] | [number, number, number]> {
    if (!raw || !raw.length) return [];
    return raw.map((row) => {
      if (row.length >= 3) return [row[0], row[1], row[2]] as [number, number, number];
      return [row[0], row[1]] as [number, number];
    });
  }

  // Create the heat layer when the map becomes available
  $effect(() => {
    const target = mapCtx.target;
    if (!target || !('addLayer' in target)) return;

    layer = untrack(() => {
      const gradient = buildGradient(gradientPositions, gradientColors);
      const map = target as L.Map;
      const opts: L.HeatLayerOptions = {
        radius,
        blur,
        minOpacity,
        gradient,
        maxZoom: map.getMaxZoom() || 18,
      };
      if (maxIntensity > 0) opts.max = maxIntensity;

      const latlngs = convertData(data);
      const heat = L.heatLayer(latlngs, opts);
      heat.addTo(target as L.Map);

      // Register with layer registry
      const entryId = id || crypto.randomUUID();
      const displayName = name || 'Heat Layer';
      if (layerRegistry) {
        layerRegistry.register({
          id: entryId,
          name: displayName,
          type: 'heat',
          getVisible: () => visible,
          setVisible: (v: boolean) => { visible = v; },
        });
        logger.info('MapHeatLayer', `Registered in layer control: "${displayName}"`);
      }

      return heat;
    });

    return () => {
      layer?.remove();
      layer = undefined;
      const entryId = id || '';
      if (layerRegistry && entryId) {
        layerRegistry.deregister(entryId);
      }
    };
  });

  // Sync data changes
  $effect(() => {
    const d = data;
    if (layer) {
      layer.setLatLngs(convertData(d));
    }
  });

  // Sync heat options
  $effect(() => {
    const r = radius;
    const b = blur;
    const mo = minOpacity;
    const mi = maxIntensity;
    const gp = gradientPositions;
    const gc = gradientColors;
    if (layer) {
      const gradient = buildGradient(gp, gc);
      const opts: L.HeatLayerOptions = { radius: r, blur: b, minOpacity: mo, gradient };
      if (mi > 0) opts.max = mi;
      layer.setOptions(opts);
      layer.redraw();
    }
  });

  // Sync visibility
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (layer && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(layer)) {
        layer.addTo(map);
      } else if (!v && map.hasLayer(layer)) {
        layer.remove();
      }
    }
  });
</script>
