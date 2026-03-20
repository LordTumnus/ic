<!--
  DatabaseNode.svelte — Cylinder database shape.
  Classic flowchart data-store symbol: top ellipse lid, rectangular body, bottom ellipse cap.
  Label displayed inside the body, editable on double-click.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type DatabaseData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type DatabaseNodeType = Node<DatabaseData, 'ic.node.Database'>;

  let { data, selected, dragging }: NodeProps<DatabaseNodeType> = $props();

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
  class="ic-ne-database"
  class:ic-ne-database--hovered={hovered && !selected && !dragging}
  class:ic-ne-database--selected={selected}
  class:ic-ne-database--dragging={dragging}
  class:ic-ne-database--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-database__svg" viewBox="0 0 80 80" xmlns="http://www.w3.org/2000/svg">
    <!-- Body + bottom cap as a single filled path (no stroke on sides hidden by top lid) -->
    <path
      d="M2,14 L2,66 A38,12 0 0,0 78,66 L78,14"
      {fill}
      stroke="none"
    />
    <!-- Bottom ellipse outline -->
    <ellipse
      cx="40" cy="66" rx="38" ry="12"
      fill="none"
      {stroke}
      stroke-width="1.5"
    />
    <!-- Side lines -->
    <line x1="2" y1="14" x2="2" y2="66" stroke={stroke} stroke-width="1.5" />
    <line x1="78" y1="14" x2="78" y2="66" stroke={stroke} stroke-width="1.5" />
    <!-- Top ellipse (visible lid) -->
    <ellipse
      cx="40" cy="14" rx="38" ry="12"
      {fill}
      {stroke}
      stroke-width="1.5"
    />
  </svg>

  <!-- Label overlay inside the body portion -->
  <div class="ic-ne-database__label-overlay">
    <InlineEdit
      value={data.label}
      className="ic-ne-database__label-text"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>

  <!-- Input handle: left at vertical midpoint of body (~y=40) -->
  {#if data.inputs?.[0]}
    <PortHandle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
      variant="dot"
    />
  {/if}

  <!-- Output handle: right at vertical midpoint of body -->
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
  .ic-ne-database {
    position: relative;
    width: 80px;
    height: 80px;
    transition: filter 0.15s ease;
  }

  .ic-ne-database--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-database--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-database--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-database--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-database__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-database__label-overlay {
    position: absolute;
    top: 55%;
    left: 50%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
    max-width: 64px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-ne-database__label-overlay :global(.ic-ne-database__label-text) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
    text-align: center;
  }
</style>
