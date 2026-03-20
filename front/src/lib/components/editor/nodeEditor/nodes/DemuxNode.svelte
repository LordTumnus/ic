<!--
  DemuxNode.svelte — Demultiplexer: 1 input → N outputs.
  Rendered as a black tapered trapezoid bar (mirrored Mux).
  Input on the left, output ports on the right edge.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';

  type DemuxData = {
    label: string;
    outputNumber: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type DemuxNodeType = Node<DemuxData, 'ic.node.Demux'>;

  let { data, selected, dragging }: NodeProps<DemuxNodeType> = $props();

  let hovered = $state(false);

  // Height scales with port count
  const portCount = $derived(data.outputs?.length ?? 2);
  const barH = $derived(Math.max(50, portCount * 22));

  const strokeColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : 'var(--ic-foreground)',
  );

  // Port top positions (evenly spaced)
  function portTop(index: number, total: number): string {
    if (total <= 1) return '50%';
    const padding = 8;
    const usable = barH - padding * 2;
    const y = padding + (index / (total - 1)) * usable;
    return `${y}px`;
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-demux"
  class:ic-ne-demux--selected={selected}
  class:ic-ne-demux--dragging={dragging}
  class:ic-ne-demux--disabled={data.disabled}
  style:height="{barH}px"
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-demux__svg" viewBox="0 0 14 {barH}" preserveAspectRatio="none">
    <rect
      x="0" y="0" width="14" height={barH}
      fill="var(--ic-foreground)"
      stroke={strokeColor}
      stroke-width="1"
      opacity="0.9"
    />
  </svg>

  <!-- Label -->
  {#if data.label}
    <div class="ic-ne-demux__label">{data.label}</div>
  {/if}

  <!-- Input port (left, centered) -->
  {#if data.inputs?.[0]}
    <PortHandle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
      variant="dot"
      color="var(--ic-background)"
    />
  {/if}

  <!-- Output ports (right edge, evenly distributed) -->
  {#if data.outputs?.length}
    {#each data.outputs as port, i (port.name)}
      <PortHandle
        type="source"
        position={Position.Right}
        id={port.name}
        variant="dot"
        color="var(--ic-background)"
        style="top: {portTop(i, data.outputs.length)}; right: -3px; transform: translateY(-50%);"
      />
    {/each}
  {/if}
</div>

<style>
  .ic-ne-demux {
    position: relative;
    width: 14px;
  }

  .ic-ne-demux--selected {
    filter: drop-shadow(0 0 2px var(--ic-primary));
  }

  .ic-ne-demux--dragging {
    filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.3));
  }

  .ic-ne-demux--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-demux__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-demux__label {
    position: absolute;
    bottom: -14px;
    left: 50%;
    transform: translateX(-50%);
    font-family: var(--ic-font-family);
    font-size: 9px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
</style>
