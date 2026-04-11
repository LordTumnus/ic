<!--
  MapFeatureGroup.svelte — Container layer using L.FeatureGroup.

  Like MapLayerGroup but supports event bubbling (Click) and
  fitBounds() to zoom the map to the group's extent.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, setContext, untrack, onMount } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { ChildEntries, Resolution } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
    childEntries = [] as ChildEntries,
    // Events
    click,
    // Methods
    fitBounds = $bindable((): Resolution => ({ success: true, data: {} })),
  }: {
    id?: string;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
    childEntries?: ChildEntries;
    click?: (data: { latlng: [number, number] }) => void;
    fitBounds?: () => Resolution;
  } = $props();

  const parentCtx = getContext<MapContext>('ic-map');
  const mapUtils = getContext('ic-map-utils');

  // Override context: children add to this group
  const ctx: MapContext = $state({ target: undefined, loading: false });
  setContext('ic-map', ctx);
  setContext('ic-map-utils', mapUtils);

  let featureGroup: L.FeatureGroup | undefined;

  // --- Create feature group ---
  $effect(() => {
    const target = parentCtx.target;
    if (!target) return;

    featureGroup = untrack(() => {
      const fg = L.featureGroup();

      fg.on('click', (e: L.LeafletMouseEvent) => {
        click?.({ latlng: [e.latlng.lat, e.latlng.lng] });
      });

      if (visible) fg.addTo(target as L.Map);
      return fg;
    });
    ctx.target = featureGroup;

    return () => {
      ctx.target = undefined;
      featureGroup?.remove();
      featureGroup = undefined;
    };
  });

  // --- Sync visibility ---
  $effect(() => {
    const v = visible;
    const target = parentCtx.target;
    if (featureGroup && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(featureGroup)) featureGroup.addTo(map);
      else if (!v && map.hasLayer(featureGroup)) featureGroup.remove();
    }
  });

  // --- Methods ---
  onMount(() => {
    fitBounds = (): Resolution => {
      if (featureGroup && featureGroup.getLayers().length > 0) {
        // Walk up to find the root L.Map instance
        const target = parentCtx.target;
        if (target && 'fitBounds' in target) {
          (target as L.Map).fitBounds(featureGroup.getBounds());
        }
      }
      return { success: true, data: {} };
    };
  });
</script>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
