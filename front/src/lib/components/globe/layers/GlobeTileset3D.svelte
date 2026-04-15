<!--
  GlobeTileset3D.svelte — Streaming 3D Tiles layer.

  Creates a CesiumJS Cesium3DTileset and adds it to the globe's primitive
  list. Every fetch (tileset.json, .b3dm/.i3dm/.pnts/.glb child tiles)
  routes through the 'tileset3d' BinaryChannel via our ProxiedResource,
  so the whole hierarchy streams through MATLAB webread.

  Source selection:
    - ionAssetId > 0  → resolve via Globe's MATLAB-side Ion handshake
                        and build a ProxiedResource against the asset's
                        tile-server URL + per-session token
    - url non-empty    → ProxiedResource directly on the user's URL
    - otherwise       → no-op (tileset not created)

  Pose override: if position is [NaN, NaN], the tileset uses its baked-in
  georeferencing (the 90% case for OSM Buildings, Google 3D Tiles, etc.).
  If position is set, we build a modelMatrix from HPR + altitude and
  apply a uniform scale, overriding the baked transform entirely.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import {
    Cesium3DTileset,
    Cesium3DTileStyle,
    Cesium3DTileColorBlendMode,
    Cartesian3,
    Color,
    HeadingPitchRoll,
    Matrix4,
    Transforms,
    Math as CesiumMath,
  } from '@cesium/engine';
  import type { GlobeContext, GlobeUtils } from '../Globe.svelte';
  import { createProxiedResource } from '$lib/utils/cesium-resource-proxy';
  import logger from '$lib/core/logger';

  interface IonAssetEndpoint {
    type: string;
    url: string;
    accessToken: string;
    attributions?: unknown[];
  }

  let {
    id = '',
    url = $bindable(''),
    ionAssetId = $bindable(0),
    maximumScreenSpaceError = $bindable(16),
    position = $bindable<[number, number]>([NaN, NaN]),
    altitude = $bindable(0),
    heading = $bindable(0),
    pitch = $bindable(0),
    roll = $bindable(0),
    scale = $bindable(1.0),
    color = $bindable<number[]>([]),
    colorBlendAmount = $bindable(0.5),
    style = $bindable<Record<string, unknown>>({}),
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
    loaded,
    allTilesLoaded,
    error,
  }: {
    id?: string;
    url?: string;
    ionAssetId?: number;
    maximumScreenSpaceError?: number;
    position?: [number, number];
    altitude?: number;
    heading?: number;
    pitch?: number;
    roll?: number;
    scale?: number;
    color?: number[];
    colorBlendAmount?: number;
    style?: Record<string, unknown>;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
    loaded?: (data: { boundingSphere: number[] }) => void;
    allTilesLoaded?: (data: Record<string, never>) => void;
    error?: (data: { message: string }) => void;
  } = $props();

  const globeCtx = getContext<GlobeContext>('ic-globe');
  const globeUtils = getContext<GlobeUtils>('ic-globe-utils');

  let tileset: Cesium3DTileset | undefined;

  // Resolve Ion asset to a fetchable URL via the MATLAB handshake (same
  // reason as terrain: CEF can't reach api.cesium.com directly).
  async function resolveSourceUrl(utils: GlobeUtils, ionId: number, directUrl: string): Promise<string> {
    if (ionId > 0) {
      if (!utils.request) throw new Error('request fn missing on Globe utils');
      const resp = await utils.request('resolveIonAsset', { assetId: ionId });
      if (!resp?.success) {
        throw new Error(`Ion handshake failed: ${String(resp?.data ?? 'unknown')}`);
      }
      const endpoint = resp.data as IonAssetEndpoint;
      const sep = endpoint.url.includes('?') ? '&' : '?';
      return `${endpoint.url}${sep}access_token=${encodeURIComponent(endpoint.accessToken)}`;
    }
    if (!directUrl) throw new Error('Tileset3D requires either IonAssetId or Url');
    return directUrl;
  }

  // Build a modelMatrix from HPR + altitude + scale. Returns undefined
  // when Position is [NaN, NaN] — the caller should then leave
  // tileset.modelMatrix alone so the tileset's baked transform is used
  // untouched. Assigning even Matrix4.IDENTITY propagates through
  // Cesium's per-tile transform cache, which is expensive on add-refine
  // tilesets with many tiles and can cause visible "slide" during
  // camera motion as tiles reapply positions.
  function buildModelMatrix(
    pos: [number, number],
    alt: number,
    h: number,
    p: number,
    r: number,
    s: number,
  ): Matrix4 | undefined {
    if (!Number.isFinite(pos[0]) || !Number.isFinite(pos[1])) {
      return undefined;
    }
    const origin = Cartesian3.fromDegrees(pos[1], pos[0], alt);
    const hpr = new HeadingPitchRoll(
      CesiumMath.toRadians(h),
      CesiumMath.toRadians(p),
      CesiumMath.toRadians(r),
    );
    const m = Transforms.headingPitchRollToFixedFrame(origin, hpr);
    if (s !== 1.0) Matrix4.multiplyByUniformScale(m, s, m);
    return m;
  }

  // Convert a [r,g,b,a] 0..1 array to a CesiumJS Color. Empty/invalid
  // arrays return undefined so the tileset keeps its material as-is.
  function toCesiumColor(rgba: number[]): Color | undefined {
    if (!Array.isArray(rgba) || rgba.length < 3) return undefined;
    return new Color(rgba[0], rgba[1], rgba[2], rgba.length >= 4 ? rgba[3] : 1.0);
  }

  // Build the tileset asynchronously. Creates + installs. Returns
  // undefined on failure (error event already fired).
  async function buildTileset(utils: GlobeUtils): Promise<Cesium3DTileset | undefined> {
    const widget = globeCtx.widget;
    if (!widget || !utils.requestBinary) return undefined;

    try {
      const sourceUrl = await resolveSourceUrl(utils, untrack(() => ionAssetId), untrack(() => url));
      const resource = createProxiedResource({
        url: sourceUrl,
        channel: 'tileset3d',
        requestBinary: utils.requestBinary,
      });
      const t = await Cesium3DTileset.fromUrl(resource, {
        maximumScreenSpaceError: untrack(() => maximumScreenSpaceError),
      });
      widget.scene.primitives.add(t);
      return t;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      logger.warn('GlobeTileset3D', `build failed: ${message}`);
      error?.({ message });
      return undefined;
    }
  }

  // Lifecycle: create the tileset when the widget is ready + source info
  // is set. Rebuild on source change (url or ionAssetId).
  $effect(() => {
    const widget = globeCtx.widget;
    if (!widget || !globeUtils) return;

    // Track only source-changing inputs. Pose/style/color are handled
    // by separate effects that apply to the existing tileset.
    const u = url;
    const ionId = ionAssetId;
    if (!u && !(ionId > 0)) return;

    let disposed = false;

    (async () => {
      const t = await buildTileset(globeUtils);
      if (disposed || !t) {
        if (t) widget.scene.primitives.remove(t);
        return;
      }
      tileset = t;
      logger.info('GlobeTileset3D', 'tileset installed', {
        source: u || `ion:${ionId}`,
      });

      // Initial pose / style / color / visibility pass. The tracking
      // effects below handle subsequent changes.
      applyAll();

      // Event wiring. Cesium's events use addEventListener (Event class).
      t.initialTilesLoaded.addEventListener(() => {
        const bs = t.boundingSphere;
        loaded?.({
          boundingSphere: [bs.center.x, bs.center.y, bs.center.z, bs.radius],
        });
      });
      t.allTilesLoaded.addEventListener(() => {
        allTilesLoaded?.({});
      });
      t.tileFailed.addEventListener((err: { url?: string; message?: string }) => {
        error?.({ message: `tile failed: ${err?.url ?? '?'} — ${err?.message ?? ''}` });
      });
    })();

    return () => {
      disposed = true;
      if (tileset) {
        try {
          widget.scene.primitives.remove(tileset);
        } catch {
          // Widget may have been destroyed between mount and cleanup.
        }
        tileset = undefined;
      }
    };
  });

  // Apply current pose / style / color in one go. Called on initial
  // install and whenever a tracked prop changes.
  function applyAll(): void {
    if (!tileset) return;
    tileset.show = visible;
    tileset.maximumScreenSpaceError = maximumScreenSpaceError;
    const mm = buildModelMatrix(position, altitude, heading, pitch, roll, scale);
    if (mm !== undefined) tileset.modelMatrix = mm;

    const tintColor = toCesiumColor(color);
    if (tintColor) {
      tileset.colorBlendMode = Cesium3DTileColorBlendMode.HIGHLIGHT;
      tileset.colorBlendAmount = colorBlendAmount;
      // @ts-expect-error — Cesium3DTileset has a `color` setter but TS types miss it
      tileset.color = tintColor;
    }

    // Style is a declarative Cesium3DTileStyle. Only rebuild when the
    // struct has keys; an empty struct = "no style override".
    const styleKeys = Object.keys(style ?? {});
    if (styleKeys.length > 0) {
      try {
        tileset.style = new Cesium3DTileStyle(style as Record<string, string>);
      } catch (err) {
        logger.warn('GlobeTileset3D', `style apply failed: ${err}`);
      }
    } else {
      tileset.style = undefined;
    }
  }

  // Pose / style / visibility tracking — rerun applyAll when any of
  // these change. Cheap: all writes are property assignments on an
  // already-installed tileset.
  $effect(() => {
    // Explicitly read the tracked props so Svelte's reactivity graph
    // wires them up.
    void position[0]; void position[1];
    void altitude; void heading; void pitch; void roll; void scale;
    void color; void colorBlendAmount; void style;
    void maximumScreenSpaceError; void visible;
    applyAll();
  });

  // id / name / layerIndex are framework housekeeping, not consumed by
  // Cesium directly. They exist for future LayersControl support.
  $effect(() => { void id; void name; void layerIndex; });
</script>
