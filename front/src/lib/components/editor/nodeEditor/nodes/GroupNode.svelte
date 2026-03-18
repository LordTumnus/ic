<!--
  GroupNode.svelte — Basic group container with Industrial Flat styling.
  Simple label bar + optional background color. No accent stripe,
  no collapse toggle, no resize handles.
  Children are rendered by SvelteFlow via parentId.
-->
<script lang="ts">
  import {
    Handle,
    Position,
    type NodeProps,
    type Node,
  } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import { getPortColor } from '$lib/utils/node-editor-types';
  import { hexToRgb } from '$lib/utils/color';

  type GroupData = {
    label: string;
    backgroundColor: string;
    backgroundOpacity: number;
    disabled: boolean;
    locked: boolean;
    width: number;
    height: number;
    inputs: PortDef[];
    outputs: PortDef[];
  };

  type GroupNodeType = Node<GroupData, 'ic.node.BasicGroup'>;

  let { id, data, selected, dragging }: NodeProps<GroupNodeType> = $props();

  let hovered = $state(false);

  const bgStyle = $derived.by(() => {
    const opacity = data.backgroundOpacity ?? 0;
    if (opacity <= 0) return '';
    const color = data.backgroundColor;
    if (color && color.startsWith('#')) {
      const { r, g, b } = hexToRgb(color);
      return `background: rgba(${r}, ${g}, ${b}, ${opacity})`;
    }
    return `background: rgba(128, 128, 128, ${opacity * 0.3})`;
  });

  /** Compute vertical position (%) for the i-th port out of count. */
  function portTopPct(i: number, count: number): number {
    const h = data.height;
    if (h <= 30) return 50;
    const spacing = h / (count + 1);
    const top = spacing * (i + 1);
    return (top / h) * 100;
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
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <span class="ic-ne-group__label">{data.label || 'Group'}</span>

  <!-- Handles: exterior + interior -->
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
    {#key `${port.name}:int`}
      <Handle
        type="source"
        position={Position.Right}
        id={`${port.name}:int`}
        style="top: {top}%; left: 0; right: auto"
      />
    {/key}
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
    {#key `${port.name}:int`}
      <Handle
        type="target"
        position={Position.Left}
        id={`${port.name}:int`}
        style="top: {top}%; right: 0; left: auto"
      />
    {/key}
  {/each}

  <!-- Port visuals -->
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

  /* ── Label ─────────────────────────────────── */
  .ic-ne-group__label {
    position: absolute;
    top: 4px;
    left: 6px;
    font-weight: 600;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--ic-muted-foreground);
    opacity: 0.7;
    user-select: none;
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
    z-index: 1;
  }

  /* ── Port hit area ── */
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

  .ic-ne-group__port-dot {
    width: 7px;
    height: 7px;
    border-radius: 2px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    flex-shrink: 0;
  }

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
</style>
