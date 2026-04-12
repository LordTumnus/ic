<!--
  MapLayersControl.svelte — Layer visibility toggle control.

  Reads the layer registry (set by Map.svelte) and renders a toggle
  panel split into two sections:
    - Base layers (radio buttons, mutually exclusive — typically TileLayers)
    - Overlay layers (checkboxes, independent toggle — groups, etc.)

  Layers are matched by name against the baseLayers / overlayLayers
  string arrays. Layers not in either list do not appear.

  The control builds its DOM imperatively inside an L.Control subclass
  because it lives in Leaflet's container, outside Svelte's template.
-->
<script lang="ts">
  import L from 'leaflet';
  import { getContext, untrack } from 'svelte';
  import type { MapContext, LayerRegistry, LayerRegistryEntry } from '../Map.svelte';
  import logger from '$lib/core/logger';

  let {
    id = '',
    position = $bindable('topright'),
    collapsed = $bindable(true),
    baseLayers = $bindable<string[]>([]),
    overlayLayers = $bindable<string[]>([]),
    layerIndex = $bindable(0),
    // Events
    opened,
    closed,
    layerToggled,
  }: {
    id?: string;
    position?: string;
    collapsed?: boolean;
    baseLayers?: string[];
    overlayLayers?: string[];
    layerIndex?: number;
    opened?: () => void;
    closed?: () => void;
    layerToggled?: (data: { name: string; visible: boolean; group: string }) => void;
  } = $props();

  const mapCtx = getContext<MapContext>('ic-map');
  const layerRegistry = getContext<LayerRegistry>('ic-map-layers');

  let control: L.Control | undefined;
  let containerEl: HTMLDivElement | undefined;
  let listEl: HTMLDivElement | undefined;
  let panelVisible = false;

  // Layers button SVG icon
  const layersIconSvg = `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M8 1.5L14.5 5.5L8 9.5L1.5 5.5Z" fill="currentColor" opacity="0.7"/>
    <path d="M1.5 8L8 12L14.5 8" stroke="currentColor" stroke-width="1.3" fill="none"/>
    <path d="M1.5 10.5L8 14.5L14.5 10.5" stroke="currentColor" stroke-width="1.3" fill="none"/>
  </svg>`;

  /** Handle base layer radio click: show selected, hide all others */
  function selectBaseLayer(entries: LayerRegistryEntry[], selected: LayerRegistryEntry) {
    for (const entry of entries) {
      entry.setVisible(entry.id === selected.id);
    }
    selected.setVisible(true);
    logger.info('MapLayersControl', `Base layer selected: "${selected.name}"`);
    layerToggled?.({ name: selected.name, visible: true, group: 'base' });
  }

  /** Build (or rebuild) the panel DOM from registry entries */
  function rebuildList(entries: LayerRegistryEntry[]) {
    if (!listEl) return;
    listEl.innerHTML = '';

    // MATLAB may send a scalar string instead of an array for single-element lists
    const baseArr = Array.isArray(baseLayers) ? baseLayers : (baseLayers ? [baseLayers] : []);
    const overlayArr = Array.isArray(overlayLayers) ? overlayLayers : (overlayLayers ? [overlayLayers] : []);
    const baseNames = new Set(baseArr);
    const overlayNames = new Set(overlayArr);

    const baseEntries = entries.filter(e => baseNames.has(e.name));
    const overlayEntries = entries.filter(e => overlayNames.has(e.name));

    if (baseEntries.length === 0 && overlayEntries.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'ic-layers-empty';
      empty.textContent = 'No layers';
      listEl.appendChild(empty);
      return;
    }

    // --- Base layers section (radios) ---
    if (baseEntries.length > 0) {
      const heading = document.createElement('div');
      heading.className = 'ic-layers-heading';
      heading.textContent = 'Base';
      listEl.appendChild(heading);

      for (const entry of baseEntries) {
        const row = document.createElement('label');
        row.className = 'ic-layers-row';

        const radio = document.createElement('input');
        radio.type = 'radio';
        radio.name = 'ic-layers-base';
        radio.className = 'ic-layers-radio';
        radio.checked = entry.getVisible();
        radio.addEventListener('change', () => {
          if (radio.checked) selectBaseLayer(baseEntries, entry);
        });

        const label = document.createElement('span');
        label.className = 'ic-layers-name';
        label.textContent = entry.name;

        row.appendChild(radio);
        row.appendChild(label);
        listEl.appendChild(row);
      }
    }

    // --- Separator ---
    if (baseEntries.length > 0 && overlayEntries.length > 0) {
      const sep = document.createElement('div');
      sep.className = 'ic-layers-separator';
      listEl.appendChild(sep);
    }

    // --- Overlay layers section (checkboxes) ---
    if (overlayEntries.length > 0) {
      const heading = document.createElement('div');
      heading.className = 'ic-layers-heading';
      heading.textContent = 'Overlays';
      listEl.appendChild(heading);

      for (const entry of overlayEntries) {
        const row = document.createElement('label');
        row.className = 'ic-layers-row';

        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.className = 'ic-layers-checkbox';
        checkbox.checked = entry.getVisible();
        checkbox.addEventListener('change', () => {
          entry.setVisible(checkbox.checked);
          logger.info('MapLayersControl', `Overlay "${entry.name}" toggled to ${checkbox.checked}`);
          layerToggled?.({ name: entry.name, visible: checkbox.checked, group: 'overlay' });
        });

        const label = document.createElement('span');
        label.className = 'ic-layers-name';
        label.textContent = entry.name;

        row.appendChild(checkbox);
        row.appendChild(label);
        listEl.appendChild(row);
      }
    }
  }

  function isTopPosition(pos: string): boolean {
    return pos.startsWith('top');
  }

  // Custom L.Control subclass
  const LayersCtrl = L.Control.extend({
    onAdd() {
      const container = L.DomUtil.create('div', 'ic-layers-control');
      if (id) container.id = id;

      L.DomEvent.disableClickPropagation(container);
      L.DomEvent.disableScrollPropagation(container);

      // Button
      const btn = L.DomUtil.create('div', 'ic-layers-btn', container);
      btn.innerHTML = layersIconSvg;
      btn.title = 'Layers';

      // List wrapper (transparent hover bridge) + inner styled panel
      const listWrap = L.DomUtil.create('div', 'ic-layers-list', container);
      if (isTopPosition(position)) {
        listWrap.classList.add('ic-layers-list--below');
      } else {
        listWrap.classList.add('ic-layers-list--above');
      }
      const panel = L.DomUtil.create('div', 'ic-layers-panel', listWrap);
      listEl = panel;

      // Refresh on hover enter + fire events
      container.addEventListener('mouseenter', () => {
        if (!panelVisible) {
          panelVisible = true;
          opened?.();
        }
        if (layerRegistry) {
          rebuildList(layerRegistry.entries);
        }
      });
      container.addEventListener('mouseleave', () => {
        if (panelVisible) {
          panelVisible = false;
          closed?.();
        }
      });

      containerEl = container;
      return container;
    },
    onRemove() {
      containerEl = undefined;
      listEl = undefined;
    },
  });

  // --- Create control ---
  $effect(() => {
    const target = mapCtx.target;
    if (!target || !('addControl' in target)) return;

    control = untrack(() => {
      const ctrl = new LayersCtrl({
        position: position as L.ControlPosition,
      }).addTo(target as L.Map);
      logger.info('MapLayersControl', `Added to map at position: ${position}`);
      return ctrl;
    });

    return () => {
      control?.remove();
      control = undefined;
      containerEl = undefined;
      listEl = undefined;
      logger.info('MapLayersControl', 'Removed from map');
    };
  });

  // --- Rebuild list when registry entries change structurally ---
  $effect(() => {
    if (!listEl || !layerRegistry) return;
    const len = layerRegistry.entries.length;
    untrack(() => rebuildList(layerRegistry.entries));
    void len;
  });
