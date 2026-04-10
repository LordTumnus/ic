<!--
  MapMarker.svelte — Zero-DOM marker component.
  Creates an L.marker on the parent map/group via context.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack, onMount } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { Resolution } from '$lib/types';
  import { resolveAssetAsDataUri } from '$lib/utils/asset-cache';
  import { getBuiltinIcon, getBuiltinAnchor } from '$lib/utils/marker-icons';

  let {
    id = '',
    position = $bindable<[number, number]>([0, 0]),
    draggable = $bindable(false),
    title = $bindable(''),
    popupContent = $bindable(''),
    tooltipContent = $bindable(''),
    icon = $bindable<string | { hash: string; mime?: string; data?: string } | null>(null),
    iconSize = $bindable<[number, number]>([25, 41]),
    iconAnchor = $bindable<[number, number]>([0, 0]),
    visible = $bindable(true),
    opacity = $bindable(1.0),
    layerIndex = $bindable(0),
    // Events
    click,
    dragStart,
    dragEnd,
    // Methods
    openPopup = $bindable((): Resolution => ({ success: true, data: null })),
    closePopup = $bindable((): Resolution => ({ success: true, data: null })),
    openTooltip = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    position?: [number, number];
    draggable?: boolean;
    title?: string;
    popupContent?: string;
    tooltipContent?: string;
    icon?: string | { hash: string; mime?: string; data?: string } | null;
    iconSize?: [number, number];
    iconAnchor?: [number, number];
    visible?: boolean;
    opacity?: number;
    layerIndex?: number;
    click?: (data: { latlng: [number, number] }) => void;
    dragStart?: (data: { latlng: [number, number] }) => void;
    dragEnd?: (data: { latlng: [number, number] }) => void;
    openPopup?: () => Resolution;
    closePopup?: () => Resolution;
    openTooltip?: () => Resolution;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let marker: L.Marker | undefined;

  /** Resolve the icon prop to a Leaflet L.Icon or undefined (use default) */
  function resolveIcon(): L.Icon | undefined {
    if (!icon) return undefined;

    // Built-in icon name (string like "pin", "dot", etc.)
    if (typeof icon === 'string') {
      const builtinUrl = getBuiltinIcon(icon);
      if (builtinUrl) {
        const anchorRatio = getBuiltinAnchor(icon);
        // Use iconAnchor if explicitly set (non-zero), otherwise use built-in default
        const isDefaultAnchor = iconAnchor[0] === 0 && iconAnchor[1] === 0;
        const anchor: [number, number] = isDefaultAnchor
          ? [Math.round(iconSize[0] * anchorRatio[0]), Math.round(iconSize[1] * anchorRatio[1])]
          : iconAnchor;
        return L.icon({
          iconUrl: builtinUrl,
          iconSize: iconSize,
          iconAnchor: anchor,
          popupAnchor: [0, -anchor[1]],
        });
      }
      // Unknown string, not a built-in: treat as empty (use default marker)
      return undefined;
    }

    // ic.Asset object {hash, mime?, data?}
    if (typeof icon === 'object' && icon.hash) {
      const dataUri = resolveAssetAsDataUri(icon);
      if (dataUri) {
        const isDefaultAnchor = iconAnchor[0] === 0 && iconAnchor[1] === 0;
        const anchor: [number, number] = isDefaultAnchor
          ? [Math.round(iconSize[0] * 0.5), iconSize[1]]
          : iconAnchor;
        return L.icon({
          iconUrl: dataUri,
          iconSize: iconSize,
          iconAnchor: anchor,
          popupAnchor: [0, -anchor[1]],
        });
      }
    }

    return undefined;
  }

  // --- Create marker ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    marker = untrack(() => {
      const leafletIcon = resolveIcon();
      const opts: L.MarkerOptions = {
        draggable,
        title: title || undefined,
        opacity,
      };
      if (leafletIcon) opts.icon = leafletIcon;

      const m = L.marker([position[0], position[1]], opts).addTo(target as L.Map);

      if (popupContent) m.bindPopup(popupContent);
      if (tooltipContent) m.bindTooltip(tooltipContent);

      m.on('click', () => {
        const ll = m.getLatLng();
        click?.({ latlng: [ll.lat, ll.lng] });
      });
      m.on('dragstart', () => {
        const ll = m.getLatLng();
        dragStart?.({ latlng: [ll.lat, ll.lng] });
      });
      m.on('dragend', () => {
        const ll = m.getLatLng();
        position = [ll.lat, ll.lng];
        dragEnd?.({ latlng: [ll.lat, ll.lng] });
      });

      return m;
    });

    return () => {
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
  $effect(() => {
    const t = title;
    if (marker) {
      const el = marker.getElement();
      if (el) el.title = t;
    }
  });
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
  $effect(() => {
    const v = visible;
    const target = mapCtx.target;
    if (marker && target && 'hasLayer' in target) {
      const map = target as L.Map;
      if (v && !map.hasLayer(marker)) marker.addTo(map);
      else if (!v && map.hasLayer(marker)) marker.remove();
    }
  });
  // Sync icon changes
  $effect(() => {
    // Read all icon-related props to track them
    const _i = icon;
    const _s = iconSize;
    const _a = iconAnchor;
    if (!marker) return;
    const leafletIcon = resolveIcon();
    if (leafletIcon) {
      marker.setIcon(leafletIcon);
    } else {
      marker.setIcon(new L.Icon.Default());
    }
  });

  // --- Methods ---
  onMount(() => {
    openPopup = (): Resolution => {
      marker?.openPopup();
      return { success: true, data: null };
    };
    closePopup = (): Resolution => {
      marker?.closePopup();
      return { success: true, data: null };
    };
    openTooltip = (): Resolution => {
      marker?.openTooltip();
      return { success: true, data: null };
    };
  });
</script>
