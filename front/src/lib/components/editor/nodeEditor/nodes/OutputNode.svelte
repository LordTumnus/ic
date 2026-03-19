<!--
  OutputNode.svelte — Pipeline exit terminal with double chevron << shape.
  Each chevron is a proper 2D polygon (closed shape with area, outline, and interior).
  Input port on the left. Label displayed below the node (Simulink-style).
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';

  type OutputData = {
    label: string;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
  };

  type OutputNodeType = Node<OutputData, 'ic.node.Output'>;

  let { data, selected, dragging }: NodeProps<OutputNodeType> = $props();

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
  class="ic-ne-output"
  class:ic-ne-output--hovered={hovered && !selected && !dragging}
  class:ic-ne-output--selected={selected}
  class:ic-ne-output--dragging={dragging}
  class:ic-ne-output--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg
    class="ic-ne-output__shape"
    viewBox="0 0 44 36"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- First chevron (mirrored): thick bracket with perpendicular back cuts -->
    <polygon
      points="40,1 24,18 40,35 44,32 31,18 44,4"
      fill={fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Second chevron (mirrored) -->
    <polygon
      points="20,1 4,18 20,35 24,32 11,18 24,4"
      fill={fill}
      {stroke}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
  </svg>

  <!-- Input handle at left tip -->
  {#if data.inputs?.[0]}
    <Handle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
    />
  {/if}

  {#if data.label}
    <div class="ic-ne-output__label">{data.label}</div>
  {/if}
</div>

<style>
  .ic-ne-output {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    transition: filter 0.15s ease;
  }

  .ic-ne-output--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-output--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-output--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-output__shape {
    width: 44px;
    height: 36px;
    display: block;
  }

  .ic-ne-output__label {
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
    pointer-events: none;
    user-select: none;
  }

  /* Hide SF's default handle visuals */
  .ic-ne-output :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
