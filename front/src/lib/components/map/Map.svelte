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
  import { setContext, onMount, untrack } from 'svelte';
  import type { ChildEntries, Resolution } from '$lib/types';
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
    loading: boolean;
  }

  let {
    id = '',
    center = $bindable<[number, number]>([51.505, -0.09]),
    zoom = $bindable(13),
    minZoom = $bindable(0),
    maxZoom = $bindable(19),
    maxBounds = $bindable<number[][] | null>(null),
    zoomControl = $bindable(true),
    allowDragging = $bindable(true),
    scrollWheelZoom = $bindable(true),
    doubleClickZoom = $bindable(true),
    keyboard = $bindable(true),
    height = $bindable('400px'),
    childEntries = [] as ChildEntries,
    // Events
    click,
    doubleClick,
    moveEnd,
    zoomEnd,
    // Methods
    setView = $bindable((_data: { center: number[]; zoom: number }): Resolution => ({ success: true, data: null })),
    panTo = $bindable((_data: { latlng: number[] }): Resolution => ({ success: true, data: null })),
    fitBounds = $bindable((_data: { bounds: number[][] }): Resolution => ({ success: true, data: null })),
    zoomIn = $bindable((): Resolution => ({ success: true, data: null })),
    zoomOut = $bindable((): Resolution => ({ success: true, data: null })),
    invalidateSize = $bindable((): Resolution => ({ success: true, data: null })),
    // Framework
    publish,
    subscribe,
    request,
  }: {
    id?: string;
    center?: [number, number];
    zoom?: number;
    minZoom?: number;
    maxZoom?: number;
    maxBounds?: number[][] | null;
    zoomControl?: boolean;
    allowDragging?: boolean;
    scrollWheelZoom?: boolean;
    doubleClickZoom?: boolean;
    keyboard?: boolean;
    height?: string;
    childEntries?: ChildEntries;
    click?: (data: { latlng: [number, number] }) => void;
    doubleClick?: (data: { latlng: [number, number] }) => void;
    moveEnd?: (data: { center: [number, number]; zoom: number; bounds: number[][] }) => void;
    zoomEnd?: (data: { zoom: number }) => void;
    setView?: (data: { center: number[]; zoom: number }) => Resolution;
    panTo?: (data: { latlng: number[] }) => Resolution;
    fitBounds?: (data: { bounds: number[][] }) => Resolution;
    zoomIn?: () => Resolution;
    zoomOut?: () => Resolution;
    invalidateSize?: () => Resolution;
    publish?: (name: string, data?: unknown) => void;
    subscribe?: (name: string, callback: (...args: unknown[]) => void) => () => void;
    request?: (name: string, data?: unknown) => Promise<{ success: boolean; data: unknown }>;
  } = $props();

  let containerEl: HTMLDivElement;
  let mapInstance: L.Map | undefined;

  // Track the last values synced FROM Leaflet, so the prop→Leaflet $effect
  // can distinguish MATLAB-driven changes from user-interaction echoes.
  let leafletCenter: [number, number] = [center[0], center[1]];
  let leafletZoom: number = zoom;

  // Reactive context: children depend on ctx.target in their $effects
  const ctx: MapContext = $state({ target: undefined, loading: false });
  setContext('ic-map', ctx);

  // Also expose request in context so child layers (e.g. TileLayer) can use it.
  // Use getters to avoid capturing stale references to $props.
  const mapUtils = {
    get request() { return request; },
    get publish() { return publish; },
    get subscribe() { return subscribe; },
  };
  setContext('ic-map-utils', mapUtils);

  // Debounced spinner visibility
  let showSpinner = $state(false);
  let showTimer: ReturnType<typeof setTimeout> | undefined;
  let hideTimer: ReturnType<typeof setTimeout> | undefined;

  $effect(() => {
    const loading = ctx.loading;
    if (loading) {
      clearTimeout(hideTimer);
      showTimer = setTimeout(() => {
        showSpinner = true;
      }, 300);
    } else {
      clearTimeout(showTimer);
      hideTimer = setTimeout(() => {
        showSpinner = false;
      }, 500);
    }
    return () => {
      clearTimeout(showTimer);
      clearTimeout(hideTimer);
    };
  });

  // --- Map initialization ---
  // This $effect must only depend on containerEl. Everything else is
  // untracked so prop changes don't destroy and recreate the map.
  $effect(() => {
    if (!containerEl) return;

    const map = untrack(() => {
      const m = L.map(containerEl, {
        center: [center[0], center[1]],
        zoom,
        minZoom,
        maxZoom,
        zoomControl,
        attributionControl: false,
        dragging: allowDragging,
        scrollWheelZoom,
        doubleClickZoom,
        keyboard,
      });

      if (maxBounds && Array.isArray(maxBounds) && maxBounds.length === 2) {
        m.setMaxBounds(L.latLngBounds(
          [maxBounds[0][0], maxBounds[0][1]],
          [maxBounds[1][0], maxBounds[1][1]],
        ));
      }

      L.control.attribution({ prefix: 'Leaflet' }).addTo(m);

      // --- Map events → MATLAB ---
      m.on('click', (e: L.LeafletMouseEvent) => {
        click?.({ latlng: [e.latlng.lat, e.latlng.lng] });
      });
      m.on('dblclick', (e: L.LeafletMouseEvent) => {
        doubleClick?.({ latlng: [e.latlng.lat, e.latlng.lng] });
      });
      m.on('moveend', () => {
        const c = m.getCenter();
        const z = m.getZoom();
        const b = m.getBounds();
        const prevCenter = leafletCenter;
        leafletCenter = [c.lat, c.lng];
        leafletZoom = z;
        center = leafletCenter;
        zoom = leafletZoom;
        // Only fire MoveEnd when the center actually changed (not on pure zoom)
        const centerMoved =
          Math.abs(prevCenter[0] - c.lat) > 1e-6 ||
          Math.abs(prevCenter[1] - c.lng) > 1e-6;
        if (centerMoved) {
          moveEnd?.({
            center: [c.lat, c.lng],
            zoom: z,
            bounds: [[b.getSouth(), b.getWest()], [b.getNorth(), b.getEast()]],
          });
        }
      });
      m.on('zoomend', () => {
        zoomEnd?.({ zoom: m.getZoom() });
      });

      return m;
    });

    mapInstance = map;
    ctx.target = map;

    return () => {
      ctx.target = undefined;
      mapInstance = undefined;
      map.remove();
    };
  });

  // --- Sync props → Leaflet ---
  // Only call setView when the prop values differ from what Leaflet last
  // reported (i.e. the change came from MATLAB, not from user interaction).
  $effect(() => {
    const c = center;
    const z = zoom;
    if (!mapInstance) return;
    const fromLeaflet =
      Math.abs(c[0] - leafletCenter[0]) < 1e-6 &&
      Math.abs(c[1] - leafletCenter[1]) < 1e-6 &&
      z === leafletZoom;
    if (!fromLeaflet) {
      mapInstance.setView([c[0], c[1]], z);
    }
  });

  // Sync interaction toggles
  $effect(() => {
    if (!mapInstance) return;
    const d = allowDragging;
    if (d) mapInstance.dragging.enable(); else mapInstance.dragging.disable();
  });
  $effect(() => {
    if (!mapInstance) return;
    const s = scrollWheelZoom;
    if (s) mapInstance.scrollWheelZoom.enable(); else mapInstance.scrollWheelZoom.disable();
  });
  $effect(() => {
    if (!mapInstance) return;
    const d = doubleClickZoom;
    if (d) mapInstance.doubleClickZoom.enable(); else mapInstance.doubleClickZoom.disable();
  });
  $effect(() => {
    if (!mapInstance) return;
    const k = keyboard;
    if (k) mapInstance.keyboard.enable(); else mapInstance.keyboard.disable();
  });
  $effect(() => {
    if (!mapInstance) return;
    const mn = minZoom;
    const mx = maxZoom;
    mapInstance.setMinZoom(mn);
    mapInstance.setMaxZoom(mx);
  });

  // --- Methods ---
  onMount(() => {
    setView = (data): Resolution => {
      mapInstance?.setView([data.center[0], data.center[1]], data.zoom);
      return { success: true, data: null };
    };
    panTo = (data): Resolution => {
      mapInstance?.panTo([data.latlng[0], data.latlng[1]]);
      return { success: true, data: null };
    };
    fitBounds = (data): Resolution => {
      mapInstance?.fitBounds([
        [data.bounds[0][0], data.bounds[0][1]],
        [data.bounds[1][0], data.bounds[1][1]],
      ]);
      return { success: true, data: null };
    };
    zoomIn = (): Resolution => {
      mapInstance?.zoomIn();
      return { success: true, data: null };
    };
    zoomOut = (): Resolution => {
      mapInstance?.zoomOut();
      return { success: true, data: null };
    };
    invalidateSize = (): Resolution => {
      mapInstance?.invalidateSize();
      return { success: true, data: null };
    };
  });
</script>

<div class="ic-map-wrapper" style:height>
  <div {id} bind:this={containerEl} class="ic-map"></div>
  {#if showSpinner}
    <div class="ic-map-spinner"></div>
  {/if}
</div>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}

<style>
  .ic-map-wrapper {
    position: relative;
    width: 100%;
  }
  .ic-map {
    width: 100%;
    height: 100%;
    min-height: 100px;
  }
  .ic-map-spinner {
    position: absolute;
    bottom: 8px;
    left: 8px;
    z-index: 1000;
    width: 16px;
    height: 16px;
    border: 2px solid rgba(0, 0, 0, 0.15);
    border-top-color: rgba(0, 0, 0, 0.4);
    border-radius: 50%;
    animation: ic-spin 0.8s linear infinite;
    pointer-events: none;
  }
  @keyframes ic-spin {
    to { transform: rotate(360deg); }
  }
</style>
