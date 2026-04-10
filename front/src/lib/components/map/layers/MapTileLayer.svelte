<!--
  MapTileLayer.svelte — Zero-DOM tile layer component.
  Creates a ProxiedTileLayer on the parent map via context.
  Tiles are fetched through the IC request() mechanism.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { RequestFn } from '$lib/types';
  import { ProxiedTileLayer } from '$lib/utils/tile-proxy';
  import { tileProviders } from '$lib/utils/tile-providers';

  let {
    id = '',
    provider = $bindable('openstreetmap'),
    url = $bindable(''),
    subdomains = $bindable('abc'),
    tileSize = $bindable(256),
    maxNativeZoom = $bindable(19),
    visible = $bindable(true),
    opacity = $bindable(1.0),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    provider?: string;
    url?: string;
    subdomains?: string;
    tileSize?: number;
    maxNativeZoom?: number;
    visible?: boolean;
    opacity?: number;
    layerIndex?: number;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  const mapUtils = getContext<{ request?: RequestFn }>('ic-map-utils');

  let layer: ProxiedTileLayer | undefined;

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

    layer.addTo(target as L.Map);

    return () => {
      layer?.remove();
      layer = undefined;
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
