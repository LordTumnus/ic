<!--
  NodeEditor.svelte — Bridge between IC childEntries and Svelte Flow.

  IC children (Node/Edge) live in childEntries["nodes"] and ["edges"].
  A $derived extracts plain data from the reactive proxies, then a
  follow-up $effect merges it into the Svelte Flow arrays, preserving
  SF's internal state (measured dimensions, selection, etc.).
-->
<script lang="ts">
  import { untrack } from 'svelte';
  import {
    SvelteFlow,
    type Node as FlowNode,
    type Edge as FlowEdge,
  } from '@xyflow/svelte';
  import '@xyflow/svelte/dist/base.css';

  import type { ChildEntries } from '$lib/types';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import EditorNode from './EditorNode.svelte';

  let {
    height = $bindable('100%'),
    gridSize = $bindable(20),
    childEntries = {} as ChildEntries,
  }: {
    height?: string;
    gridSize?: number;
    childEntries?: ChildEntries;
  } = $props();

  const nodeTypes = { editorNode: EditorNode } as Record<string, any>;

  let flowNodes: FlowNode[] = $state.raw([]);
  let flowEdges: FlowEdge[] = $state.raw([]);

  /** MATLAB jsonencodes a single-element struct array as an object — normalize. */
  function asArray<T>(v: unknown): T[] {
    if (Array.isArray(v)) return v;
    if (v != null && typeof v === 'object') return [v as T];
    return [];
  }

  // -- Nodes: $derived reads IC props, $effect merges into SF state ----------

  const icNodes = $derived(
    (childEntries['nodes'] ?? []).map((c) => {
      const p = c.props;
      return {
        id: c.id,
        label: (p.label as string) ?? '',
        position: (p.position as number[]) ?? [0, 0],
        inputs: asArray<PortDef>(p.inputs),
        outputs: asArray<PortDef>(p.outputs),
        disabled: (p.disabled as boolean) ?? false,
      };
    }),
  );

  $effect(() => {
    const data = icNodes;
    const existing = new Map(untrack(() => flowNodes).map((n) => [n.id, n]));

    flowNodes = data.map((nd) => {
      const prev = existing.get(nd.id);
      const position = { x: nd.position[0], y: nd.position[1] };
      const nodeData = {
        label: nd.label,
        inputs: nd.inputs,
        outputs: nd.outputs,
        disabled: nd.disabled,
      };
      return prev
        ? { ...prev, position, data: nodeData }
        : { id: nd.id, type: 'editorNode', position, data: nodeData };
    });
  });

  // -- Edges: straight mapping (no SF internal state to preserve) ------------

  const icEdges = $derived(
    (childEntries['edges'] ?? []).map((c) => {
      const p = c.props;
      return {
        id: c.id,
        source: p.sourceNode as string,
        target: p.targetNode as string,
        sourceHandle: (p.sourcePort as string) || undefined,
        targetHandle: (p.targetPort as string) || undefined,
        label: (p.label as string) || undefined,
        animated: (p.animated as boolean) ?? false,
      } satisfies FlowEdge;
    }),
  );

  $effect(() => {
    flowEdges = icEdges;
  });

  // -- Position writeback: SF drag → IC child → MATLAB -----------------------

  function handleNodeDragStop({ targetNode }: { targetNode: FlowNode | null }) {
    if (!targetNode) return;
    const child = (childEntries['nodes'] ?? []).find(
      (c) => c.id === targetNode.id,
    );
    if (child) {
      child.props.position = [targetNode.position.x, targetNode.position.y];
    }
  }
</script>

<div class="ic-ne" style:height>
  <SvelteFlow
    bind:nodes={flowNodes}
    bind:edges={flowEdges}
    {nodeTypes}
    fitView
    onnodedragstop={handleNodeDragStop}
  />
</div>

<style>
  .ic-ne {
    width: 100%;
    overflow: clip;
  }
</style>
