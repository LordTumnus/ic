<!--
  AccumulatorNode.svelte — Summation node: SVG sigma (Σ) symbol.
  N inputs → 1 signal output with their sum.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type AccumulatorData = {
    label: string;
    inputNumber: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type AccumulatorNodeType = Node<AccumulatorData, 'ic.node.Accumulator'>;

  let { data, selected, dragging }: NodeProps<AccumulatorNodeType> = $props();

  let hovered = $state(false);

  const strokeColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : 'var(--ic-border)',
  );

  // Port vertical positions
  function portTop(index: number, total: number): string {
    if (total <= 1) return '50%';
    const start = 25;
    const end = 75;
    const pct = start + (index / (total - 1)) * (end - start);
    return `${pct}%`;
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-acc"
  class:ic-ne-acc--hovered={hovered && !selected && !dragging}
  class:ic-ne-acc--selected={selected}
  class:ic-ne-acc--dragging={dragging}
  class:ic-ne-acc--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-acc__svg" viewBox="0 0 40 50">
    <!-- Sigma as a filled 2D shape -->
    <path
      d="M 32 4 L 8 4 L 20 25 L 8 46 L 32 46 L 32 40 L 16 40 L 25 25 L 16 10 L 32 10 Z"
      fill="var(--ic-muted-foreground)"
      stroke="var(--ic-muted-foreground)"
      stroke-width="1.5"
      stroke-linejoin="round"
    />
  </svg>

  <!-- Label -->
  {#if data.label}
    <div class="ic-ne-acc__label">
      <InlineEdit value={data.label} className="ic-ne-acc__label-edit" oncommit={(v) => data.onpropchange?.('label', v)} />
    </div>
  {/if}

  <!-- Input ports (left, evenly spaced) -->
  {#if data.inputs?.length}
    {#each data.inputs as port, i (port.name)}
      <PortHandle
        type="target"
        position={Position.Left}
        id={port.name}
        variant="dot"
        style="top: {portTop(i, data.inputs.length)}; left: -3px; transform: translateY(-50%);"
      />
    {/each}
  {/if}

  <!-- Output port (right) -->
  {#if data.outputs?.[0]}
    <PortHandle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
      variant="dot"
    />
  {/if}
</div>

<style>
  .ic-ne-acc {
    position: relative;
    width: 40px;
  }

  .ic-ne-acc--selected {
    filter: drop-shadow(0 0 2px var(--ic-primary));
  }

  .ic-ne-acc--dragging {
    filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.3));
  }

  .ic-ne-acc--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-acc__svg {
    width: 100%;
    height: auto;
    display: block;
  }

  .ic-ne-acc__label {
    text-align: center;
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
    padding: 0 2px;
  }
</style>
