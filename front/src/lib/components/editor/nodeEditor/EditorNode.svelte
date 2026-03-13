<!--
  EditorNode.svelte — Custom Svelte Flow node.
  Session 1: label + handles. Industrial Flat styling in Session 2.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';

  type EditorNodeData = {
    label: string;
    inputs: PortDef[];
    outputs: PortDef[];
    disabled: boolean;
  };

  type EditorNodeType = Node<EditorNodeData, 'editorNode'>;

  let { data }: NodeProps<EditorNodeType> = $props();
</script>

<div class="ic-ne-node" class:ic-ne-node--disabled={data.disabled}>
  <div class="ic-ne-node__label">{data.label || 'Node'}</div>

  {#each data.inputs ?? [] as port (port.name)}
    <Handle type="target" position={Position.Left} id={port.name} />
  {/each}

  {#each data.outputs ?? [] as port (port.name)}
    <Handle type="source" position={Position.Right} id={port.name} />
  {/each}
</div>

<style>
  .ic-ne-node {
    background: var(--ic-surface, #fff);
    border: 1px solid var(--ic-border, #ccc);
    border-radius: 3px;
    padding: 8px 12px;
    min-width: 80px;
    color: var(--ic-foreground, #1a1a1a);
    font-size: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-node--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-node__label {
    text-align: center;
    font-weight: 500;
    white-space: nowrap;
  }
</style>
