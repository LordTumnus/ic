<!--
  Map.svelte — Root Leaflet map container.

  Creates an L.map instance and sets Svelte context ('ic-map')
  so child layer/control components can find it. Children are
  rendered via DynamicChild; each layer adds itself imperatively.

  Context is a reactive $state object so children's $effects re-run
  when the map becomes available (parent effects run after children's).
-->
<script lang="ts">
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';
  import { setContext } from 'svelte';
  import type { ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  // Fix Leaflet default marker icon paths broken by Vite bundler
  import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
  import markerIcon from 'leaflet/dist/images/marker-icon.png';
  import markerShadow from 'leaflet/dist/images/marker-shadow.png';

  // @ts-ignore — override default icon prototype
  delete (L.Icon.Default.prototype as any)._getIconUrl;
  L.Icon.Default.mergeOptions({
    iconRetinaUrl: markerIcon2x,
    iconUrl: markerIcon,
    shadowUrl: markerShadow,
  });

  export interface MapContext {
    target: L.Map | L.LayerGroup | undefined;
  }

  let {
    id = '',
    center = $bindable<[number, number]>([51.505, -0.09]),
    zoom = $bindable(13),
    height = $bindable('400px'),
    childEntries = [] as ChildEntries,
    publish,
    subscribe,
    request,
  }: {
    id?: string;
    center?: [number, number];
    zoom?: number;
    height?: string;
    childEntries?: ChildEntries;
    publish?: (name: string, data?: unknown) => void;
    subscribe?: (name: string, callback: (...args: unknown[]) => void) => () => void;
    request?: (name: string, data?: unknown) => Promise<{ success: boolean; data: unknown }>;
  } = $props();

  let containerEl: HTMLDivElement;

  // Reactive context: children depend on ctx.target in their $effects
  const ctx: MapContext = $state({ target: undefined });
  setContext('ic-map', ctx);

  // Also expose request in context so child layers (e.g. TileLayer) can use it.
  // Use getters to avoid capturing stale references to $props.
  const mapUtils = {
    get request() { return request; },
    get publish() { return publish; },
    get subscribe() { return subscribe; },
  };
  setContext('ic-map-utils', mapUtils);

  $effect(() => {
    if (!containerEl) return;

    const map = L.map(containerEl, {
      center: [center[0], center[1]],
      zoom,
      zoomControl: true,
      attributionControl: false,
    });

    // Add attribution without clickable links (links break uihtml)
    L.control.attribution({ prefix: 'Leaflet' }).addTo(map);

    ctx.target = map;

    return () => {
      ctx.target = undefined;
      map.remove();
    };
  });
</script>

<div {id} bind:this={containerEl} class="ic-map" style:height></div>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}

<style>
  .ic-map {
    width: 100%;
    min-height: 100px;
  }
</style>
