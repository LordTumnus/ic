<!--
  CloudNode.svelte — Cloud shape node.
  Flowchart cloud symbol for external systems or services.
  Label displayed inside, editable on double-click.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type CloudData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type CloudNodeType = Node<CloudData, 'ic.node.Cloud'>;

  let { data, selected, dragging }: NodeProps<CloudNodeType> = $props();

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
  class="ic-ne-cloud"
  class:ic-ne-cloud--hovered={hovered && !selected && !dragging}
  class:ic-ne-cloud--selected={selected}
  class:ic-ne-cloud--dragging={dragging}
  class:ic-ne-cloud--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-cloud__svg" viewBox="0 0 120 70" xmlns="http://www.w3.org/2000/svg">
    <path
      d="M25,55 C5,55 0,40 15,30 C5,15 25,5 40,10 C45,0 65,0 75,10 C90,2 110,15 105,30 C120,35 120,55 100,55 Z"
      {fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
  </svg>

  <!-- Label overlay inside the cloud -->
  <div class="ic-ne-cloud__label-overlay">
    <InlineEdit
      value={data.label}
      className="ic-ne-cloud__label-text"
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
  .ic-ne-cloud {
    position: relative;
    width: 120px;
    height: 70px;
    transition: filter 0.15s ease;
  }

  .ic-ne-cloud--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-cloud--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-cloud--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-cloud--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-cloud__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-cloud__label-overlay {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
    max-width: 90px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-ne-cloud__label-overlay :global(.ic-ne-cloud__label-text) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
    text-align: center;
  }
</style>
