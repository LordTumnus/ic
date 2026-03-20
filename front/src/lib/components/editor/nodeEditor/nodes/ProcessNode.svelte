<!--
  ProcessNode.svelte — Rounded rectangle process block.
  Standard flowchart process shape with one input and one output.
  Label displayed inside the shape, editable on double-click.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type ProcessData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type ProcessNodeType = Node<ProcessData, 'ic.node.Process'>;

  let { data, selected, dragging }: NodeProps<ProcessNodeType> = $props();

  let hovered = $state(false);

  const fill = $derived(data.backgroundColor || 'var(--ic-muted)');
  const stroke = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : data.outlineColor || 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-process"
  class:ic-ne-process--hovered={hovered && !selected && !dragging}
  class:ic-ne-process--selected={selected}
  class:ic-ne-process--dragging={dragging}
  class:ic-ne-process--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-process__svg" viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
    <rect
      x="1" y="1" width="98" height="48" rx="8"
      {fill}
      {stroke}
      stroke-width="1.5"
    />
  </svg>

  <!-- Label overlay inside the rectangle -->
  <div class="ic-ne-process__label-overlay">
    <InlineEdit
      value={data.label}
      className="ic-ne-process__label-text"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>

  <!-- Input handle: left midpoint -->
  {#if data.inputs?.[0]}
    <PortHandle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
      variant="dot"
    />
  {/if}

  <!-- Output handle: right midpoint -->
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
  .ic-ne-process {
    position: relative;
    width: 100px;
    height: 50px;
    transition: filter 0.15s ease;
  }

  .ic-ne-process--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-process--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-process--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-process--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-process__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-process__label-overlay {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
    max-width: 88px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-ne-process__label-overlay :global(.ic-ne-process__label-text) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
    text-align: center;
  }
</style>
