<!--
  MuxNode.svelte — Multiplexer: N inputs → 1 output.
  Rendered as a black tapered trapezoid bar (Simulink style).
  Input ports on the left edge, output on the right.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';

  type MuxData = {
    label: string;
    inputNumber: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type MuxNodeType = Node<MuxData, 'ic.node.Mux'>;

  let { data, selected, dragging }: NodeProps<MuxNodeType> = $props();

  let hovered = $state(false);

  // Height scales with port count
  const portCount = $derived(data.inputs?.length ?? 2);
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
  class="ic-ne-mux"
  class:ic-ne-mux--selected={selected}
  class:ic-ne-mux--dragging={dragging}
  class:ic-ne-mux--disabled={data.disabled}
  style:height="{barH}px"
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-mux__svg" viewBox="0 0 14 {barH}" preserveAspectRatio="none">
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
    <div class="ic-ne-mux__label">{data.label}</div>
  {/if}

  <!-- Input ports (left edge, evenly distributed) -->
  {#if data.inputs?.length}
    {#each data.inputs as port, i (port.name)}
      <PortHandle
        type="target"
        position={Position.Left}
        id={port.name}
        variant="dot"
        color="var(--ic-background)"
        style="top: {portTop(i, data.inputs.length)}; left: -3px; transform: translateY(-50%);"
      />
    {/each}
  {/if}

  <!-- Output port (right, centered) -->
  {#if data.outputs?.[0]}
    <PortHandle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
      variant="dot"
      color="var(--ic-background)"
    />
  {/if}
</div>

<style>
  .ic-ne-mux {
    position: relative;
    width: 14px;
  }

  .ic-ne-mux--selected {
    filter: drop-shadow(0 0 2px var(--ic-primary));
  }

  .ic-ne-mux--dragging {
    filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.3));
  }

  .ic-ne-mux--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-mux__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-mux__label {
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
