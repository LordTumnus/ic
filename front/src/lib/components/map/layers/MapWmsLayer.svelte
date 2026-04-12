<!--
  MapWmsLayer.svelte — Zero-DOM WMS tile layer component.
  Creates a ProxiedWmsLayer on the parent map via context.
  WMS tiles are fetched through the IC request() mechanism.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack, onMount } from 'svelte';
  import type { MapContext, LayerRegistry } from '../Map.svelte';
  import type { RequestFn, Resolution } from '$lib/types';
  import { ProxiedWmsLayer } from '$lib/utils/wms-proxy';
  import logger from '$lib/core/logger';

  let {
    id = '',
    url = $bindable(''),
    layers = $bindable(''),
    wmsStyles = $bindable(''),
    format = $bindable('image/png'),
    transparent = $bindable(true),
    version = $bindable('1.1.1'),
    opacity = $bindable(1.0),
    tileSize = $bindable(256),
    crs = $bindable('EPSG:3857'),
    name = $bindable(''),
    visible = $bindable(true),
    layerIndex = $bindable(0),
    // Events
    fetchStart,
    fetchEnd,
    // Methods
    refresh = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    url?: string;
    layers?: string;
    wmsStyles?: string;
    format?: string;
    transparent?: boolean;
    version?: string;
    opacity?: number;
    tileSize?: number;
    crs?: string;
    name?: string;
    visible?: boolean;
    layerIndex?: number;
    fetchStart?: (data: Record<string, never>) => void;
    fetchEnd?: (data: Record<string, never>) => void;
    refresh?: () => Resolution;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  const mapUtils = getContext<{ request?: RequestFn }>('ic-map-utils');
  const layerRegistry = getContext<LayerRegistry>('ic-map-layers');

  let layer: ProxiedWmsLayer | undefined;

  // Debounced fetch events
  let fetchShowTimer: ReturnType<typeof setTimeout> | undefined;
  let fetchHideTimer: ReturnType<typeof setTimeout> | undefined;
  let isFetching = false;

  /** Resolve Leaflet CRS object from string name */
  function resolveCrs(crsName: string): L.CRS {
    const crsMap: Record<string, L.CRS> = {
      'EPSG:3857': L.CRS.EPSG3857,
      'EPSG:4326': L.CRS.EPSG4326,
      'EPSG:3395': L.CRS.EPSG3395,
    };
    return crsMap[crsName] || L.CRS.EPSG3857;
  }

  // Create/recreate the WMS layer when the map becomes available
  $effect(() => {
    const target = mapCtx.target;
    const requestFn = mapUtils.request;
    if (!target || !requestFn || !('addLayer' in target)) return;

    layer = untrack(() => {
      const wms = new ProxiedWmsLayer(url, {
        requestFn,
        mimeHint: format,
        layers,
        styles: wmsStyles,
        format,
        transparent,
        version,
        crs: resolveCrs(crs),
        tileSize,
        maxZoom: 19,
      });

      wms.onLoadingChange = (loading) => {
        mapCtx.loading = loading;
        if (loading) {
          clearTimeout(fetchHideTimer);
          if (!isFetching) {
            fetchShowTimer = setTimeout(() => {
              isFetching = true;
              fetchStart?.({});
            }, 300);
          }
        }
      };
      wms.onAllLoadingChange = (loading) => {
        if (!loading) {
          clearTimeout(fetchShowTimer);
          fetchHideTimer = setTimeout(() => {
            if (isFetching) fetchEnd?.({});
            isFetching = false;
          }, 500);
        }
      };

      wms.addTo(target as L.Map);

      // Register with layer registry
      const entryId = id || crypto.randomUUID();
      const displayName = name || 'WMS Layer';
      if (layerRegistry) {
        layerRegistry.register({
          id: entryId,
          name: displayName,
          type: 'wms',
          getVisible: () => visible,
          setVisible: (v: boolean) => { visible = v; },
        });
        logger.info('MapWmsLayer', `Registered in layer control: "${displayName}"`);
      }

      return wms;
    });

    return () => {
      layer?.remove();
      layer = undefined;
      mapCtx.loading = false;
      const entryId = id || '';
      if (layerRegistry && entryId) {
        layerRegistry.deregister(entryId);
      }
    };
  });

  // Sync WMS parameters
  $effect(() => {
    const l = layers;
    const s = wmsStyles;
    const f = format;
    const t = transparent;
    const v = version;
    const c = crs;
    if (layer) {
      layer.setParams({
        layers: l,
        styles: s,
        format: f,
        transparent: t,
        version: v,
        crs: resolveCrs(c),
      });
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

  // Sync opacity
  $effect(() => {
    const o = opacity;
    if (layer) layer.setOpacity(o);
  });

  // Bind refresh method: clears frontend cache and redraws with cache-buster
  onMount(() => {
    refresh = (): Resolution => {
      if (layer) {
        layer.clearCache();
      }
      return { success: true, data: null };
    };
  });
</script>
