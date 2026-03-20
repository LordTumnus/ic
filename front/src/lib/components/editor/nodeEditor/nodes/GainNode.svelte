<!--
  GainNode.svelte — Classic amplifier triangle node.
  SVG right-pointing triangle with gain factor displayed inside.
  Dynamically mirrors input port type on output.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';

  type GainData = {
    label: string;
    factor: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
  };

  type GainNodeType = Node<GainData, 'ic.node.Gain'>;

  let { data, selected, dragging }: NodeProps<GainNodeType> = $props();

  let hovered = $state(false);

  const displayFactor = $derived(() => {
    const f = data.factor ?? 1;
    // Format: "x2", "x0.5", "x-1"
    return 'x' + (Number.isInteger(f) ? f.toString() : f.toFixed(2).replace(/0+$/, '').replace(/\.$/, ''));
  });

  const strokeColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-gain"
  class:ic-ne-gain--hovered={hovered && !selected && !dragging}
  class:ic-ne-gain--selected={selected}
  class:ic-ne-gain--dragging={dragging}
  class:ic-ne-gain--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-gain__svg" viewBox="-1 -1 82 62" xmlns="http://www.w3.org/2000/svg">
    <!-- Triangle body -->
    <polygon
      points="0,0 80,30 0,60"
      fill="var(--ic-muted)"
      stroke={strokeColor}
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Factor text -->
    <text
      x="24"
      y="34"
      class="ic-ne-gain__factor"
      text-anchor="middle"
      dominant-baseline="middle"
    >{displayFactor()}</text>
  </svg>

  <!-- Input handle: left midpoint -->
  {#if data.inputs?.[0]}
    <Handle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
    />
  {/if}

  <!-- Output handle: right tip -->
  {#if data.outputs?.[0]}
    <Handle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-gain__label">{data.label}</div>
{/if}

<style>
  .ic-ne-gain {
    width: 80px;
    height: 60px;
    transition: filter 0.15s ease;
  }

  .ic-ne-gain--dragging {
    filter: drop-shadow(0 3px 6px rgba(0, 0, 0, 0.3));
  }

  .ic-ne-gain--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-gain__svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .ic-ne-gain__factor {
    font-family: monospace;
    font-size: 13px;
    font-weight: 700;
    fill: var(--ic-foreground);
    user-select: none;
    pointer-events: none;
  }

  .ic-ne-gain__label {
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
  .ic-ne-gain :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
