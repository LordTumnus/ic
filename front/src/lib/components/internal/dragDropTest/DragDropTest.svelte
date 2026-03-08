<!--
  DragDropTest — Diagnostic for drag-and-drop in MATLAB CEF.

  Two side-by-side bins with colored cards. Drag within and between bins.
  Uses svelte-dnd-action (mouse-based, bypasses CEF HTML5 DnD block).
-->
<script lang="ts">
  import { dndzone, SHADOW_ITEM_MARKER_PROPERTY_NAME, SHADOW_PLACEHOLDER_ITEM_ID } from 'svelte-dnd-action';
  import { flip } from 'svelte/animate';
  import type { PublishFn } from '$lib/types';
  import logger from '$lib/core/logger';

  interface DndItem {
    id: number;
    name: string;
    color: string;
    [SHADOW_ITEM_MARKER_PROPERTY_NAME]?: boolean;
  }

  let {
    listA: listAProp = [],
    listB: listBProp = [],
    disabled = false,
    orderChanged,
    publish,
  }: {
    listA?: DndItem[];
    listB?: DndItem[];
    disabled?: boolean;
    orderChanged?: (data?: unknown) => void;
    publish?: PublishFn;
  } = $props();

  // Local copies for svelte-dnd-action (it mutates items with shadow markers
  // that would break MATLAB's struct typing if synced via $bindable)
  let itemsA = $state<DndItem[]>([]);
  let itemsB = $state<DndItem[]>([]);

  // Sync from MATLAB → local on prop change
  $effect(() => { itemsA = listAProp.map((it) => ({ ...it })); });
  $effect(() => { itemsB = listBProp.map((it) => ({ ...it })); });

  const FLIP_MS = 200;
  const ZONE_TYPE = 'dnd-test';

  function handleConsiderA(e: CustomEvent<{ items: DndItem[] }>) {
    itemsA = e.detail.items;
  }

  function handleFinalizeA(e: CustomEvent<{ items: DndItem[] }>) {
    itemsA = e.detail.items;
    fireOrderChanged();
  }

  function handleConsiderB(e: CustomEvent<{ items: DndItem[] }>) {
    itemsB = e.detail.items;
  }

  function handleFinalizeB(e: CustomEvent<{ items: DndItem[] }>) {
    itemsB = e.detail.items;
    fireOrderChanged();
  }

  function clean(items: DndItem[]) {
    return items
      .filter((it) => it.id !== SHADOW_PLACEHOLDER_ITEM_ID)
      .map(({ id, name, color }) => ({ id, name, color }));
  }

  function fireOrderChanged() {
    const payload = { value: { listA: clean(itemsA), listB: clean(itemsB) } };
    orderChanged?.(payload);
    logger.debug('DragDropTest', 'Order changed', payload);
  }
</script>

<div class="ic-ddt">
  <div class="ic-ddt__header">Drag & Drop Test</div>
  <div class="ic-ddt__meta">
    svelte-dnd-action — mouse-based DnD (bypasses CEF HTML5 DnD block)
  </div>

  <div class="ic-ddt__bins">
    <div class="ic-ddt__bin">
      <div class="ic-ddt__bin-label">List A</div>
      <div
        class="ic-ddt__zone"
        use:dndzone={{ items: itemsA, flipDurationMs: FLIP_MS, type: ZONE_TYPE, dragDisabled: disabled }}
        onconsider={handleConsiderA}
        onfinalize={handleFinalizeA}
      >
        {#each itemsA as item (item.id)}
          <div
            class="ic-ddt__card"
            class:ic-ddt__card--shadow={item[SHADOW_ITEM_MARKER_PROPERTY_NAME]}
            style="--card-accent: {item.color}"
            animate:flip={{ duration: FLIP_MS }}
          >
            <span class="ic-ddt__card-indicator"></span>
            <span class="ic-ddt__card-label">{item.name}</span>
            <span class="ic-ddt__card-id">#{item.id}</span>
          </div>
        {/each}
      </div>
    </div>

    <div class="ic-ddt__bin">
      <div class="ic-ddt__bin-label">List B</div>
      <div
        class="ic-ddt__zone"
        use:dndzone={{ items: itemsB, flipDurationMs: FLIP_MS, type: ZONE_TYPE, dragDisabled: disabled }}
        onconsider={handleConsiderB}
        onfinalize={handleFinalizeB}
      >
        {#each itemsB as item (item.id)}
          <div
            class="ic-ddt__card"
            class:ic-ddt__card--shadow={item[SHADOW_ITEM_MARKER_PROPERTY_NAME]}
            style="--card-accent: {item.color}"
            animate:flip={{ duration: FLIP_MS }}
          >
            <span class="ic-ddt__card-indicator"></span>
            <span class="ic-ddt__card-label">{item.name}</span>
            <span class="ic-ddt__card-id">#{item.id}</span>
          </div>
        {/each}
      </div>
    </div>
  </div>
</div>

<style>
  .ic-ddt {
    font-family: var(--ic-font-family);
    font-size: var(--ic-font-size);
    padding: 16px;
    background: var(--ic-background, #fff);
    color: var(--ic-foreground, #1a1a1a);
    border: 1px solid var(--ic-border, #ccc);
    border-radius: 2px;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }

  .ic-ddt__header {
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 4px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--ic-border, #ccc);
  }

  .ic-ddt__meta {
    font-size: 11px;
    color: var(--ic-muted-foreground, #666);
    margin-bottom: 12px;
    font-style: italic;
  }

  .ic-ddt__bins {
    display: flex;
    gap: 12px;
  }

  .ic-ddt__bin {
    flex: 1;
    min-width: 0;
  }

  .ic-ddt__bin-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--ic-muted-foreground, #666);
    margin-bottom: 6px;
  }

  .ic-ddt__zone {
    min-height: 80px;
    padding: 6px;
    background: var(--ic-secondary, #f5f5f5);
    border: 1px solid var(--ic-border, #ccc);
    border-radius: 2px;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.08);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .ic-ddt__card {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 10px;
    background: var(--ic-background, #fff);
    border: 1px solid var(--ic-border, #ccc);
    border-radius: 2px;
    cursor: grab;
    user-select: none;
    box-shadow:
      0 1px 2px rgba(0, 0, 0, 0.06),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
    transition: box-shadow 0.15s ease;
  }

  .ic-ddt__card:hover {
    box-shadow:
      0 2px 4px rgba(0, 0, 0, 0.1),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  .ic-ddt__card:active {
    cursor: grabbing;
  }

  .ic-ddt__card--shadow {
    opacity: 0.4;
    border-style: dashed;
    background: var(--ic-secondary, #f5f5f5);
  }

  .ic-ddt__card-indicator {
    width: 4px;
    height: 20px;
    border-radius: 1px;
    background: var(--card-accent);
    flex-shrink: 0;
  }

  .ic-ddt__card-label {
    flex: 1;
    font-weight: 500;
    font-size: 13px;
  }

  .ic-ddt__card-id {
    font-size: 11px;
    color: var(--ic-muted-foreground, #888);
    font-variant-numeric: tabular-nums;
  }
</style>
