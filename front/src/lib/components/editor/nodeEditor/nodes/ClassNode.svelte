<!--
  ClassNode.svelte — UML class box with header and fields.
  HTML-based vertically stacked box: dark header + light body with monospace fields.
  Input port on left, output port on right.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type ClassData = {
    label: string;
    fields: string[];
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type ClassNodeType = Node<ClassData, 'ic.node.Class'>;

  let { data, selected, dragging }: NodeProps<ClassNodeType> = $props();

  let hovered = $state(false);

  const borderColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : data.outlineColor || 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-class"
  class:ic-ne-class--hovered={hovered && !selected && !dragging}
  class:ic-ne-class--selected={selected}
  class:ic-ne-class--dragging={dragging}
  class:ic-ne-class--disabled={data.disabled}
  style:border-color={borderColor}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <div class="ic-ne-class__header">
    <InlineEdit
      value={data.label}
      className="ic-ne-class__header-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>
  <div class="ic-ne-class__body">
    {#each data.fields ?? [] as field}
      <div class="ic-ne-class__field">{field}</div>
    {/each}
  </div>

  <!-- Input handle: left vertically centered -->
  {#if data.inputs?.[0]}
    <PortHandle type="target" position={Position.Left} id={data.inputs[0].name} variant="dot" />
  {/if}

  <!-- Output handle: right vertically centered -->
  {#if data.outputs?.[0]}
    <PortHandle type="source" position={Position.Right} id={data.outputs[0].name} variant="dot" />
  {/if}
</div>

<style>
  .ic-ne-class {
    position: relative;
    min-width: 120px;
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    overflow: clip;
    font-family: var(--ic-font-family);
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-class--hovered {
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-class--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-class--dragging {
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.25);
  }

  .ic-ne-class--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-class__header {
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    padding: 4px 8px;
    font-size: 11px;
    font-weight: 600;
    text-align: center;
  }

  .ic-ne-class__header :global(.ic-ne-class__header-edit) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-secondary-foreground);
  }

  .ic-ne-class__body {
    background-color: var(--ic-muted);
    padding: 4px 8px;
  }

  .ic-ne-class__field {
    font-family: monospace;
    font-size: 10px;
    color: var(--ic-foreground);
    line-height: 1.6;
    white-space: nowrap;
  }
</style>
