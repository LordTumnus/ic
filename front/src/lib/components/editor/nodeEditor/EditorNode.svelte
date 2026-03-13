<!--
  EditorNode.svelte — Custom Svelte Flow node with Industrial Flat styling.
  Mixer-channel aesthetic: secondary header with accent bottom border,
  recessed body, port rows with colored dots.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import Icon from '$lib/components/display/icon/Icon.svelte';
  import type { EditorNodeData } from '$lib/utils/node-editor-types';
  import { getPortColor } from '$lib/utils/node-editor-types';

  type EditorNodeType = Node<EditorNodeData, 'editorNode'>;

  let { data, selected, dragging }: NodeProps<EditorNodeType> = $props();

  const accentColor = $derived(data.color || 'var(--ic-primary)');
  const maxPorts = $derived(
    Math.max(data.inputs?.length ?? 0, data.outputs?.length ?? 0),
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-node"
  class:ic-ne-node--selected={selected}
  class:ic-ne-node--dragging={dragging}
  class:ic-ne-node--disabled={data.disabled}
>
  <div
    class="ic-ne-node__header"
    style:--accent={accentColor}
  >
    {#if data.icon}
      <span class="ic-ne-node__icon">
        <Icon source={data.icon} size={13} color={accentColor} />
      </span>
    {/if}
    <span class="ic-ne-node__label">{data.label || 'Node'}</span>
  </div>

  {#if maxPorts > 0}
    <div class="ic-ne-node__body">
      {#each { length: maxPorts } as _, i (i)}
        <div class="ic-ne-node__port-row">
          {#if data.inputs?.[i]}
            {@const port = data.inputs[i]}
            <div class="ic-ne-node__port ic-ne-node__port--input">
              <Handle
                type="target"
                position={Position.Left}
                id={port.name}
                style="left: 0px; top: 50%; transform: translate(-50%, -50%);"
              />
              <span
                class="ic-ne-node__port-dot"
                style:background-color={getPortColor(port)}
              ></span>
              <span class="ic-ne-node__port-label"
                >{port.label || port.name}</span
              >
            </div>
          {/if}

          {#if data.outputs?.[i]}
            {@const port = data.outputs[i]}
            <div class="ic-ne-node__port ic-ne-node__port--output">
              <span class="ic-ne-node__port-label"
                >{port.label || port.name}</span
              >
              <span
                class="ic-ne-node__port-dot"
                style:background-color={getPortColor(port)}
              ></span>
              <Handle
                type="source"
                position={Position.Right}
                id={port.name}
                style="right: 0px; top: 50%; transform: translate(50%, -50%);"
              />
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  /* ── Node container — white panel ────────────────────────── */
  .ic-ne-node {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    min-width: 140px;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    transition: border-color 0.15s ease;
    overflow: clip;
  }

  .ic-ne-node--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-node--dragging {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
  }

  .ic-ne-node--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* ── Header — muted surface with inset accent line ────────── */
  .ic-ne-node__header {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 5px 10px;
    background: var(--ic-muted);
    color: var(--ic-muted-foreground);
    font-weight: 600;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    position: relative;
  }

  .ic-ne-node__header::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 8px;
    right: 8px;
    height: 2px;
    border-radius: 1px;
    background-color: var(--accent);
  }

  .ic-ne-node__icon {
    display: inline-flex;
    flex-shrink: 0;
  }

  .ic-ne-node__label {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
  }

  /* ── Body — port rows in recessed area ─────────────────────── */
  .ic-ne-node__body {
    padding: 4px 0;
  }

  .ic-ne-node__port-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: relative;
    min-height: 22px;
    padding: 2px 0;
  }

  .ic-ne-node__port {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .ic-ne-node__port--output {
    margin-left: auto;
  }

  .ic-ne-node__port-dot {
    width: 8px;
    height: 8px;
    border-radius: 2px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    flex-shrink: 0;
  }

  .ic-ne-node__port-label {
    font-size: 11px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
  }

  /* ── Hide SF's default handle visuals — port-dot is the indicator ── */
  .ic-ne-node :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
