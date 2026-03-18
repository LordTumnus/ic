<!--
  GroupNode.svelte — Subflow container with Industrial Flat styling.
  Semi-transparent rectangle with header bar, resize handles, collapse toggle.
  Children are rendered by SvelteFlow via parentId, not by this component.

  Handles are placed directly in the group root (no intermediate positioned
  containers) so SvelteFlow measures their position relative to the node.
  Port labels/dots are separate visual-only elements.
-->
<script lang="ts">
  import {
    Handle,
    Position,
    NodeResizer,
    type NodeProps,
    type Node,
  } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import { getPortColor } from '$lib/utils/node-editor-types';
  import { hexToRgb } from '$lib/utils/color';

  type GroupData = {
    label: string;
    color: string;
    backgroundColor: string;
    backgroundOpacity: number;
    disabled: boolean;
    locked: boolean;
    width: number;
    height: number;
    collapsed: boolean;
    resizable: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onGroupResize?: (nodeId: string, width: number, height: number) => void;
    onGroupCollapse?: (nodeId: string, collapsed: boolean) => void;
  };

  type GroupNodeType = Node<GroupData, 'ic.node.Group'>;

  let { id, data, selected, dragging }: NodeProps<GroupNodeType> = $props();

  let hovered = $state(false);

  const accentColor = $derived(data.color || 'var(--ic-primary)');
  const bgOpacity = $derived(data.backgroundOpacity ?? 0);

  const bgStyle = $derived.by(() => {
    const opacity = bgOpacity;
    if (opacity <= 0) return '';
    const color = data.backgroundColor;
    if (color && color.startsWith('#')) {
      const { r, g, b } = hexToRgb(color);
      return `background: rgba(${r}, ${g}, ${b}, ${opacity})`;
    }
    return `background: rgba(128, 128, 128, ${opacity * 0.3})`;
  });

  const hasInputs = $derived((data.inputs?.length ?? 0) > 0);
  const hasOutputs = $derived((data.outputs?.length ?? 0) > 0);

  const BASE_HEADER_H = 30;
  const PORT_ROW_H = 24;
  const PORT_PAD = 20;

  /** Height of the header when collapsed — header + room for ports. */
  const collapsedH = $derived((() => {
    const maxPorts = Math.max(data.inputs?.length ?? 0, data.outputs?.length ?? 0);
    if (maxPorts === 0) return BASE_HEADER_H;
    return BASE_HEADER_H + maxPorts * PORT_ROW_H + PORT_PAD;
  })());

  /** Compute vertical position (%) for the i-th port out of count.
   *  When collapsed, ports are placed below the header band. */
  function portTopPct(i: number, count: number): number {
    const h = data.collapsed ? collapsedH : data.height;
    if (data.collapsed) {
      // Distribute ports in the area below the header
      const availH = h - BASE_HEADER_H;
      const spacing = availH / (count + 1);
      const top = BASE_HEADER_H + spacing * (i + 1);
      return (top / h) * 100;
    }
    if (h <= BASE_HEADER_H) return 50;
    const spacing = h / (count + 1);
    const top = spacing * (i + 1);
    return (top / h) * 100;
  }


  function handleResizeEnd(
    _event: MouseEvent | TouchEvent,
    params: { width: number; height: number },
  ) {
    data.onGroupResize?.(id, params.width, params.height);
  }

  function toggleCollapse(e: MouseEvent) {
    e.stopPropagation();
    data.onGroupCollapse?.(id, !data.collapsed);
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-group"
  style={bgStyle}
  class:ic-ne-group--hovered={hovered && !selected && !dragging}
  class:ic-ne-group--selected={selected}
  class:ic-ne-group--dragging={dragging}
  class:ic-ne-group--disabled={data.disabled}
  class:ic-ne-group--collapsed={data.collapsed}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  {#if data.resizable && !data.collapsed}
    <NodeResizer
      minWidth={120}
      minHeight={60}
      isVisible={selected}
      lineClass="ic-ne-group__resize-line"
      handleClass="ic-ne-group__resize-handle"
      onResizeEnd={handleResizeEnd}
    />
  {/if}

  <div class="ic-ne-group__header" style:--accent={accentColor}>
    <button
      class="ic-ne-group__chevron"
      class:ic-ne-group__chevron--collapsed={data.collapsed}
      onclick={toggleCollapse}
      aria-label={data.collapsed ? 'Expand group' : 'Collapse group'}
    >
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path
          d="M3 4.5L6 7.5L9 4.5"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>
    <span class="ic-ne-group__label">{data.label || 'Group'}</span>
  </div>

  <!-- Handles: exterior + interior overlap at the same edge position.
       Direction (Position) differs so edges route correctly inward/outward. -->
  {#each data.inputs ?? [] as port, i (port.name)}
    {@const top = portTopPct(i, data.inputs.length)}
    {#key port.name}
      <Handle
        type="target"
        position={Position.Left}
        id={port.name}
        style="top: {top}%"
      />
    {/key}
    {#if !data.collapsed}
      {#key `${port.name}:int`}
        <Handle
          type="source"
          position={Position.Right}
          id={`${port.name}:int`}
          style="top: {top}%; left: 0; right: auto"
        />
      {/key}
    {/if}
  {/each}

  {#each data.outputs ?? [] as port, i (port.name)}
    {@const top = portTopPct(i, data.outputs.length)}
    {#key port.name}
      <Handle
        type="source"
        position={Position.Right}
        id={port.name}
        style="top: {top}%"
      />
    {/key}
    {#if !data.collapsed}
      {#key `${port.name}:int`}
        <Handle
          type="target"
          position={Position.Left}
          id={`${port.name}:int`}
          style="top: {top}%; right: 0; left: auto"
        />
      {/key}
    {/if}
  {/each}

  <!-- Port visuals: dot at handle height, label above -->
  {#each data.inputs ?? [] as port, i (port.name)}
    {@const top = portTopPct(i, data.inputs.length)}
    <div
      class="ic-ne-group__port-hit ic-ne-group__port-hit--left"
      style="top: {top}%"
      data-port-name={port.name}
      data-port-side="input"
    >
      <span
        class="ic-ne-group__port-dot"
        style:background-color={getPortColor(port)}
      ></span>
      <span class="ic-ne-group__port-label">{port.label || port.name}</span>
    </div>
  {/each}

  {#each data.outputs ?? [] as port, i (port.name)}
    {@const top = portTopPct(i, data.outputs.length)}
    <div
      class="ic-ne-group__port-hit ic-ne-group__port-hit--right"
      style="top: {top}%"
      data-port-name={port.name}
      data-port-side="output"
    >
      <span class="ic-ne-group__port-label">{port.label || port.name}</span>
      <span
        class="ic-ne-group__port-dot"
        style:background-color={getPortColor(port)}
      ></span>
    </div>
  {/each}
</div>

<style>
  /* ── Group container ────────────────────────── */
  .ic-ne-group {
    width: 100%;
    height: 100%;
    border: 1px dashed var(--ic-border);
    border-radius: 3px;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    position: relative;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-group--hovered {
    border-color: var(--ic-muted-foreground);
  }

  .ic-ne-group--selected {
    border-color: var(--ic-primary);
    box-shadow: 0 0 0 1px var(--ic-primary);
  }

  .ic-ne-group--dragging {
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.2);
  }

  .ic-ne-group--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-group--collapsed {
    overflow: clip;
  }

  /* ── Header ────────────────────────────────── */
  .ic-ne-group__header {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 4px 8px;
    background: var(--ic-muted);
    color: var(--ic-muted-foreground);
    font-weight: 600;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    border-bottom: 2px solid var(--accent);
    border-radius: 3px 3px 0 0;
    user-select: none;
    position: relative;
    z-index: 1;
  }

  .ic-ne-group__chevron {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    padding: 0;
    border: none;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    border-radius: 2px;
    flex-shrink: 0;
    transition: transform 0.15s ease;
  }

  .ic-ne-group__chevron:hover {
    background: rgba(128, 128, 128, 0.15);
  }

  .ic-ne-group__chevron--collapsed {
    transform: rotate(-90deg);
  }

  .ic-ne-group__label {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
  }

  /* ── Port hit area (clickable container for dot + label) ── */
  .ic-ne-group__port-hit {
    position: absolute;
    display: flex;
    align-items: center;
    gap: 4px;
    transform: translateY(-50%);
    cursor: pointer;
    padding: 2px 4px;
    border-radius: 2px;
    z-index: 2;
  }

  .ic-ne-group__port-hit:hover {
    background: rgba(128, 128, 128, 0.1);
  }

  .ic-ne-group__port-hit--left {
    left: 2px;
  }

  .ic-ne-group__port-hit--right {
    right: 2px;
  }

  /* ── Port dot ─────────────────────────────────── */
  .ic-ne-group__port-dot {
    width: 7px;
    height: 7px;
    border-radius: 2px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    flex-shrink: 0;
  }

  /* ── Port label ───────────────────────────────── */
  .ic-ne-group__port-label {
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
  }

  /* ── Hide SF's default handle visuals ────────── */
  .ic-ne-group :global(.svelte-flow__handle) {
    width: 10px;
    height: 10px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }

  /* ── Resize handle styling ──────────────────── */
  .ic-ne-group :global(.ic-ne-group__resize-handle) {
    width: 8px;
    height: 8px;
    background: var(--ic-primary);
    border: 1px solid var(--ic-background);
    border-radius: 2px;
  }

  .ic-ne-group :global(.ic-ne-group__resize-line) {
    border-color: var(--ic-primary);
  }
</style>
