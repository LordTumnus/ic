<!--
  TransformNode.svelte — f(x) math block with N paired input/output channels.
  Displays header with label, expression badge, and paired port rows.
  Resizable, inline-editable label and expression.
-->
<script lang="ts">
  import { Position, NodeResizer, type NodeProps, type Node } from '@xyflow/svelte';
  import Icon from '$lib/components/display/icon/Icon.svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type TransformData = {
    label: string;
    expression: string;
    color: string;
    icon: any;
    disabled: boolean;
    locked: boolean;
    inputNumber: number;
    inputs: PortDef[];
    outputs: PortDef[];
    onNodeResize?: (nodeId: string, width: number, height: number) => void;
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type TransformNodeType = Node<TransformData, 'ic.node.Transform'>;

  let { id, data, selected, dragging }: NodeProps<TransformNodeType> = $props();

  let hovered = $state(false);

  const accentColor = $derived(data.color || 'var(--ic-primary)');
  const maxPorts = $derived(
    Math.max(data.inputs?.length ?? 0, data.outputs?.length ?? 0),
  );
  const minH = $derived(60 + maxPorts * 24);
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-node"
  class:ic-ne-node--hovered={hovered && !selected && !dragging}
  class:ic-ne-node--selected={selected}
  class:ic-ne-node--dragging={dragging}
  class:ic-ne-node--disabled={data.disabled}
  style:min-height="{minH}px"
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <NodeResizer
    minWidth={140}
    minHeight={minH}
    isVisible={selected}
    lineClass="ic-ne-node__resize-line"
    handleClass="ic-ne-node__resize-handle"
    onResizeEnd={(_e, params) => data.onNodeResize?.(id, params.width, params.height)}
  />

  <div class="ic-ne-node__header" style:--accent={accentColor}>
    {#if data.icon}
      <span class="ic-ne-node__icon">
        <Icon source={data.icon} size={13} color={accentColor} />
      </span>
    {/if}
    <InlineEdit
      value={data.label || 'Transform'}
      className="ic-ne-node__label-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>

  <div class="ic-ne-node__body">
    <div class="ic-ne-node__expression">
      <span class="ic-ne-node__expression-badge">f(x)</span>
      <InlineEdit
        value={data.expression || ''}
        className="ic-ne-node__expression-edit"
        placeholder="e.g. 2*x + 1"
        oncommit={(v) => data.onpropchange?.('expression', v)}
      />
    </div>

    {#if maxPorts > 0}
      <div class="ic-ne-node__ports">
        {#each { length: maxPorts } as _, i (i)}
          <div class="ic-ne-node__port-row">
            {#if data.inputs?.[i]}
              {@const port = data.inputs[i]}
              <PortHandle
                type="target"
                position={Position.Left}
                id={port.name}
                variant="dot"
              />
              <span class="ic-ne-node__port-label ic-ne-node__port-label--left"
                >{port.label || port.name}</span
              >
            {/if}

            {#if data.outputs?.[i]}
              {@const port = data.outputs[i]}
              <span class="ic-ne-node__port-label ic-ne-node__port-label--right"
                >{port.label || port.name}</span
              >
              <PortHandle
                type="source"
                position={Position.Right}
                id={port.name}
                variant="dot"
              />
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  /* ── Node container ────────────────────────── */
  .ic-ne-node {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    min-width: 140px;
    height: 100%;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease,
      transform 0.15s ease;
  }

  .ic-ne-node--hovered {
    border-color: var(--ic-muted-foreground);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-node--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-node--dragging {
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.28);
    transform: scale(1.01);
  }

  .ic-ne-node--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* ── Header ────────────────────────────────── */
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

  .ic-ne-node :global(.ic-ne-node__label-edit) {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
    font-weight: 600;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--ic-muted-foreground);
  }

  /* ── Body ───────────────────────────────────── */
  .ic-ne-node__body {
    padding: 4px 0;
  }

  /* ── Expression display ─────────────────────── */
  .ic-ne-node__expression {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 3px 8px;
    margin: 2px 4px;
    background: var(--ic-muted);
    border-radius: 2px;
  }

  .ic-ne-node__expression-badge {
    font-family: monospace;
    font-size: 10px;
    font-weight: 700;
    color: var(--ic-muted-foreground);
    opacity: 0.6;
    flex-shrink: 0;
  }

  .ic-ne-node :global(.ic-ne-node__expression-edit) {
    font-family: monospace;
    font-size: 11px;
    color: var(--ic-foreground);
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
    flex: 1;
  }

  /* ── Ports ──────────────────────────────────── */
  .ic-ne-node__ports {
    padding: 2px 0;
  }

  .ic-ne-node__port-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: relative;
    min-height: 22px;
    padding: 2px 8px;
    transition: background-color 0.1s ease;
  }

  .ic-ne-node__port-row:hover {
    background-color: rgba(128, 128, 128, 0.08);
  }

  .ic-ne-node__port-label {
    font-size: 11px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
  }

  .ic-ne-node__port-label--right {
    margin-left: auto;
  }

  /* ── Resize handles ────────────────────────── */
  .ic-ne-node :global(.ic-ne-node__resize-line) {
    border-color: transparent;
  }

  .ic-ne-node :global(.ic-ne-node__resize-handle) {
    width: 6px;
    height: 6px;
    background: transparent;
    border: 2px solid var(--ic-muted-foreground);
    border-radius: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, border-color 0.15s ease;
  }

  .ic-ne-node :global(.ic-ne-node__resize-handle:hover) {
    border-color: var(--ic-primary);
    opacity: 1;
  }

  .ic-ne-node :global(.ic-ne-node__resize-handle.top.left) {
    border-right: none; border-bottom: none;
  }
  .ic-ne-node :global(.ic-ne-node__resize-handle.top.right) {
    border-left: none; border-bottom: none;
  }
  .ic-ne-node :global(.ic-ne-node__resize-handle.bottom.left) {
    border-right: none; border-top: none;
  }
  .ic-ne-node :global(.ic-ne-node__resize-handle.bottom.right) {
    border-left: none; border-top: none;
  }
</style>
