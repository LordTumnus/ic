<!--
  MapScaleControl.svelte — Zero-DOM scale bar control.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';

  let {
    id = '',
    position = $bindable('bottomleft'),
    maxWidth = $bindable(100),
    metric = $bindable(true),
    imperial = $bindable(true),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    position?: string;
    maxWidth?: number;
    metric?: boolean;
    imperial?: boolean;
    layerIndex?: number;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let control: L.Control.Scale | undefined;

  $effect(() => {
    const target = mapCtx.target;
    if (!target || !('addControl' in target)) return;

    control = untrack(() => {
      return L.control.scale({
        position: position as L.ControlPosition,
        maxWidth,
        metric,
        imperial,
      }).addTo(target as L.Map);
    });

    return () => {
      control?.remove();
      control = undefined;
    };
  });
</script>
