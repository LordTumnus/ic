<!--
  QueueNode.svelte — Horizontal cylinder shape (queue/buffer).
  SVG cylinder with left ellipse separator, label inside.
  Input port on left, output port on right.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type QueueData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type QueueNodeType = Node<QueueData, 'ic.node.Queue'>;

  let { data, selected, dragging }: NodeProps<QueueNodeType> = $props();

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
  class="ic-ne-queue"
  class:ic-ne-queue--hovered={hovered && !selected && !dragging}
  class:ic-ne-queue--selected={selected}
  class:ic-ne-queue--dragging={dragging}
  class:ic-ne-queue--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-queue__svg" viewBox="0 0 120 60" xmlns="http://www.w3.org/2000/svg">
    <!-- Cylinder body outline -->
    <path
      d="M15,2 L105,2 A13,28 0 0,1 105,58 L15,58 A13,28 0 0,1 15,2 Z"
      {fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Left cap separator ellipse (stroke only) -->
    <ellipse
      cx="15" cy="30" rx="13" ry="28"
      fill="none"
      {stroke}
      stroke-width="1.5"
    />
  </svg>

  <!-- Label overlay centered in the body area -->
  <div class="ic-ne-queue__label-overlay">
    <InlineEdit
      value={data.label}
      className="ic-ne-queue__label-text"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>

  <!-- Input handle: left midpoint -->
  {#if data.inputs?.[0]}
    <PortHandle type="target" position={Position.Left} id={data.inputs[0].name} variant="dot" />
  {/if}

  <!-- Output handle: right midpoint -->
  {#if data.outputs?.[0]}
    <PortHandle type="source" position={Position.Right} id={data.outputs[0].name} variant="dot" />
  {/if}
</div>

<style>
  .ic-ne-queue {
    position: relative;
    width: 120px;
    height: 60px;
    transition: filter 0.15s ease;
  }

  .ic-ne-queue--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-queue--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-queue--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-queue--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-queue__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-queue__label-overlay {
    position: absolute;
    top: 50%;
    left: 55%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
  }

  .ic-ne-queue__label-overlay :global(.ic-ne-queue__label-text) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
  }
</style>
