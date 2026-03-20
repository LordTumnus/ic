<!--
  DecisionNode.svelte — Diamond decision shape.
  Classic flowchart conditional with "yes" (right) and "no" (bottom) outputs.
  Label displayed inside the diamond, editable on double-click.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type DecisionData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type DecisionNodeType = Node<DecisionData, 'ic.node.Decision'>;

  let { data, selected, dragging }: NodeProps<DecisionNodeType> = $props();

  let hovered = $state(false);

  const fill = $derived(data.backgroundColor || 'var(--ic-muted)');
  const stroke = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : data.outlineColor || 'var(--ic-border)',
  );

  // Find specific output ports by name
  const yesPort = $derived(data.outputs?.find((p) => p.name === 'yes'));
  const noPort = $derived(data.outputs?.find((p) => p.name === 'no'));
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-decision"
  class:ic-ne-decision--hovered={hovered && !selected && !dragging}
  class:ic-ne-decision--selected={selected}
  class:ic-ne-decision--dragging={dragging}
  class:ic-ne-decision--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-decision__svg" viewBox="-1 -1 82 82" xmlns="http://www.w3.org/2000/svg">
    <polygon
      points="40,0 80,40 40,80 0,40"
      {fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
  </svg>

  <!-- Label overlay inside the diamond -->
  <div class="ic-ne-decision__label-overlay">
    <InlineEdit
      value={data.label}
      className="ic-ne-decision__label-text"
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

  <!-- Output "yes" handle: right midpoint -->
  {#if yesPort}
    <PortHandle
      type="source"
      position={Position.Right}
      id={yesPort.name}
      variant="dot"
    />
  {/if}

  <!-- Output "no" handle: bottom center -->
  {#if noPort}
    <div class="ic-ne-decision__bottom-port">
      <PortHandle
        type="source"
        position={Position.Bottom}
        id={noPort.name}
        variant="dot"
        style="top: auto; bottom: -3px; left: 50%; transform: translateX(-50%);"
      />
    </div>
  {/if}
</div>

<style>
  .ic-ne-decision {
    position: relative;
    width: 80px;
    height: 80px;
    transition: filter 0.15s ease;
  }

  .ic-ne-decision--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-decision--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-decision--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-decision--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-decision__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-decision__label-overlay {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
    max-width: 56px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-ne-decision__label-overlay :global(.ic-ne-decision__label-text) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
    text-align: center;
  }

  .ic-ne-decision__bottom-port {
    position: absolute;
    bottom: -3px;
    left: 50%;
    transform: translateX(-50%);
  }
</style>
