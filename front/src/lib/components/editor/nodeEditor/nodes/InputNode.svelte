<!--
  InputNode.svelte — Pipeline entry terminal with double chevron >> shape.
  Each chevron is a proper 2D polygon (closed shape with area, outline, and interior).
  Output port on the right. Label displayed below the node (Simulink-style).
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type InputData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type InputNodeType = Node<InputData, 'ic.node.Input'>;

  let { data, selected, dragging }: NodeProps<InputNodeType> = $props();

  let hovered = $state(false);

  const fill = $derived(data.backgroundColor || 'var(--ic-muted)');
  const stroke = $derived(
    selected
      ? 'var(--ic-primary)'
      : data.outlineColor || 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-input"
  class:ic-ne-input--hovered={hovered && !selected && !dragging}
  class:ic-ne-input--selected={selected}
  class:ic-ne-input--dragging={dragging}
  class:ic-ne-input--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg
    class="ic-ne-input__shape"
    viewBox="0 0 44 36"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- First chevron: thick bracket with perpendicular back cuts -->
    <polygon
      points="4,1 20,18 4,35 0,32 13,18 0,4"
      fill={fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Second chevron -->
    <polygon
      points="24,1 40,18 24,35 20,32 33,18 20,4"
      fill={fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
  </svg>

  <!-- Output handle at right tip -->
  {#if data.outputs?.[0]}
    <PortHandle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
      variant="dot"
    />
  {/if}

  {#if data.label}
    <div class="ic-ne-input__label">
      <InlineEdit value={data.label} className="ic-ne-input__label-edit" oncommit={(v) => data.onpropchange?.('label', v)} />
    </div>
  {/if}
</div>

<style>
  .ic-ne-input {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    transition: filter 0.15s ease;
  }

  .ic-ne-input--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-input--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-input--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-input__shape {
    width: 44px;
    height: 36px;
    display: block;
  }

  .ic-ne-input__label {
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
