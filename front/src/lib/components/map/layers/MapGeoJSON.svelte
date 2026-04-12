<!--
  MapGeoJSON.svelte — GeoJSON feature collection layer.

  Supports per-feature styling via precomputed style arrays (computed
  by MATLAB function handles) and hover highlighting.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack, onMount } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { Resolution } from '$lib/types';

  interface FeatureStyle {
    color?: string;
    weight?: number;
    opacity?: number;
    fillColor?: string;
    fillOpacity?: number;
    dashArray?: string;
  }

  let {
    id = '',
    data = $bindable<Record<string, unknown>>({}),
    color = $bindable('#3388ff'),
    weight = $bindable(3),
    fill = $bindable(true),
    fillColor = $bindable(''),
    fillOpacity = $bindable(0.2),
    pointRadius = $bindable(8),
    featureStyles = $bindable<FeatureStyle[]>([]),
    featureHighlightStyles = $bindable<FeatureStyle[]>([]),
    featurePopups = $bindable<string[]>([]),
    featureTooltips = $bindable<string[]>([]),
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
    // Events
    featureClick,
    featureMouseOver,
    featureMouseOut,
    // Methods
    fitBounds = $bindable((): Resolution => ({ success: true, data: {} })),
    resetStyle = $bindable((): Resolution => ({ success: true, data: {} })),
  }: {
    id?: string;
    data?: Record<string, unknown>;
    color?: string;
    weight?: number;
    fill?: boolean;
    fillColor?: string;
    fillOpacity?: number;
    pointRadius?: number;
    featureStyles?: FeatureStyle[];
    featureHighlightStyles?: FeatureStyle[];
    featurePopups?: string[];
    featureTooltips?: string[];
    visible?: boolean;
    name?: string;
    layerIndex?: number;
    featureClick?: (data: { featureId: string; properties: Record<string, unknown>; latlng: [number, number] }) => void;
    featureMouseOver?: (data: { featureId: string; properties: Record<string, unknown>; latlng: [number, number] }) => void;
    featureMouseOut?: (data: { featureId: string; properties: Record<string, unknown> }) => void;
    fitBounds?: () => Resolution;
    resetStyle?: () => Resolution;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let layer: L.GeoJSON | undefined;
  // Map each Leaflet layer to its computed base style for reliable reset
  let baseStyleMap = new Map<L.Layer, L.PathOptions>();

  function getFeatureId(feature: any, index: number): string {
    return feature?.id != null ? String(feature.id)
      : feature?.properties?.id != null ? String(feature.properties.id)
      : String(index);
  }

  function defaultStyle(): L.PathOptions {
    return {
      color,
      weight,
      fill,
      fillColor: fillColor || color,
      fillOpacity,
    };
  }

  function buildLayer(geojsonData: any): L.GeoJSON {
    baseStyleMap = new Map();
    let featureIndex = 0;

    return L.geoJSON(geojsonData as any, {
      style: () => defaultStyle(),

      pointToLayer: (_feature, latlng) => {
        return L.circleMarker(latlng, { radius: pointRadius });
      },

      onEachFeature: (feature, featureLayer) => {
        const idx = featureIndex++;
        const fid = getFeatureId(feature, idx);
        const props = feature?.properties ?? {};

        // Compute and apply per-feature style, store for reset
        const base = defaultStyle();
        if (featureStyles.length > idx && featureStyles[idx]) {
          Object.assign(base, featureStyles[idx]);
        }
        if ('setStyle' in featureLayer) {
          (featureLayer as L.Path).setStyle(base);
        }
        baseStyleMap.set(featureLayer, base);

        // Bind popup if precomputed
        if (featurePopups.length > idx && featurePopups[idx]) {
          featureLayer.bindPopup(featurePopups[idx]);
        }

        // Bind tooltip if precomputed
        if (featureTooltips.length > idx && featureTooltips[idx]) {
          featureLayer.bindTooltip(featureTooltips[idx]);
        }

        featureLayer.on('click', (e: L.LeafletMouseEvent) => {
          featureClick?.({
            featureId: fid,
            properties: props,
            latlng: [e.latlng.lat, e.latlng.lng],
          });
        });

        featureLayer.on('mouseover', (e: L.LeafletMouseEvent) => {
          if (featureHighlightStyles.length > idx && featureHighlightStyles[idx]) {
            if ('setStyle' in featureLayer) {
              (featureLayer as L.Path).setStyle(featureHighlightStyles[idx] as L.PathOptions);
              if ('bringToFront' in featureLayer) {
                (featureLayer as L.Path).bringToFront();
              }
            }
          }
          featureMouseOver?.({
            featureId: fid,
            properties: props,
            latlng: [e.latlng.lat, e.latlng.lng],
          });
        });

        featureLayer.on('mouseout', () => {
          // Restore the computed base style (not Leaflet's resetStyle which re-calls style())
          const original = baseStyleMap.get(featureLayer);
          if (original && 'setStyle' in featureLayer) {
            (featureLayer as L.Path).setStyle(original);
          }
          featureMouseOut?.({
            featureId: fid,
            properties: props,
          });
        });
      },
    });
  }

  // --- Create layer ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    layer = untrack(() => {
      if (!data || !('features' in data)) return undefined;
      const l = buildLayer(data);
      if (visible) l.addTo(target as L.Map);
      return l;
    });

    return () => {
      baseStyleMap = new Map();
      layer?.remove();
      layer = undefined;
    };
  });

  // --- Rebuild on data or style changes ---
  $effect(() => {
    const d = data;
    void color, weight, fill, fillColor, fillOpacity, pointRadius, featureStyles, featureHighlightStyles, featurePopups, featureTooltips;
    if (!layer) return;

    const target = mapCtx.target;
    if (!target || !d || !('features' in d)) return;

    const wasVisible = visible && (target as L.Map).hasLayer(layer);
    layer.remove();
    featureLayers = [];
    const newLayer = buildLayer(d);
    if (wasVisible) newLayer.addTo(target as L.Map);
    layer = newLayer;
  });

  // --- Sync visibility ---
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (layer && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(layer)) layer.addTo(map);
      else if (!v && map.hasLayer(layer)) layer.remove();
    }
  });

  // --- Methods ---
  onMount(() => {
    fitBounds = (): Resolution => {
      if (layer && layer.getLayers().length > 0) {
        const target = mapCtx.target;
        if (target && 'fitBounds' in target) {
          (target as L.Map).fitBounds(layer.getBounds());
        }
      }
      return { success: true, data: {} };
    };
    resetStyle = (): Resolution => {
      if (layer) layer.resetStyle();
      return { success: true, data: {} };
    };
  });
</script>
