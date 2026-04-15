<!--
  GlobeTerrain.svelte — Zero-DOM 3D elevation provider.

  Sets viewer.scene.terrainProvider to a CesiumTerrainProvider whose
  fetches route through the IC BinaryChannel. Terrain layer.json + each
  per-tile .terrain payload flow through the 'terrain' channel:
    requestBinary('terrain', {url}) → MATLAB webread → raw bytes file
    frontend fetch() → ArrayBuffer → CesiumJS quantized-mesh worker.

  Provider presets:
    - 'cesium-world' : Cesium World Terrain (Ion-hosted, asset id 1)
    - 'custom'       : user-supplied quantized-mesh URL

  Cesium World Terrain requires Globe.IonToken to be set (it's an
  Ion-hosted asset). When the token is missing or wrong, Ion responds
  with 401 → emits the 'error' event.

  This component is the singleton terrain controller. There is exactly
  one of these per ic.Globe (auto-created MATLAB-side as g.Terrain).
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import {
    CesiumTerrainProvider,
    EllipsoidTerrainProvider,
    Terrain,
  } from '@cesium/engine';
  import type { GlobeContext, GlobeUtils } from '../Globe.svelte';
  import { createProxiedResource } from '$lib/utils/cesium-resource-proxy';
  import logger from '$lib/core/logger';

  const ION_WORLD_TERRAIN_ASSET_ID = 1;

  // Shape of api.cesium.com/v1/assets/{id}/endpoint response.
  interface IonAssetEndpoint {
    type: string;
    url: string;
    accessToken: string;
    attributions?: unknown[];
  }

  let {
    id = '',
    enabled = $bindable(false),
    provider = $bindable<'cesium-world' | 'custom'>('cesium-world'),
    url = $bindable(''),
    exaggeration = $bindable(1.0),
    exaggerationRelativeHeight = $bindable(0),
    // Events
    loaded,
    error,
  }: {
    id?: string;
    enabled?: boolean;
    provider?: 'cesium-world' | 'custom';
    url?: string;
    exaggeration?: number;
    exaggerationRelativeHeight?: number;
    loaded?: (data: { provider: string }) => void;
    error?: (data: { message: string }) => void;
  } = $props();

  const globeCtx = getContext<GlobeContext>('ic-globe');
  const globeUtils = getContext<GlobeUtils>('ic-globe-utils');

  // Track the currently-installed terrain so cleanup knows what to
  // revert to. We always end on EllipsoidTerrainProvider when disabled
  // or when destroying the component.
  let activeProvider: CesiumTerrainProvider | undefined;

  // Whether we've already resolved Globe's deferred terrain promise.
  // First install resolves it (in-place upgrade, no flash). Subsequent
  // provider changes use scene.setTerrain (will visibly swap).
  let installedOnce = false;

  // Build the (Cesium)TerrainProvider asynchronously. Returns undefined
  // on failure (already logged + error event already fired).
  async function buildProvider(
    p: 'cesium-world' | 'custom',
    u: string,
    utils: GlobeUtils,
  ): Promise<CesiumTerrainProvider | undefined> {
    const { requestBinary, request } = utils;
    if (!requestBinary) return undefined;

    try {
      let providerUrl: string;

      if (p === 'cesium-world') {
        // CEF Chromium 104 can't reach api.cesium.com directly. MATLAB
        // performs the Ion handshake via webread and returns the
        // resolved tile-server URL + a per-session token. We then build
        // a ProxiedResource against that URL so every subsequent tile
        // fetch routes through the 'terrain' BinaryChannel.
        if (!request) throw new Error('request fn missing on Globe utils');
        const resp = await request('resolveIonAsset', { assetId: ION_WORLD_TERRAIN_ASSET_ID });
        if (!resp?.success) {
          throw new Error(`Ion handshake failed: ${String(resp?.data ?? 'unknown')}`);
        }
        const endpoint = resp.data as IonAssetEndpoint;
        // Append per-session token as a query parameter; Ion's tile
        // server accepts either Authorization header or this query form.
        const sep = endpoint.url.includes('?') ? '&' : '?';
        providerUrl = `${endpoint.url}${sep}access_token=${encodeURIComponent(endpoint.accessToken)}`;
      } else {
        if (!u) throw new Error('Terrain provider="custom" requires a non-empty url');
        providerUrl = u;
      }

      const resource = createProxiedResource({
        url: providerUrl,
        channel: 'terrain',
        requestBinary,
        cacheSize: 200,
        maxInFlight: 6,
      });
      // NOTE: no `requestVertexNormals`/`requestWaterMask` — those tell
      // Cesium to set an extensions Accept header on tile fetches, and
      // our ProxiedResource currently drops request headers on the way
      // to MATLAB webread. Enabling them would cause Cesium's worker to
      // parse the default tile format as if it contained extensions,
      // producing garbled geometry. Can be re-enabled once we plumb
      // headers through requestBinary.
      return await CesiumTerrainProvider.fromUrl(resource);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      logger.warn('GlobeTerrain', `provider build failed: ${message}`);
      error?.({ message });
      return undefined;
    }
  }

  // Main lifecycle: create or destroy the terrain provider when
  // enabled/provider/url change. Exaggeration is handled separately
  // (it's a scene property, no rebuild needed).
  $effect(() => {
    const widget = globeCtx.widget;
    if (!widget || !globeUtils?.requestBinary) return;

    // Track the inputs that require a rebuild.
    const isEnabled = enabled;
    const p = provider;
    const u = url;

    let disposed = false;

    if (!isEnabled) {
      // Revert to flat ellipsoid.
      widget.scene.setTerrain(new Terrain(Promise.resolve(new EllipsoidTerrainProvider())));
      activeProvider = undefined;
      return () => { disposed = true; };
    }

    (async () => {
      const newProvider = await buildProvider(p, u, globeUtils);
      if (disposed || !newProvider) return;

      if (!installedOnce && globeUtils.resolveTerrain) {
        // First install: resolve the deferred terrain promise that was
        // bound at CesiumWidget construction time. Cesium upgrades from
        // ellipsoid to terrain in place — no surface rebuild, no flash.
        globeUtils.resolveTerrain(newProvider);
        installedOnce = true;
      } else {
        // Subsequent provider changes (user switched providers at
        // runtime): use scene.setTerrain — there will be a swap, but at
        // that point the user already has imagery rendered and is
        // actively interacting, so a brief blip is acceptable.
        widget.scene.setTerrain(new Terrain(Promise.resolve(newProvider)));
      }
      activeProvider = newProvider;
      logger.info('GlobeTerrain', 'terrain installed', { provider: p });
      loaded?.({ provider: p });
    })().catch((err) => {
      const message = err instanceof Error ? err.message : String(err);
      logger.error('GlobeTerrain', `setTerrain failed: ${message}`);
      error?.({ message });
    });

    return () => {
      disposed = true;
      // Don't aggressively revert here — the next $effect run will
      // either install a new provider (if still enabled) or fall into
      // the `if (!isEnabled)` branch above on next mount.
    };
  });

  // Vertical exaggeration is a scene property — applies on top of any
  // active terrain provider. Setting it without a terrain provider has
  // no visible effect (ellipsoid has no elevation to scale).
  $effect(() => {
    const widget = globeCtx.widget;
    if (!widget) return;
    const x = exaggeration;
    const h = exaggerationRelativeHeight;
    untrack(() => {
      widget.scene.verticalExaggeration = x;
      widget.scene.verticalExaggerationRelativeHeight = h;
    });
  });

  // Cleanup: on destroy, revert to flat. The widget itself may already
  // be torn down by Globe.svelte; guard against that.
  $effect(() => {
    return () => {
      const widget = globeCtx.widget;
      if (widget && !widget.isDestroyed?.()) {
        try {
          widget.scene.setTerrain(new Terrain(Promise.resolve(new EllipsoidTerrainProvider())));
        } catch {
          // Widget may be destroyed mid-teardown; silently ignore.
        }
      }
      activeProvider = undefined;
    };
  });

  // id is set by the framework but not used directly by Cesium.
  $effect(() => { void id; });
</script>
