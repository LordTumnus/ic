<!--
  MapLayerGroup.svelte — Container layer that groups children into an L.LayerGroup.

  Overrides the 'ic-map' context so child layers add to the group
  instead of the root map. Toggling Visible adds/removes the entire
  group from the parent target.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, setContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
    childEntries?: ChildEntries;
  } = $props();

  const parentCtx = getContext<MapContext>('ic-map');
  const mapUtils = getContext('ic-map-utils');

  // Override context: children add to this group, not the parent target
  const ctx: MapContext = $state({ target: undefined, loading: false });
  setContext('ic-map', ctx);
  setContext('ic-map-utils', mapUtils);

  let group: L.LayerGroup | undefined;

  // --- Create layer group ---
  $effect(() => {
    const target = parentCtx.target;
    if (!target) return;

    group = untrack(() => {
      const g = L.layerGroup();
      if (visible) g.addTo(target as L.Map);
      return g;
    });
    ctx.target = group;

    return () => {
      ctx.target = undefined;
      group?.remove();
      group = undefined;
    };
  });

  // --- Sync visibility ---
  $effect(() => {
    const v = visible;
    const target = parentCtx.target;
    if (group && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(group)) group.addTo(map);
      else if (!v && map.hasLayer(group)) group.remove();
    }
  });
</script>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
