<!--
  GlobeTileLayer.svelte — Zero-DOM imagery tile layer.

  Creates a ProxiedImageryProvider + CesiumJS ImageryLayer on the parent
  Globe via context. Tiles flow through the IC BinaryChannel:
     requestBinary('tile', {z,x,y,url}) → MATLAB webread → raw bytes file
     frontend fetch() → ArrayBuffer → ImageBitmap → GPU texture.

  Reactive props: provider preset, custom URL, opacity, visibility,
  brightness, contrast. Changes that affect the tile URL recreate the
  layer (CesiumJS ImageryLayer doesn't support template swap).
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { ImageryLayer } from '@cesium/engine';
  import type { GlobeContext, GlobeUtils } from '../Globe.svelte';
  import { createProxiedImageryProvider } from '$lib/utils/cesium-imagery-provider';
  import logger from '$lib/core/logger';

  let {
    id = '',
    provider = $bindable('openstreetmap'),
    url = $bindable(''),
    name = $bindable(''),
    visible = $bindable(true),
    opacity = $bindable(1.0),
    maximumLevel = $bindable(19),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    provider?: string;
    url?: string;
    name?: string;
    visible?: boolean;
    opacity?: number;
    maximumLevel?: number;
    layerIndex?: number;
  } = $props();

  const globeCtx = getContext<GlobeContext>('ic-globe');
  const globeUtils = getContext<GlobeUtils>('ic-globe-utils');

  let layer: ImageryLayer | undefined;

  // Create/recreate the ImageryLayer whenever the Cesium widget becomes
  // available OR the tile source changes (provider/url/maximumLevel).
  // Everything else is untracked so opacity/visibility toggles don't
  // churn the layer.
  $effect(() => {
    const widget = globeCtx.widget;
    const requestBinary = globeUtils?.requestBinary;
    if (!widget || !requestBinary) return;

    // Track these explicitly so URL/provider changes rebuild the layer.
    const p = provider;
    const u = url;
    const maxLvl = maximumLevel;

    let imageryProvider;
    try {
      imageryProvider = createProxiedImageryProvider({
        provider: u ? undefined : p,
        url: u || undefined,
        requestBinary,
        maximumLevel: maxLvl,
      });
    } catch (err) {
      logger.warn('GlobeTileLayer', `provider construction failed: ${err}`);
      return;
    }

    // addImageryProvider returns the created ImageryLayer.
    const created = untrack(() => widget.imageryLayers.addImageryProvider(imageryProvider));
    created.alpha = untrack(() => opacity);
    created.show = untrack(() => visible);
    layer = created;

    logger.info('GlobeTileLayer', 'ImageryLayer added', {
      provider: u ? 'custom' : p,
      url: u,
    });

    return () => {
      if (layer && widget.imageryLayers.contains(layer)) {
        widget.imageryLayers.remove(layer, true); // destroy=true
      }
      layer = undefined;
    };
  });

  // Sync visibility (cheap: show/hide flag, no re-fetch)
  $effect(() => {
    const v = visible;
    if (layer) layer.show = v;
  });

  // Sync opacity
  $effect(() => {
    const o = opacity;
    if (layer) layer.alpha = o;
  });

  // id / name / layerIndex are set by MATLAB but not used by CesiumJS
  // directly — they exist for future LayersControl wiring.
  $effect(() => {
    void id;
    void name;
    void layerIndex;
  });
</script>
