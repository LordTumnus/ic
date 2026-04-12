<!--
  MapCoordinateDisplay.svelte — Cursor coordinate readout control.

  Displays lat/lng as the mouse moves over the map.
  Industrial Flat styling: dark bg, monospace font, inset shadow.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext } from '../Map.svelte';

  let {
    id = '',
    position = $bindable('bottomleft'),
    precision = $bindable(5),
    prefix = $bindable(''),
    separator = $bindable(' | '),
    emptyText = $bindable('---'),
    layerIndex = $bindable(0),
  }: {
    id?: string;
    position?: string;
    precision?: number;
    prefix?: string;
    separator?: string;
    emptyText?: string;
    layerIndex?: number;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let control: L.Control | undefined;
  let displayEl: HTMLDivElement | undefined;

  // Custom L.Control subclass
  const CoordControl = L.Control.extend({
    onAdd() {
      const div = L.DomUtil.create('div', 'ic-coord-display');
      if (id) div.id = id;
      div.innerHTML = emptyText;
      displayEl = div;
      return div;
    },
    onRemove() {
      displayEl = undefined;
    },
  });

  $effect(() => {
    const target = mapCtx.target;
    if (!target || !('addControl' in target)) return;

    control = untrack(() => {
      const ctrl = new CoordControl({
        position: position as L.ControlPosition,
      }).addTo(target as L.Map);

      const map = target as L.Map;

      map.on('mousemove', (e: L.LeafletMouseEvent) => {
        if (displayEl) {
          const lat = e.latlng.lat.toFixed(precision);
          const lng = e.latlng.lng.toFixed(precision);
          displayEl.innerHTML = `${prefix}${lat}${separator}${lng}`;
        }
      });

      map.on('mouseout', () => {
        if (displayEl) {
          displayEl.innerHTML = emptyText;
        }
      });

      return ctrl;
    });

    return () => {
      const map = mapCtx.target as L.Map;
      if (map) {
        map.off('mousemove');
        map.off('mouseout');
      }
      control?.remove();
      control = undefined;
      displayEl = undefined;
    };
  });
</script>

<style>
  :global(.ic-coord-display) {
    background: var(--ic-secondary);
    color: var(--ic-foreground);
    font-family: 'Roboto Mono', 'Consolas', monospace;
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    padding: 4px 8px 4px 12px;
    border-radius: 2px;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
    border: 1px solid var(--ic-border);
    min-width: 140px;
    text-align: center;
    user-select: none;
    /* Grip dots on left edge */
    background-image: radial-gradient(circle, var(--ic-muted-foreground) 1px, transparent 1px);
    background-size: 4px 4px;
    background-position: 3px center;
    background-repeat: repeat-y;
  }
</style>
