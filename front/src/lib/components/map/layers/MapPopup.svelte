<!--
  MapPopup.svelte — Standalone popup at a fixed geographic position.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack, onMount } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { Resolution } from '$lib/types';

  let {
    id = '',
    position = $bindable<[number, number]>([0, 0]),
    content = $bindable(''),
    isOpen = $bindable(true),
    maxWidth = $bindable(300),
    minWidth = $bindable(50),
    autoClose = $bindable(true),
    visible = $bindable(true),
    name = $bindable(''),
    layerIndex = $bindable(0),
    // Events
    closed,
    // Methods
    open = $bindable((): Resolution => ({ success: true, data: null })),
    close = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    position?: [number, number];
    content?: string;
    isOpen?: boolean;
    maxWidth?: number;
    minWidth?: number;
    autoClose?: boolean;
    visible?: boolean;
    name?: string;
    layerIndex?: number;
    closed?: (data: Record<string, never>) => void;
    open?: () => Resolution;
    close?: () => Resolution;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let popup: L.Popup | undefined;
  // Guard against echoing Leaflet close events back
  let suppressCloseEvent = false;

  // --- Create popup ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target) return;

    popup = untrack(() => {
      const p = L.popup({
        maxWidth,
        minWidth,
        autoClose,
        closeOnClick: autoClose,
      })
        .setLatLng([position[0], position[1]])
        .setContent(content);

      p.on('remove', () => {
        if (!suppressCloseEvent && isOpen) {
          isOpen = false;
          closed?.({});
        }
      });

      if (isOpen && visible) {
        p.openOn(target as L.Map);
      }

      return p;
    });

    return () => {
      suppressCloseEvent = true;
      popup?.remove();
      popup = undefined;
      suppressCloseEvent = false;
    };
  });

  // --- Sync props ---
  $effect(() => {
    const p = position;
    if (popup) popup.setLatLng([p[0], p[1]]);
  });
  $effect(() => {
    const c = content;
    if (popup) popup.setContent(c);
  });
  $effect(() => {
    const o = isOpen;
    const v = visible;
    const target = mapCtx.target;
    if (!popup || !target) return;
    suppressCloseEvent = true;
    if (o && v) {
      popup.openOn(target as L.Map);
    } else {
      popup.remove();
    }
    suppressCloseEvent = false;
  });

  // --- Methods ---
  onMount(() => {
    open = (): Resolution => {
      const target = mapCtx.target;
      if (popup && target) {
        isOpen = true;
        popup.openOn(target as L.Map);
      }
      return { success: true, data: {} };
    };
    close = (): Resolution => {
      if (popup) {
        suppressCloseEvent = true;
        isOpen = false;
        popup.remove();
        suppressCloseEvent = false;
      }
      return { success: true, data: {} };
    };
  });
</script>
