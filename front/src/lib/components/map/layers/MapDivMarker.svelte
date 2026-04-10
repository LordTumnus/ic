<!--
  MapDivMarker.svelte — Custom HTML marker via L.DivIcon.

  Can render raw HTML (via content prop) or IC child components
  (via childEntries). When children exist, they are portalled into
  the DivIcon's container element after Leaflet creates it.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    position = $bindable<[number, number]>([0, 0]),
    content = $bindable(''),
    className = $bindable(''),
    iconSize = $bindable<[number, number]>([0, 0]),
    iconAnchor = $bindable<[number, number]>([0, 0]),
    opacity = $bindable(1.0),
    popupContent = $bindable(''),
    tooltipContent = $bindable(''),
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
    childEntries = [] as ChildEntries,
    // Events
    click,
  }: {
    id?: string;
    position?: [number, number];
    content?: string;
    className?: string;
    iconSize?: [number, number];
    iconAnchor?: [number, number];
    opacity?: number;
    popupContent?: string;
    tooltipContent?: string;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
    childEntries?: ChildEntries;
    click?: (data: { latlng: [number, number] }) => void;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let marker: L.Marker | undefined;
  let portalEl: HTMLDivElement;

  const hasChildren = $derived(childEntries.length > 0);

  function buildIcon(): L.DivIcon {
    const autoSize = iconSize[0] === 0 && iconSize[1] === 0;
    const autoAnchor = iconAnchor[0] === 0 && iconAnchor[1] === 0;
    return L.divIcon({
      html: hasChildren ? '' : content,
      className: className || 'ic-div-marker',
      iconSize: autoSize ? undefined : iconSize as [number, number],
      iconAnchor: autoAnchor ? undefined : iconAnchor as [number, number],
    });
  }

  /** Move the portal container into the DivIcon's DOM element */
  function portalChildren() {
    if (!marker || !portalEl || !hasChildren) return;
    const el = marker.getElement();
    if (!el) return;
    // Find the icon container div (Leaflet wraps DivIcon html in a child div)
    const iconDiv = el.querySelector('.ic-div-marker') || el.querySelector('[class*="leaflet-div-icon"]') || el;
    // Clear any placeholder html and append the portal
    if (iconDiv !== portalEl.parentElement) {
      iconDiv.textContent = '';
      iconDiv.appendChild(portalEl);
    }
  }

  // --- Create marker ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    marker = untrack(() => {
      const m = L.marker([position[0], position[1]], {
        icon: buildIcon(),
        opacity,
      }).addTo(target as L.Map);

      if (popupContent) m.bindPopup(popupContent);
      if (tooltipContent) m.bindTooltip(tooltipContent);

      m.on('click', () => {
        const ll = m.getLatLng();
        click?.({ latlng: [ll.lat, ll.lng] });
      });

      return m;
    });

    // Portal children into the icon after a tick (Leaflet needs to render first)
    requestAnimationFrame(() => portalChildren());

    return () => {
      // Move portal back before Leaflet removes the marker element
      if (portalEl && portalEl.parentElement && portalEl.parentElement !== document.body) {
        // Reparent to a safe place so Svelte children aren't destroyed
      }
      marker?.remove();
      marker = undefined;
    };
  });

  // --- Sync props ---
  $effect(() => {
    const p = position;
    if (marker) marker.setLatLng([p[0], p[1]]);
  });
  $effect(() => {
    const o = opacity;
    if (marker) marker.setOpacity(o);
  });
  // Rebuild icon when content, className, iconSize, or iconAnchor change
  $effect(() => {
    void content, className, iconSize, iconAnchor, hasChildren;
    if (!marker) return;
    marker.setIcon(buildIcon());
    // Re-portal children after icon rebuild
    requestAnimationFrame(() => portalChildren());
  });
  // Sync popup
  $effect(() => {
    const pc = popupContent;
    if (!marker) return;
    if (pc) {
      if (marker.getPopup()) {
        marker.getPopup()!.setContent(pc);
      } else {
        marker.bindPopup(pc);
      }
    } else {
      marker.unbindPopup();
    }
  });
  // Sync tooltip
  $effect(() => {
    const tc = tooltipContent;
    if (!marker) return;
    if (tc) {
      if (marker.getTooltip()) {
        marker.getTooltip()!.setContent(tc);
      } else {
        marker.bindTooltip(tc);
      }
    } else {
      marker.unbindTooltip();
    }
  });
  // Sync visibility
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (marker && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(marker)) {
        marker.addTo(map);
        requestAnimationFrame(() => portalChildren());
      } else if (!v && map.hasLayer(marker)) {
        marker.remove();
      }
    }
  });
</script>

<!-- Portal container: children render here, then get moved into the DivIcon's DOM -->
<div {id} bind:this={portalEl}>
  {#each childEntries as child (child.id)}
    <DynamicChild entry={child} />
  {/each}
</div>

<style>
  :global(.ic-div-marker) {
    background: none;
    border: none;
  }
</style>
