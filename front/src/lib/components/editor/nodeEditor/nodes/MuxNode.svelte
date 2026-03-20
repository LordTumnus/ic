<!--
  MuxNode.svelte — Multiplexer: N inputs → 1 output.
  Rendered as a black tapered trapezoid bar (Simulink style).
  Input ports on the left edge, output on the right.
-->
<script lang="ts">
  import { Position, NodeResizer, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';

  type MuxData = {
    label: string;
    inputNumber: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onNodeResize?: (nodeId: string, width: number, height: number) => void;
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type MuxNodeType = Node<MuxData, 'ic.node.Mux'>;

  let { id, data, selected, dragging }: NodeProps<MuxNodeType> = $props();

  let hovered = $state(false);

  // Minimum height scales with port count
  const portCount = $derived(data.inputs?.length ?? 2);
  const minH = $derived(Math.max(50, portCount * 22));

  const strokeColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : 'var(--ic-foreground)',
  );

  // Port positions as percentage (responsive to resize)
  function portTop(index: number, total: number): string {
    if (total <= 1) return '50%';
    const startPct = 12;
    const endPct = 88;
    const pct = startPct + (index / (total - 1)) * (endPct - startPct);
    return `${pct}%`;
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-mux"
  class:ic-ne-mux--selected={selected}
  class:ic-ne-mux--dragging={dragging}
  class:ic-ne-mux--disabled={data.disabled}
  style:min-height="{minH}px"
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <NodeResizer
    minWidth={14}
    maxWidth={14}
    minHeight={minH}
    isVisible={selected}
    lineClass="ic-ne-mux__resize-line"
    handleClass="ic-ne-mux__resize-handle"
    onResizeEnd={(_e, params) => data.onNodeResize?.(id, params.width, params.height)}
  />

  <svg class="ic-ne-mux__svg" viewBox="0 0 14 100" preserveAspectRatio="none">
    <rect
      x="0" y="0" width="14" height="100"
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
    height: 100%;
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

  /* Resize: hide edge lines, show only bottom handle */
  .ic-ne-mux :global(.ic-ne-mux__resize-line) {
    border-color: transparent;
  }

  .ic-ne-mux :global(.ic-ne-mux__resize-handle) {
    width: 8px;
    height: 4px;
    background: var(--ic-muted-foreground);
    border: none;
    border-radius: 1px;
    opacity: 0.5;
    transition: opacity 0.15s ease, background 0.15s ease;
  }

  .ic-ne-mux :global(.ic-ne-mux__resize-handle:hover) {
    background: var(--ic-primary);
    opacity: 1;
  }

  /* Hide corner handles — only keep bottom center */
  .ic-ne-mux :global(.ic-ne-mux__resize-handle.top),
  .ic-ne-mux :global(.ic-ne-mux__resize-handle.left),
  .ic-ne-mux :global(.ic-ne-mux__resize-handle.right) {
    display: none;
  }
</style>
