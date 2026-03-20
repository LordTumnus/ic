<!--
  GainNode.svelte — Classic amplifier triangle node.
  SVG right-pointing triangle with gain factor displayed inside.
  Dynamically mirrors input port type on output.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type GainData = {
    label: string;
    factor: number;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type GainNodeType = Node<GainData, 'ic.node.Gain'>;

  let { data, selected, dragging }: NodeProps<GainNodeType> = $props();

  let hovered = $state(false);

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
  </svg>

  <!-- Factor overlay (HTML for inline editing) -->
  <div class="ic-ne-gain__factor-overlay">
    <InlineEdit
      value={data.factor ?? 1}
      inputType="number"
      className="ic-ne-gain__factor"
      oncommit={(v) => data.onpropchange?.('factor', v)}
    />
  </div>

  <!-- Input handle: left midpoint -->
  {#if data.inputs?.[0]}
    <PortHandle type="target" position={Position.Left} id={data.inputs[0].name} variant="dot" />
  {/if}

  <!-- Output handle: right tip (chevron) -->
  {#if data.outputs?.[0]}
    <PortHandle type="source" position={Position.Right} id={data.outputs[0].name} variant="chevron" />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-gain__label">
    <InlineEdit
      value={data.label}
      className="ic-ne-gain__label-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>
{/if}

<style>
  .ic-ne-gain {
    position: relative;
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

  .ic-ne-gain__factor-overlay {
    position: absolute;
    top: 50%;
    left: 30%;
    transform: translate(-50%, -50%);
    pointer-events: auto;
  }

  .ic-ne-gain__factor-overlay :global(.ic-ne-gain__factor) {
    font-family: monospace;
    font-size: 13px;
    font-weight: 700;
    color: var(--ic-foreground);
  }

  .ic-ne-gain__label {
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
    margin-top: 4px;
  }

</style>
