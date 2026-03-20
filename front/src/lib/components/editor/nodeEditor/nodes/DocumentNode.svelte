<!--
  DocumentNode.svelte — Page shape with wavy bottom edge.
  SVG document/page silhouette with label inside.
  Input port on left, output port on right.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type DocumentData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type DocumentNodeType = Node<DocumentData, 'ic.node.Document'>;

  let { data, selected, dragging }: NodeProps<DocumentNodeType> = $props();

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
  class="ic-ne-document"
  class:ic-ne-document--hovered={hovered && !selected && !dragging}
  class:ic-ne-document--selected={selected}
  class:ic-ne-document--dragging={dragging}
  class:ic-ne-document--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-document__svg" viewBox="0 0 80 90" xmlns="http://www.w3.org/2000/svg">
    <path
      d="M2,2 L78,2 L78,75 Q60,85 40,75 Q20,65 2,75 Z"
      {fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
  </svg>

  <!-- Label overlay inside the page shape -->
  <div class="ic-ne-document__label-overlay">
    <InlineEdit
      value={data.label}
      className="ic-ne-document__label-text"
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
  .ic-ne-document {
    position: relative;
    width: 80px;
    height: 90px;
    transition: filter 0.15s ease;
  }

  .ic-ne-document--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-document--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-document--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-document--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-document__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-document__label-overlay {
    position: absolute;
    top: 30%;
    left: 50%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
  }

  .ic-ne-document__label-overlay :global(.ic-ne-document__label-text) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
  }
</style>