</script>

<style>
  :global(.ic-layers-control) {
    position: relative;
  }

  :global(.ic-layers-btn) {
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
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
    transition: box-shadow 0.15s ease;
  }

  :global(.ic-layers-btn:hover) {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.25),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* Transparent wrapper — bridges the gap between button and panel */
  :global(.ic-layers-list) {
    display: none;
    position: absolute;
    right: 0;
    z-index: 1000;
  }

  :global(.ic-layers-control:hover .ic-layers-list) {
    display: block;
  }

  :global(.ic-layers-list--below) {
    top: 100%;
    padding-top: 4px;
  }
  :global(.ic-layers-list--above) {
    bottom: 100%;
    padding-bottom: 4px;
  }

  /* Styled inner panel */
  :global(.ic-layers-panel) {
    min-width: 170px;
    max-height: 240px;
    overflow-y: auto;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    padding: 4px 0;
    font-family: inherit;
    font-size: 0.8125rem;
    color: var(--ic-foreground);
  }

  /* Section headings */
  :global(.ic-layers-heading) {
    padding: 3px 10px 2px;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--ic-muted-foreground);
    user-select: none;
  }

  /* Separator between base and overlay sections */
  :global(.ic-layers-separator) {
    height: 1px;
    margin: 4px 8px;
    background: var(--ic-border);
  }

  :global(.ic-layers-row) {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 5px 10px;
    cursor: pointer;
    transition: background 0.1s;
    user-select: none;
  }

  :global(.ic-layers-row:hover) {
    background: var(--ic-secondary);
  }

  /* Shared input base for checkbox and radio */
  :global(.ic-layers-checkbox),
  :global(.ic-layers-radio) {
    appearance: none;
    width: 14px;
    height: 14px;
    border: 1px solid transparent;
    background: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    cursor: pointer;
    flex-shrink: 0;
    position: relative;
    margin: 0;
    transition: all 0.1s ease;
  }

  :global(.ic-layers-checkbox) {
    border-radius: 2px;
  }

  :global(.ic-layers-radio) {
    border-radius: 50%;
  }

  :global(.ic-layers-checkbox:checked),
  :global(.ic-layers-radio:checked) {
    background: var(--ic-primary);
    border-color: transparent;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.18);
  }

  /* Checkbox checkmark */
  :global(.ic-layers-checkbox:checked::after) {
    content: '';
    position: absolute;
    left: 3px;
    top: 0px;
    width: 5px;
    height: 8px;
    border: solid var(--ic-primary-foreground);
    border-width: 0 1.5px 1.5px 0;
    transform: rotate(45deg);
  }

  /* Radio dot */
  :global(.ic-layers-radio:checked::after) {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 5px;
    height: 5px;
    background: var(--ic-primary-foreground);
    border-radius: 50%;
    transform: translate(-50%, -50%);
  }

  :global(.ic-layers-name) {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    line-height: 1.3;
  }

  :global(.ic-layers-empty) {
    padding: 8px 12px;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    font-style: italic;
    font-size: 0.75rem;
    text-align: center;
  }

  /* Scrollbar styling for the panel */
  :global(.ic-layers-panel::-webkit-scrollbar) {
    width: 4px;
  }
  :global(.ic-layers-panel::-webkit-scrollbar-track) {
    background: transparent;
  }
  :global(.ic-layers-panel::-webkit-scrollbar-thumb) {
    background: var(--ic-border);
    border-radius: 2px;
  }
</style>
