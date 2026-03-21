<!--
  IcNode.svelte — Container node that renders arbitrary IC components.
  Draggable header + interactive content body with nodrag isolation.
  Resizable, with input/output ports on left/right edges.
-->
<script lang="ts">
  import {
    Position,
    NodeResizer,
    type NodeProps,
    type Node,
  } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import type { ChildEntry } from '$lib/types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type IcNodeData = {
    label: string;
    width: number;
    height: number;
    backgroundColor: string;
    outlineColor: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    contentEntries: ChildEntry[];
    onNodeResize?: (nodeId: string, width: number, height: number) => void;
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type IcNodeType = Node<IcNodeData, 'ic.node.IcNode'>;

  let { id, data, selected, dragging }: NodeProps<IcNodeType> = $props();

  let hovered = $state(false);

  const bgColor = $derived(data.backgroundColor || 'var(--ic-muted)');
  const borderColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : data.outlineColor || 'var(--ic-border)',
  );

  /** Compute vertical position (%) for the i-th port out of count. */
  function portTopPct(i: number, count: number): number {
    const headerH = 24;
    const h = data.height;
    const bodyH = h - headerH;
    if (bodyH <= 10) return 50;
    const spacing = bodyH / (count + 1);
    const top = headerH + spacing * (i + 1);
    return (top / h) * 100;
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-icnode"
  class:ic-ne-icnode--hovered={hovered && !selected && !dragging}
  class:ic-ne-icnode--selected={selected}
  class:ic-ne-icnode--dragging={dragging}
  class:ic-ne-icnode--disabled={data.disabled}
  style:border-color={borderColor}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <NodeResizer
    minWidth={120}
    minHeight={80}
    isVisible={selected}
    lineClass="ic-ne-icnode__resize-line"
    handleClass="ic-ne-icnode__resize-handle"
    onResizeEnd={(_e, params) => data.onNodeResize?.(id, params.width, params.height)}
  />

  <!-- Header (draggable) -->
  <div class="ic-ne-icnode__header">
    <InlineEdit
      value={data.label}
      className="ic-ne-icnode__label-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />
  </div>

  <!-- Content body: stop pointer propagation so SvelteFlow doesn't intercept IC interactions -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ic-ne-icnode__body nodrag nopan nowheel"
    style:background-color={bgColor}
    onpointerdown={(e) => e.stopPropagation()}
    onmousedown={(e) => e.stopPropagation()}
  >
    {#each data.contentEntries ?? [] as entry (entry.id)}
      {@render entry.snippet()}
    {/each}
  </div>

  <!-- Input handles: left edge -->
  {#each data.inputs ?? [] as port, i (port.name)}
    <PortHandle
      type="target"
      position={Position.Left}
      id={port.name}
      variant="dot"
      style="top: {portTopPct(i, data.inputs.length)}%"
    />
  {/each}

  <!-- Output handles: right edge -->
  {#each data.outputs ?? [] as port, i (port.name)}
    <PortHandle
      type="source"
      position={Position.Right}
      id={port.name}
      variant="dot"
      style="top: {portTopPct(i, data.outputs.length)}%"
    />
  {/each}
</div>

<style>
  .ic-ne-icnode {
    position: relative;
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    font-family: var(--ic-font-family);
    overflow: clip;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-icnode--hovered {
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-icnode--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-icnode--dragging {
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.25);
  }

  .ic-ne-icnode--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* ── Header ─────────────────────────────── */
  .ic-ne-icnode__header {
    display: flex;
    align-items: center;
    height: 24px;
    min-height: 24px;
    padding: 0 8px;
    background: var(--ic-secondary);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--ic-secondary-foreground);
    user-select: none;
    cursor: grab;
  }

  .ic-ne-icnode__header :global(.ic-ne-icnode__label-edit) {
    font-family: var(--ic-font-family);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--ic-secondary-foreground);
  }

  /* ── Body (IC content area) ─────────────── */
  .ic-ne-icnode__body {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 6px;
    overflow: clip;
  }

  /* ── Resize: hide edge lines ────────────── */
  .ic-ne-icnode :global(.ic-ne-icnode__resize-line) {
    border-color: transparent;
  }

  /* ── Resize: L-bracket corner handles ───── */
  .ic-ne-icnode :global(.ic-ne-icnode__resize-handle) {
    width: 8px;
    height: 8px;
    background: transparent;
    border: 2px solid var(--ic-muted-foreground);
    border-radius: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease, border-color 0.15s ease;
  }

  .ic-ne-icnode :global(.ic-ne-icnode__resize-handle:hover) {
    border-color: var(--ic-primary);
    opacity: 1;
  }

  .ic-ne-icnode :global(.ic-ne-icnode__resize-handle.top.left) {
    border-right: none; border-bottom: none;
  }
  .ic-ne-icnode :global(.ic-ne-icnode__resize-handle.top.right) {
    border-left: none; border-bottom: none;
  }
  .ic-ne-icnode :global(.ic-ne-icnode__resize-handle.bottom.left) {
    border-right: none; border-top: none;
  }
  .ic-ne-icnode :global(.ic-ne-icnode__resize-handle.bottom.right) {
    border-left: none; border-top: none;
  }

  /* ── Hide SF's default handle visuals ──── */
  .ic-ne-icnode :global(.svelte-flow__handle) {
    width: 14px;
    height: 14px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
