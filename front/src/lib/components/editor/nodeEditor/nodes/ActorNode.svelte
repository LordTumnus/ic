<!--
  ActorNode.svelte — UML stick figure (actor).
  SVG stick figure with label below.
  Input port on left at body center, output port on right at body center.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type ActorData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type ActorNodeType = Node<ActorData, 'ic.node.Actor'>;

  let { data, selected, dragging }: NodeProps<ActorNodeType> = $props();

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
  class="ic-ne-actor"
  class:ic-ne-actor--hovered={hovered && !selected && !dragging}
  class:ic-ne-actor--selected={selected}
  class:ic-ne-actor--dragging={dragging}
  class:ic-ne-actor--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-actor__svg" viewBox="0 0 40 70" xmlns="http://www.w3.org/2000/svg">
    <!-- Head -->
    <circle cx="20" cy="10" r="8" fill={fill} {stroke} stroke-width="2" />
    <!-- Body -->
    <line x1="20" y1="18" x2="20" y2="42" {stroke} stroke-width="2" stroke-linecap="round" />
    <!-- Arms -->
    <line x1="4" y1="30" x2="36" y2="30" {stroke} stroke-width="2" stroke-linecap="round" />
    <!-- Left leg -->
    <line x1="20" y1="42" x2="6" y2="62" {stroke} stroke-width="2" stroke-linecap="round" />
    <!-- Right leg -->
    <line x1="20" y1="42" x2="34" y2="62" {stroke} stroke-width="2" stroke-linecap="round" />
  </svg>

  <!-- Input handle: left at body center (~y=30) -->
  {#if data.inputs?.[0]}
    <PortHandle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
      variant="dot"
      style="top: 30px; transform: translateY(-50%);"
    />
  {/if}

  <!-- Output handle: right at body center (~y=30) -->
  {#if data.outputs?.[0]}
    <PortHandle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
      variant="dot"
      style="top: 30px; transform: translateY(-50%);"
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-actor__label">
    <InlineEdit
      value={data.label}
      className="ic-ne-actor__label-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>
{/if}

<style>
  .ic-ne-actor {
    position: relative;
    width: 40px;
    height: 70px;
    transition: filter 0.15s ease;
  }

  .ic-ne-actor--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-actor--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-actor--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-actor--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-actor__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-actor__label {
    position: absolute;
    top: 100%;
    left: 50%;
    transform: translateX(-50%);
    margin-top: 4px;
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
  }
</style>
