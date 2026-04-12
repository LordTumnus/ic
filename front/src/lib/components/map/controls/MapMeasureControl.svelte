<!--
  MapMeasureControl.svelte — Distance and area measurement control.
  Custom-built (no plugin) with Industrial Flat styling.
  Supports distance (polyline) and area (polygon) measurement modes.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack, onMount } from 'svelte';
  import type { MapContext } from '../Map.svelte';
  import type { Resolution } from '$lib/types';

  let {
    id = '',
    position = $bindable('topright'),
    units = $bindable('metric'),
    color = $bindable(''),
    weight = $bindable(2),
    activeMeasurement = $bindable<Record<string, unknown>>({}),
    layerIndex = $bindable(0),
    // Events
    measureStart,
    measureEnd,
    // Methods
    clear: clearMethod = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    position?: string;
    units?: string;
    color?: string;
    weight?: number;
    activeMeasurement?: Record<string, unknown>;
    layerIndex?: number;
    measureStart?: (data: Record<string, never>) => void;
    measureEnd?: (data: Record<string, unknown>) => void;
    clear?: () => Resolution;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  let control: L.Control | undefined;

  // Drawing state
  type MeasureMode = 'idle' | 'distance' | 'area';
  let mode: MeasureMode = 'idle';
  let points: L.LatLng[] = [];
  let drawingLine: L.Polyline | undefined;
  let drawingPolygon: L.Polygon | undefined;
  let vertexMarkers: L.CircleMarker[] = [];
  let tooltipMarker: L.Marker | undefined;
  let resultMarker: L.Marker | undefined;
  let hadDoubleClickZoom = false;

  // Button elements for active state styling
  let distBtn: HTMLButtonElement | undefined;
  let areaBtn: HTMLButtonElement | undefined;

  /** Resolve the measurement color (falls back to CSS variable extraction) */
  function getMeasureColor(): string {
    if (color) return color;
    return '#3b82f6'; // fallback blue matching typical --ic-primary
  }

  // ── Distance & area calculations ──────────────────────────────────────

  function formatDistance(meters: number): { value: number; unit: string; display: string } {
    if (units === 'imperial') {
      const feet = meters * 3.28084;
      if (feet < 5280) return { value: feet, unit: 'ft', display: `${feet.toFixed(1)} ft` };
      const miles = feet / 5280;
      return { value: miles, unit: 'mi', display: `${miles.toFixed(2)} mi` };
    }
    if (meters < 1000) return { value: meters, unit: 'm', display: `${meters.toFixed(1)} m` };
    const km = meters / 1000;
    return { value: km, unit: 'km', display: `${km.toFixed(2)} km` };
  }

  function formatArea(sqMeters: number): { value: number; unit: string; display: string } {
    if (units === 'imperial') {
      const sqFeet = sqMeters * 10.7639;
      if (sqFeet < 27878400) return { value: sqFeet, unit: 'sq ft', display: `${sqFeet.toFixed(0)} sq ft` };
      const sqMiles = sqFeet / 27878400;
      return { value: sqMiles, unit: 'sq mi', display: `${sqMiles.toFixed(3)} sq mi` };
    }
    if (sqMeters < 1e6) return { value: sqMeters, unit: 'sq m', display: `${sqMeters.toFixed(0)} sq m` };
    const sqKm = sqMeters / 1e6;
    return { value: sqKm, unit: 'sq km', display: `${sqKm.toFixed(3)} sq km` };
  }

  function totalDistance(pts: L.LatLng[]): number {
    let sum = 0;
    const map = mapCtx.target as L.Map;
    for (let i = 1; i < pts.length; i++) {
      sum += map.distance(pts[i - 1], pts[i]);
    }
    return sum;
  }

  /** Geodesic area using the spherical excess formula */
  function geodesicArea(pts: L.LatLng[]): number {
    const R = 6371000;
    const rad = Math.PI / 180;
    let area = 0;
    const n = pts.length;
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      area += (pts[j].lng - pts[i].lng) * rad *
              (2 + Math.sin(pts[i].lat * rad) + Math.sin(pts[j].lat * rad));
    }
    return Math.abs(area * R * R / 2);
  }

  // ── Drawing helpers ───────────────────────────────────────────────────

  function addVertex(latlng: L.LatLng): void {
    const map = mapCtx.target as L.Map;
    const c = getMeasureColor();

    points.push(latlng);

    // Vertex dot
    const vertex = L.circleMarker(latlng, {
      radius: 4,
      color: c,
      fillColor: '#fff',
      fillOpacity: 1,
      weight: 2,
    }).addTo(map);
    vertexMarkers.push(vertex);

    // Update drawing shape
    if (mode === 'distance') {
      if (!drawingLine) {
        drawingLine = L.polyline([latlng], {
          color: c,
          weight: weight,
          dashArray: '6 6',
        }).addTo(map);
      } else {
        drawingLine.addLatLng(latlng);
      }
    } else if (mode === 'area') {
      if (!drawingPolygon) {
        drawingPolygon = L.polygon([latlng], {
          color: c,
          weight: weight,
          dashArray: '6 6',
          fillOpacity: 0.1,
        }).addTo(map);
      } else {
        drawingPolygon.addLatLng(latlng);
      }
    }
  }

  function updateTooltip(latlng: L.LatLng): void {
    const map = mapCtx.target as L.Map;
    if (!points.length) return;

    let text = '';
    if (mode === 'distance') {
      const running = totalDistance([...points, latlng]);
      text = formatDistance(running).display;
    } else if (mode === 'area' && points.length >= 2) {
      const area = geodesicArea([...points, latlng]);
      text = formatArea(area).display;
    }

    if (!text) return;

    if (!tooltipMarker) {
      tooltipMarker = L.marker(latlng, {
        icon: L.divIcon({
          className: 'ic-measure__tooltip',
          html: text,
          iconAnchor: [-12, 12],
        }),
        interactive: false,
      }).addTo(map);
    } else {
      tooltipMarker.setLatLng(latlng);
      const icon = tooltipMarker.getIcon() as L.DivIcon;
      icon.options.html = text;
      tooltipMarker.setIcon(icon);
    }
  }

  function removeTooltip(): void {
    tooltipMarker?.remove();
    tooltipMarker = undefined;
  }

  // ── Measurement lifecycle ─────────────────────────────────────────────

  function activateMode(newMode: MeasureMode): void {
    const map = mapCtx.target as L.Map;
    if (!map) return;

    // If same mode clicked again, deactivate
    if (mode === newMode) {
      deactivate();
      return;
    }

    // Clean previous measurement
    clearDrawing();

    mode = newMode;
    points = [];

    // Disable double-click zoom
    hadDoubleClickZoom = map.doubleClickZoom.enabled();
    map.doubleClickZoom.disable();

    // Crosshair cursor
    L.DomUtil.addClass(map.getContainer(), 'ic-measure-active');

    // Update button active states
    updateButtons();

    // Register map handlers
    map.on('click', onMapClick);
    map.on('mousemove', onMapMouseMove);
    map.on('dblclick', onMapDblClick);

    measureStart?.({});
  }

  function deactivate(): void {
    const map = mapCtx.target as L.Map;
    if (!map) return;

    mode = 'idle';
    removeTooltip();

    // Restore double-click zoom
    if (hadDoubleClickZoom) map.doubleClickZoom.enable();

    // Restore cursor
    L.DomUtil.removeClass(map.getContainer(), 'ic-measure-active');

    // Remove map handlers
    map.off('click', onMapClick);
    map.off('mousemove', onMapMouseMove);
    map.off('dblclick', onMapDblClick);

    updateButtons();
  }

  function finishMeasurement(): void {
    if (points.length < 2) {
      deactivate();
      return;
    }

    const map = mapCtx.target as L.Map;
    removeTooltip();

    let resultText = '';
    let payload: Record<string, unknown> = {};

    if (mode === 'distance') {
      const dist = totalDistance(points);
      const fmt = formatDistance(dist);
      resultText = fmt.display;
      payload = {
        type: 'distance',
        value: fmt.value,
        unit: fmt.unit,
        points: points.map((p) => [p.lat, p.lng]),
      };
    } else if (mode === 'area') {
      if (points.length < 3) {
        deactivate();
        return;
      }
      const area = geodesicArea(points);
      const fmt = formatArea(area);
      resultText = fmt.display;
      payload = {
        type: 'area',
        value: fmt.value,
        unit: fmt.unit,
        points: points.map((p) => [p.lat, p.lng]),
      };
    }

    // Place result label at midpoint (distance) or centroid (area)
    const labelPos = mode === 'distance'
      ? points[Math.floor(points.length / 2)]
      : L.latLng(
          points.reduce((s, p) => s + p.lat, 0) / points.length,
          points.reduce((s, p) => s + p.lng, 0) / points.length,
        );

    resultMarker = L.marker(labelPos, {
      icon: L.divIcon({
        className: 'ic-measure__label',
        html: resultText,
        iconAnchor: [0, 12],
      }),
      interactive: false,
    }).addTo(map);

    activeMeasurement = payload;
    measureEnd?.(payload);
    deactivate();
  }

  function clearDrawing(): void {
    const map = mapCtx.target as L.Map;
    if (!map) return;

    drawingLine?.remove();
    drawingLine = undefined;
    drawingPolygon?.remove();
    drawingPolygon = undefined;
    for (const m of vertexMarkers) m.remove();
    vertexMarkers = [];
    resultMarker?.remove();
    resultMarker = undefined;
    removeTooltip();
    points = [];
    activeMeasurement = {};
  }

  function updateButtons(): void {
    distBtn?.classList.toggle('ic-measure__btn--active', mode === 'distance');
    areaBtn?.classList.toggle('ic-measure__btn--active', mode === 'area');
  }

  // ── Map event handlers ────────────────────────────────────────────────

  function onMapClick(e: L.LeafletMouseEvent): void {
    addVertex(e.latlng);
  }

  function onMapMouseMove(e: L.LeafletMouseEvent): void {
    updateTooltip(e.latlng);
  }

  function onMapDblClick(e: L.LeafletMouseEvent): void {
    L.DomEvent.stop(e);
    finishMeasurement();
  }

  // ── SVG icons ─────────────────────────────────────────────────────────

  const rulerSvg = `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round">
    <line x1="2" y1="14" x2="14" y2="2"/>
    <line x1="2" y1="14" x2="4" y2="12"/>
    <line x1="5" y1="11" x2="6.5" y2="9.5"/>
    <line x1="8" y1="8" x2="9.5" y2="6.5"/>
    <line x1="11" y1="5" x2="12" y2="4"/>
  </svg>`;

  const areaSvg = `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <polygon points="3,12 8,3 13,12"/>
  </svg>`;

  // ── Leaflet control ───────────────────────────────────────────────────

  const MeasureCtrl = L.Control.extend({
    onAdd() {
      const container = L.DomUtil.create('div', 'ic-measure');
      if (id) container.id = id;
      L.DomEvent.disableClickPropagation(container);
      L.DomEvent.disableScrollPropagation(container);

      // Distance button
      const dBtn = L.DomUtil.create('button', 'ic-measure__btn', container);
      dBtn.innerHTML = rulerSvg;
      dBtn.title = 'Measure distance';
      dBtn.addEventListener('click', () => activateMode('distance'));
      distBtn = dBtn;

      // Area button
      const aBtn = L.DomUtil.create('button', 'ic-measure__btn', container);
      aBtn.innerHTML = areaSvg;
      aBtn.title = 'Measure area';
      aBtn.addEventListener('click', () => activateMode('area'));
      areaBtn = aBtn;

      return container;
    },
    onRemove() {
      distBtn = undefined;
      areaBtn = undefined;
    },
  });

  // Create control when map is ready
  $effect(() => {
    const target = mapCtx.target;
    if (!target || !('addControl' in target)) return;

    control = untrack(() => {
      return new MeasureCtrl({
        position: position as L.ControlPosition,
      }).addTo(target as L.Map);
    });

    return () => {
      deactivate();
      clearDrawing();
      control?.remove();
      control = undefined;
    };
  });

  // Bind clear method
  onMount(() => {
    clearMethod = (): Resolution => {
      clearDrawing();
      deactivate();
      return { success: true, data: null };
    };
  });
</script>

<style>
  :global(.ic-measure) {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  :global(.ic-measure__btn) {
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    color: var(--ic-foreground);
    padding: 0;
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
    transition: box-shadow 0.15s ease;
  }

  :global(.ic-measure__btn:hover) {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  :global(.ic-measure__btn--active) {
    border-color: var(--ic-primary);
    color: var(--ic-primary);
  }

  :global(.ic-measure__tooltip) {
    background: var(--ic-secondary, #1e1e2e);
    color: var(--ic-foreground, #e0e0e0);
    font-family: 'Roboto Mono', 'Consolas', monospace;
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    padding: 2px 6px;
    border-radius: 2px;
    border: 1px solid var(--ic-border, #333);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
    white-space: nowrap;
    pointer-events: none;
  }

  :global(.ic-measure__label) {
    background: var(--ic-secondary, #1e1e2e);
    color: var(--ic-foreground, #e0e0e0);
    font-family: 'Roboto Mono', 'Consolas', monospace;
    font-size: 12px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    padding: 3px 8px;
    border-radius: 2px;
    border: 1px solid var(--ic-border, #333);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.12);
    white-space: nowrap;
    pointer-events: none;
  }

  :global(.ic-measure-active) {
    cursor: crosshair !important;
  }
</style>
