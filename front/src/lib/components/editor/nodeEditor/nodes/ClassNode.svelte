<!--
  ClassNode.svelte — UML class diagram box with Properties, Methods, Events sections.
  Header has class name with left/right ports for subclass linking and a top port
  for superclass inheritance. Each member row has invisible left/right port handles.
  Sections are separated by horizontal lines.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type ClassData = {
    label: string;
    propertyList: string[];
    methodList: string[];
    eventList: string[];
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

  // Find header ports by name
  const inheritPort = $derived(data.inputs?.find((p) => p.name === 'inherit'));
  const subLeftPort = $derived(data.outputs?.find((p) => p.name === 'sub-left'));
  const subRightPort = $derived(data.outputs?.find((p) => p.name === 'sub-right'));

  // Check which sections have content
  const hasProperties = $derived((data.propertyList?.length ?? 0) > 0);
  const hasMethods = $derived((data.methodList?.length ?? 0) > 0);
  const hasEvents = $derived((data.eventList?.length ?? 0) > 0);
  const hasAnyMembers = $derived(hasProperties || hasMethods || hasEvents);
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
  <!-- Top port: inherit (superclass link) -->
  {#if inheritPort}
    <PortHandle
      type="target"
      position={Position.Top}
      id={inheritPort.name}
      variant="dot"
    />
  {/if}

  <!-- Header with class name + left/right subclass ports -->
  <div class="ic-ne-class__header">
    {#if subLeftPort}
      <PortHandle
        type="source"
        position={Position.Left}
        id={subLeftPort.name}
        variant="dot"
        style="top: 50%; transform: translateY(-50%);"
      />
    {/if}

    <InlineEdit
      value={data.label}
      className="ic-ne-class__header-edit"
      oncommit={(v) => data.onpropchange?.('label', v)}
    />

    {#if subRightPort}
      <PortHandle
        type="source"
        position={Position.Right}
        id={subRightPort.name}
        variant="dot"
        style="top: 50%; transform: translateY(-50%);"
      />
    {/if}
  </div>

  <!-- Body: sectioned members -->
  {#if hasAnyMembers}
    <div class="ic-ne-class__body">
      <!-- Properties section -->
      {#if hasProperties}
        <div class="ic-ne-class__section-label">Properties</div>
        {#each data.propertyList as prop, i}
          <div class="ic-ne-class__row">
            <PortHandle
              type="target"
              position={Position.Left}
              id={`prop-${i + 1}-in`}
              hidden
            />
            <span class="ic-ne-class__member">{prop}</span>
            <PortHandle
              type="source"
              position={Position.Right}
              id={`prop-${i + 1}-out`}
              hidden
            />
          </div>
        {/each}
      {/if}

      <!-- Methods section -->
      {#if hasMethods}
        {#if hasProperties}
          <div class="ic-ne-class__hline"></div>
        {/if}
        <div class="ic-ne-class__section-label">Methods</div>
        {#each data.methodList as method, i}
          <div class="ic-ne-class__row">
            <PortHandle
              type="target"
              position={Position.Left}
              id={`meth-${i + 1}-in`}
              hidden
            />
            <span class="ic-ne-class__member">{method}</span>
            <PortHandle
              type="source"
              position={Position.Right}
              id={`meth-${i + 1}-out`}
              hidden
            />
          </div>
        {/each}
      {/if}

      <!-- Events section -->
      {#if hasEvents}
        {#if hasProperties || hasMethods}
          <div class="ic-ne-class__hline"></div>
        {/if}
        <div class="ic-ne-class__section-label">Events</div>
        {#each data.eventList as evt, i}
          <div class="ic-ne-class__row">
            <PortHandle
              type="target"
              position={Position.Left}
              id={`evt-${i + 1}-in`}
              hidden
            />
            <span class="ic-ne-class__member">{evt}</span>
            <PortHandle
              type="source"
              position={Position.Right}
              id={`evt-${i + 1}-out`}
              hidden
            />
          </div>
        {/each}
      {/if}
    </div>
  {/if}
</div>

<style>
  .ic-ne-class {
    position: relative;
    min-width: 140px;
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    overflow: clip;
    font-family: var(--ic-font-family);
    background: var(--ic-background);
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

  /* ── Header ─────────────────────────────────── */
  .ic-ne-class__header {
    position: relative;
    background-color: var(--ic-secondary);
    color: var(--ic-secondary-foreground);
    padding: 5px 14px;
    font-size: 11px;
    font-weight: 600;
    text-align: center;
    border-bottom: 1px solid var(--ic-border);
  }

  .ic-ne-class__header :global(.ic-ne-class__header-edit) {
    font-family: var(--ic-font-family);
    font-size: 11px;
    font-weight: 600;
    color: var(--ic-secondary-foreground);
  }

  /* ── Body ───────────────────────────────────── */
  .ic-ne-class__body {
    padding: 2px 0;
  }

  /* ── Section label ──────────────────────────── */
  .ic-ne-class__section-label {
    padding: 3px 8px 1px;
    font-size: 9px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--ic-muted-foreground);
    opacity: 0.7;
  }

  /* ── Horizontal line between sections ───────── */
  .ic-ne-class__hline {
    height: 1px;
    background-color: var(--ic-border);
    margin: 2px 0;
  }

  /* ── Member row ─────────────────────────────── */
  .ic-ne-class__row {
    position: relative;
    display: flex;
    align-items: center;
    padding: 1px 8px;
    min-height: 18px;
    transition: background-color 0.1s ease;
  }

  .ic-ne-class__row:hover {
    background-color: rgba(128, 128, 128, 0.06);
  }

  .ic-ne-class__member {
    font-family: monospace;
    font-size: 10px;
    color: var(--ic-foreground);
    line-height: 1.5;
    white-space: nowrap;
  }
</style>
