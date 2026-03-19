<!--
  ConstantNode.svelte — Compact pill displaying a value (number or string) with one output.
  No port labels. Optional label below (Simulink-style).
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';

  type ConstantData = {
    label: string;
    value: number;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    outputs: PortDef[];
  };

  type ConstantNodeType = Node<ConstantData, 'ic.node.Constant'>;

  let { data, selected, dragging }: NodeProps<ConstantNodeType> = $props();

  let hovered = $state(false);

  const bgColor = $derived(data.backgroundColor || 'var(--ic-muted)');
  const borderColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : data.outlineColor || 'var(--ic-border)',
  );

  const displayValue = $derived(String(data.value ?? 0));
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-const"
  class:ic-ne-const--hovered={hovered && !selected && !dragging}
  class:ic-ne-const--selected={selected}
  class:ic-ne-const--dragging={dragging}
  class:ic-ne-const--disabled={data.disabled}
  style:background-color={bgColor}
  style:border-color={borderColor}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <span class="ic-ne-const__value">{displayValue}</span>

  <!-- Output handle on right -->
  {#if data.outputs?.[0]}
    <Handle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-const__label">{data.label}</div>
{/if}

<style>
  .ic-ne-const {
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 36px;
    height: 28px;
    padding: 0 12px;
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    font-family: var(--ic-font-family);
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-const--hovered {
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-const--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-const--dragging {
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.25);
  }

  .ic-ne-const--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-const__value {
    font-family: monospace;
    font-size: 13px;
    font-weight: 600;
    color: var(--ic-foreground);
    white-space: nowrap;
    user-select: none;
  }

  .ic-ne-const__label {
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
    margin-top: 4px;
    pointer-events: none;
    user-select: none;
  }

  /* Hide SF's default handle visuals */
  .ic-ne-const :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
