<!--
  MapTileLayer.svelte — Zero-DOM tile layer component.
  Creates a ProxiedTileLayer on the parent map via context.
  Tiles are fetched through the IC request() mechanism.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { MapContext, LayerRegistry } from '../Map.svelte';
  import type { RequestFn } from '$lib/types';
  import { ProxiedTileLayer } from '$lib/utils/tile-proxy';
  import { tileProviders } from '$lib/utils/tile-providers';
  import logger from '$lib/core/logger';

  let {
    id = '',
    provider = $bindable('openstreetmap'),
    url = $bindable(''),
    name = $bindable(''),
    subdomains = $bindable('abc'),
    tileSize = $bindable(256),
    maxNativeZoom = $bindable(19),
    visible = $bindable(true),
    opacity = $bindable(1.0),
    layerIndex = $bindable(0),
    // Events
    fetchStart,
    fetchEnd,
  }: {
    id?: string;
    provider?: string;
    url?: string;
    name?: string;
    subdomains?: string;
    tileSize?: number;
    maxNativeZoom?: number;
    visible?: boolean;
    opacity?: number;
    layerIndex?: number;
    fetchStart?: (data: Record<string, never>) => void;
    fetchEnd?: (data: Record<string, never>) => void;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  const mapUtils = getContext<{ request?: RequestFn }>('ic-map-utils');
  const layerRegistry = getContext<LayerRegistry>('ic-map-layers');

  let layer: ProxiedTileLayer | undefined;

  // Debounced fetch events: avoid flickering on quick load cycles
  let fetchShowTimer: ReturnType<typeof setTimeout> | undefined;
  let fetchHideTimer: ReturnType<typeof setTimeout> | undefined;
  let isFetching = false;

  function resolveUrlTemplate(): string {
    // If explicit URL is provided, use it; otherwise resolve from provider preset
    if (url) return url;
    const preset = tileProviders[provider];
    return preset?.url ?? tileProviders['openstreetmap'].url;
  }

  function resolveAttribution(): string {
    if (url) return '';
    const preset = tileProviders[provider];
    return preset?.attribution ?? '';
  }

  // Create/recreate the tile layer when the map or provider/url changes
  $effect(() => {
    const target = mapCtx.target;
    const requestFn = mapUtils.request;
    if (!target || !requestFn || !('addLayer' in target)) return;

    const urlTemplate = untrack(() => resolveUrlTemplate());
    const attribution = untrack(() => resolveAttribution());

    layer = new ProxiedTileLayer({
      urlTemplate,
      requestFn,
      subdomains: untrack(() => subdomains),
      tileSize: untrack(() => tileSize),
      maxNativeZoom: untrack(() => maxNativeZoom),
      maxZoom: 19,
      attribution,
    });

    layer.onLoadingChange = (loading) => {
      mapCtx.loading = loading;
      // FetchStart fires when viewport tiles start loading (debounced)
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
    layer.onAllLoadingChange = (loading) => {
      // FetchEnd fires when ALL tiles (viewport + prefetch) are done
      if (!loading) {
        clearTimeout(fetchShowTimer);
        fetchHideTimer = setTimeout(() => {
          if (isFetching) fetchEnd?.({});
          isFetching = false;
        }, 500);
      }
    };

    layer.addTo(target as L.Map);

    // Register with layer registry (untracked to avoid re-triggering this effect)
    const entryId = untrack(() => id || crypto.randomUUID());
    const displayName = untrack(() => name || provider || 'Tile Layer');
    untrack(() => {
      if (layerRegistry) {
        layerRegistry.register({
          id: entryId,
          name: displayName,
          type: 'tile',
          getVisible: () => visible,
          setVisible: (v: boolean) => { visible = v; },
        });
        logger.info('MapTileLayer', `Registered in layer control: "${displayName}"`);
      }
    });

    return () => {
      layer?.remove();
      layer = undefined;
      mapCtx.loading = false;
      if (layerRegistry) {
        layerRegistry.deregister(entryId);
        logger.info('MapTileLayer', `Deregistered from layer control: "${displayName}"`);
      }
    };
  });

  // Sync provider/url changes → update URL template and redraw tiles
  $effect(() => {
    const p = provider;
    const u = url;
    if (layer) {
      const urlTemplate = u || tileProviders[p]?.url || tileProviders['openstreetmap'].url;
      layer.setUrlTemplate(urlTemplate);
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
</script>
