<!--
  LoggerNode.svelte — Scrolling terminal/console sink node.
  Displays log entries pushed from MATLAB via the .log() method.
  Auto-scrolls to bottom on new entries.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type LoggerData = {
    label: string;
    maxLines: number;
    logEntries: string[];
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type LoggerNodeType = Node<LoggerData, 'ic.node.Logger'>;

  let { data, selected, dragging }: NodeProps<LoggerNodeType> = $props();

  let hovered = $state(false);
  let terminalEl: HTMLDivElement | undefined = $state();

  // Auto-scroll to bottom when entries change
  $effect(() => {
    const entries = data.logEntries;
    if (terminalEl && entries?.length) {
      // Use microtask to ensure DOM is updated
      queueMicrotask(() => {
        if (terminalEl) terminalEl.scrollTop = terminalEl.scrollHeight;
      });
    }
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-logger"
  class:ic-ne-logger--hovered={hovered && !selected && !dragging}
  class:ic-ne-logger--selected={selected}
  class:ic-ne-logger--dragging={dragging}
  class:ic-ne-logger--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <!-- Header -->
  <div class="ic-ne-logger__header">
    <span class="ic-ne-logger__badge">&gt;_</span>
    <span class="ic-ne-logger__title">
      <InlineEdit value={data.label || 'Logger'} className="ic-ne-logger__title-edit" oncommit={(v) => data.onpropchange?.('label', v)} />
    </span>
  </div>

  <!-- Terminal area -->
  <div class="ic-ne-logger__terminal" bind:this={terminalEl}>
    {#if data.logEntries?.length}
      {#each data.logEntries as line, i (i)}
        <div class="ic-ne-logger__line">{line}</div>
      {/each}
    {:else}
      <div class="ic-ne-logger__empty">No log entries</div>
    {/if}
  </div>

  <!-- Input handle on left -->
  {#if data.inputs?.[0]}
    <PortHandle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
      variant="dot"
    />
  {/if}
</div>

<style>
  .ic-ne-logger {
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    width: 220px;
    color: var(--ic-foreground);
    font-family: var(--ic-font-family);
    font-size: 12px;
    overflow: clip;
    transition:
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .ic-ne-logger--hovered {
    border-color: var(--ic-muted-foreground);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .ic-ne-logger--selected {
    border-color: var(--ic-primary);
  }

  .ic-ne-logger--dragging {
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.28);
  }

  .ic-ne-logger--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  /* Header */
  .ic-ne-logger__header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    background: var(--ic-muted);
    font-weight: 600;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--ic-muted-foreground);
  }

  .ic-ne-logger__badge {
    font-family: monospace;
    font-size: 12px;
    font-weight: 700;
    opacity: 0.6;
    flex-shrink: 0;
  }

  .ic-ne-logger__title {
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
  }

  /* Terminal */
  .ic-ne-logger__terminal {
    height: 120px;
    overflow-y: auto;
    overflow-x: clip;
    padding: 4px 8px;
    background: var(--ic-muted);
    margin: 4px;
    border-radius: 2px;
    border: 1px solid rgba(128, 128, 128, 0.15);
  }

  .ic-ne-logger__line {
    font-family: monospace;
    font-size: 10px;
    line-height: 1.5;
    color: var(--ic-primary);
    white-space: pre-wrap;
    word-break: break-all;
  }

  .ic-ne-logger__empty {
    font-family: monospace;
    font-size: 10px;
    color: var(--ic-muted-foreground);
    opacity: 0.5;
    text-align: center;
    padding-top: 40px;
  }

  /* Scrollbar styling for terminal */
  .ic-ne-logger__terminal::-webkit-scrollbar {
    width: 4px;
  }

  .ic-ne-logger__terminal::-webkit-scrollbar-track {
    background: transparent;
  }

  .ic-ne-logger__terminal::-webkit-scrollbar-thumb {
    background: rgba(128, 128, 128, 0.3);
    border-radius: 2px;
  }
</style>
