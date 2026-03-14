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
    Background,
    BackgroundVariant,
    type Node as FlowNode,
    type Edge as FlowEdge,
    type Connection,
  } from '@xyflow/svelte';
  import '@xyflow/svelte/dist/base.css';

  import type { ChildEntries, RequestFn } from '$lib/types';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import EditorNode from './EditorNode.svelte';

  let {
    height = $bindable('100%'),
    gridSize = $bindable(20),
    childEntries = {} as ChildEntries,
    request,
    // Events
    nodeMoved,
  }: {
    height?: string;
    gridSize?: number;
    childEntries?: ChildEntries;
    request?: RequestFn;
    nodeMoved?: (data?: unknown) => void;
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
        color: (p.color as string) ?? '',
        icon: p.icon ?? null,
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
        color: nd.color,
        icon: nd.icon,
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

  // -- Connection: optimistic temp edge + request → MATLAB creates real edge ---

  function handleBeforeConnect(connection: Connection): Connection {
    // Fire-and-forget: MATLAB creates the real Edge child via @insert.
    request?.('connect', {
      source: connection.source,
      sourcePort: connection.sourceHandle ?? '',
      target: connection.target,
      targetPort: connection.targetHandle ?? '',
    });
    // Return connection → SF adds temp edge instantly (no flash).
    // When MATLAB's @insert arrives, $effect replaces flowEdges with icEdges,
    // swapping the temp edge for the real IC-owned edge.
    return connection;
  }

  // -- Deletion: prevent SF deletion, request MATLAB to handle ----------------

  async function handleBeforeDelete({
    nodes,
    edges,
  }: {
    nodes: FlowNode[];
    edges: FlowEdge[];
  }): Promise<false> {
    const deletedNodeIds = new Set(nodes.map((n) => n.id));

    if (nodes.length > 0) {
      request?.('deleteNodes', { nodeIds: nodes.map((n) => n.id) });
    }

    // Only request disconnect for edges NOT connected to deleted nodes
    // (those will be cascade-deleted by MATLAB's removeNode).
    const standaloneEdges = edges.filter(
      (e) => !deletedNodeIds.has(e.source) && !deletedNodeIds.has(e.target),
    );
    for (const edge of standaloneEdges) {
      request?.('disconnect', { edgeId: edge.id });
    }

    return false;
  }

  // -- Position writeback + NodeMoved event -----------------------------------

  function handleNodeDragStop({ targetNode }: { targetNode: FlowNode | null }) {
    if (!targetNode) return;
    const child = (childEntries['nodes'] ?? []).find(
      (c) => c.id === targetNode.id,
    );
    if (child) {
      const pos = [targetNode.position.x, targetNode.position.y];
      child.props.position = pos;
      nodeMoved?.({ value: { nodeId: targetNode.id, position: pos } });
    }
  }
</script>

<div class="ic-ne" style:height>
  <SvelteFlow
    bind:nodes={flowNodes}
    bind:edges={flowEdges}
    {nodeTypes}
    fitView
    deleteKey={['Backspace', 'Delete']}
    onbeforeconnect={handleBeforeConnect}
    onbeforedelete={handleBeforeDelete}
    onnodedragstop={handleNodeDragStop}
  >
    <Background variant={BackgroundVariant.Dots} gap={gridSize} size={1} />
  </SvelteFlow>
</div>

<style>
  .ic-ne {
    width: 100%;
    overflow: clip;

    /* Override Svelte Flow theme to match Industrial Flat */
    --xy-background-color-default: var(--ic-background);
    --xy-background-pattern-color-default: var(--ic-border);
    --xy-edge-stroke-default: var(--ic-muted-foreground);
    --xy-edge-stroke-selected-default: var(--ic-primary);
    --xy-node-border-default: none;
    --xy-node-boxshadow-hover-default: none;
    --xy-node-boxshadow-selected-default: none;
    --xy-handle-background-color-default: transparent;
    --xy-handle-border-color-default: transparent;
  }
</style>
