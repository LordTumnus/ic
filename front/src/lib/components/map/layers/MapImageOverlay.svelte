<!--
  MapImageOverlay.svelte — Image overlay on geographic bounds.
  Resolves ic.Asset to a data URI and creates an L.imageOverlay.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import { resolveAssetAsDataUri } from '$lib/utils/asset-cache';

  let {
    id = '',
    image = $bindable<string | { hash: string; mime?: string; data?: string } | null>(null),
    bounds = $bindable<number[][]>([[0, 0], [0, 0]]),
    opacity = $bindable(1.0),
    zIndex = $bindable(1),
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    image?: string | { hash: string; mime?: string; data?: string } | null;
    bounds?: number[][];
    opacity?: number;
    zIndex?: number;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let overlay: L.ImageOverlay | undefined;

  function resolveImageUrl(): string | null {
    if (!image) return null;
    if (typeof image === 'string') return image || null;
    if (typeof image === 'object' && image.hash) {
      return resolveAssetAsDataUri(image) ?? null;
    }
    return null;
  }

  function toBounds(b: number[][]): L.LatLngBoundsExpression {
    return [[b[0][0], b[0][1]], [b[1][0], b[1][1]]];
  }

  // --- Create overlay ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    overlay = untrack(() => {
      const url = resolveImageUrl();
      if (!url) return undefined;

      const o = L.imageOverlay(url, toBounds(bounds), {
        opacity,
        zIndex,
      });
      if (visible) o.addTo(target as L.Map);
      return o;
    });

    return () => {
      overlay?.remove();
      overlay = undefined;
    };
  });

  // --- Sync image change: remove + recreate ---
  $effect(() => {
    const _img = image;
    if (!overlay) return;

    const target = mapCtx.target;
    if (!target) return;

    const url = resolveImageUrl();
    if (!url) {
      overlay.remove();
      overlay = undefined;
      return;
    }

    const wasVisible = visible && (target as L.Map).hasLayer(overlay);
    overlay.remove();
    const newOverlay = L.imageOverlay(url, toBounds(bounds), { opacity, zIndex });
    if (wasVisible) newOverlay.addTo(target as L.Map);
    overlay = newOverlay;
  });

  // --- Sync bounds ---
  $effect(() => {
    const b = bounds;
    if (overlay) overlay.setBounds(toBounds(b));
  });

  // --- Sync opacity ---
  $effect(() => {
    const o = opacity;
    if (overlay) overlay.setOpacity(o);
  });

  // --- Sync visibility ---
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (overlay && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(overlay)) overlay.addTo(map);
      else if (!v && map.hasLayer(overlay)) overlay.remove();
    }
  });
</script>
