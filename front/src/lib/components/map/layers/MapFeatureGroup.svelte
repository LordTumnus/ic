<!--
  MapFeatureGroup.svelte — Container layer using L.FeatureGroup.

  Like MapLayerGroup but supports event bubbling (Click) and
  fitBounds() to zoom the map to the group's extent.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, setContext, untrack, onMount } from 'svelte';
  import type { MapContext, LayerRegistry } from '../Map.svelte';
  import type { ChildEntries, Resolution } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';
  import logger from '$lib/core/logger';

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
  const layerRegistry = getContext<LayerRegistry>('ic-map-layers');

  // Override context: children add to this group
  const ctx: MapContext = $state({ target: undefined, loading: false });
  setContext('ic-map', ctx);
  setContext('ic-map-utils', mapUtils);
  setContext('ic-map-layers', layerRegistry);

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

    // Register with layer registry (untracked to avoid re-triggering this effect)
    const entryId = untrack(() => id || crypto.randomUUID());
    const displayName = untrack(() => name || 'Feature Group');
    untrack(() => {
      if (layerRegistry) {
        layerRegistry.register({
          id: entryId,
          name: displayName,
          type: 'featuregroup',
          getVisible: () => visible,
          setVisible: (v: boolean) => { visible = v; },
        });
        logger.info('MapFeatureGroup', `Registered in layer control: "${displayName}"`);
      }
    });

    return () => {
      ctx.target = undefined;
      featureGroup?.remove();
      featureGroup = undefined;
      if (layerRegistry) {
        layerRegistry.deregister(entryId);
        logger.info('MapFeatureGroup', `Deregistered from layer control: "${displayName}"`);
      }
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
