<!--
  NodeEditor.svelte — Bridge between IC childEntries and Svelte Flow.

  IC children (Node/Edge) live in childEntries["nodes"] and ["edges"].
  Ports are value-class arrays serialized as reactive props on each Node.
  The toolbar has built-in viewport controls (inside SvelteFlow Panel)
  and user-added IC components via childEntries["toolbar"] snippets.

  Edge lifecycle (optimistic):
    1. User drags connection → onbeforeconnect returns edge → SF shows it immediately
    2. onconnect fires → request sent to MATLAB
    3. MATLAB creates edge (type from source port's Type), responds with real edge ID
    4. reconcileEdges() swaps the SF temp edge for the MATLAB-sourced real edge

  Edge types:
    - StaticEdge: simple line with optional arrow markers
    - FlowEdge: animated particles traveling source → target
    - SignalEdge: waveform overlay with math expression evaluation
-->
<script lang="ts">
  import { untrack } from 'svelte';
  import {
    SvelteFlow,
    Background,
    BackgroundVariant,
    Panel,
    useSvelteFlow,
    type Node as FlowNode,
    type Edge as FlowEdge,
    type Connection,
  } from '@xyflow/svelte';
  import '@xyflow/svelte/dist/base.css';

  import type { ChildEntries, RequestFn } from '$lib/types';
  import { extractPorts } from '$lib/utils/node-editor-types';
  import { EDGE_TYPE_MAP } from '$lib/utils/edge-utils';

  // Node type components — one per concrete MATLAB class
  import TransformNode from './nodes/TransformNode.svelte';

  // Edge type components — one per concrete MATLAB edge class
  import StaticEdgeRenderer from './edges/StaticEdgeRenderer.svelte';
  import FlowEdgeRenderer from './edges/FlowEdgeRenderer.svelte';
  import SignalEdgeRenderer from './edges/SignalEdgeRenderer.svelte';

  let {
    height = $bindable('100%'),
    gridSize = $bindable(20),
    edgeGeometry = $bindable('bezier'),
    childEntries = {} as ChildEntries,
    request,
    // Events
    nodeMoved,
  }: {
    height?: string;
    gridSize?: number;
    edgeGeometry?: string;
    childEntries?: ChildEntries;
    request?: RequestFn;
    nodeMoved?: (data?: unknown) => void;
  } = $props();

  // -- Node type registry: MATLAB class name → Svelte Flow component ----------

  const nodeTypes = {
    'ic.node.Transform': TransformNode,
  } as Record<string, any>;

  // -- Edge type registry: SvelteFlow edge type key → Svelte component --------

  const edgeTypes = {
    static: StaticEdgeRenderer,
    flow: FlowEdgeRenderer,
    signal: SignalEdgeRenderer,
  } as Record<string, any>;

  // -- Svelte Flow state ------------------------------------------------------

  let flowNodes: FlowNode[] = $state.raw([]);
  let flowEdges: FlowEdge[] = $state([]);

  // -- Nodes: extract from IC childEntries with nested port data ---------------

  const icNodes = $derived(
    (childEntries['nodes'] ?? []).map((c) => {
      const p = c.props;
      const inputs = extractPorts(c, 'inputs');
      const outputs = extractPorts(c, 'outputs');
      return {
        id: c.id,
        type: c.type,
        position: (p.position as number[]) ?? [0, 0],
        disabled: (p.disabled as boolean) ?? false,
        locked: (p.locked as boolean) ?? false,
        parentNodeId: (p.parentNodeId as string) || undefined,
        inputs,
        outputs,
        nodeProps: p,
      };
    }),
  );

  // Build lookup: "nodeId:portName" → PortDef (for source port behavior on edges)
  const portBehaviorMap = $derived(
    new Map(
      icNodes.flatMap((n) =>
        n.outputs.map((p) => [`${n.id}:${p.name}`, p] as const),
      ),
    ),
  );

  // Stable key that changes only when port handles appear/disappear/rename.
  // Used to re-trigger edge reconciliation after handles register in the DOM.
  const nodeHandleKey = $derived(
    icNodes
      .map((n) => {
        const ins = n.inputs.map((p) => p.name).join(',');
        const outs = n.outputs.map((p) => p.name).join(',');
        return `${n.id}:${ins}:${outs}`;
      })
      .join('|'),
  );

  // Use $effect.pre so nodes (and their Handle components) are set BEFORE
  // the DOM update. Handles register during the DOM update, and the edge
  // $effect (post-DOM) then finds them already registered.
  $effect.pre(() => {
    const data = icNodes;
    const existing = new Map(untrack(() => flowNodes).map((n) => [n.id, n]));

    flowNodes = data.map((nd) => {
      const prev = existing.get(nd.id);
      const position = { x: nd.position[0], y: nd.position[1] };
      const nodeData = {
        label: (nd.nodeProps.label as string) ?? '',
        expression: (nd.nodeProps.expression as string) ?? '',
        color: (nd.nodeProps.color as string) ?? '',
        icon: nd.nodeProps.icon ?? null,
        disabled: nd.disabled,
        locked: nd.locked,
        inputs: nd.inputs,
        outputs: nd.outputs,
      };

      const base = prev
        ? { ...prev, position, data: nodeData }
        : { id: nd.id, type: nd.type, position, data: nodeData };

      if (nd.parentNodeId) {
        (base as any).parentId = nd.parentNodeId;
        (base as any).extent = 'parent';
      }
      if (nd.locked) {
        (base as any).draggable = false;
      }

      return base;
    });
  });

  // -- Edges: MATLAB-sourced edges with type mapping and data injection --------

  // Props to exclude from the edge data pass-through (handled separately)
  const EDGE_META_KEYS = new Set([
    'sourceNodeId',
    'targetNodeId',
    'sourcePortName',
    'targetPortName',
    'label',
  ]);

  const icEdges = $derived(
    (childEntries['edges'] ?? []).map((c) => {
      const p = c.props;
      const sourceId = p.sourceNodeId as string;
      const sourcePortName = (p.sourcePortName as string) || '';

      // Build edge data: display props + editor geometry + source port behavior
      const data: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(p)) {
        if (!EDGE_META_KEYS.has(k)) {
          data[k] = v;
        }
      }
      data.editorGeometry = edgeGeometry;

      // Inject source port behavior props
      const srcPort = portBehaviorMap.get(`${sourceId}:${sourcePortName}`);
      if (srcPort) {
        data.sourceOutputRate = srcPort.outputRate;
        data.sourceSpeed = srcPort.speed;
        data.sourceExpression = srcPort.expression;
        data.sourceFrequency = srcPort.frequency;
      }

      return {
        id: c.id,
        type: EDGE_TYPE_MAP[c.type] ?? 'default',
        source: sourceId,
        target: p.targetNodeId as string,
        sourceHandle: sourcePortName || undefined,
        targetHandle: (p.targetPortName as string) || undefined,
        label: (p.label as string) || undefined,
        data,
      } satisfies FlowEdge;
    }),
  );

  // Reconcile: when MATLAB's icEdges changes, merge with SF's flowEdges.
  // - MATLAB edges always win (add new, update existing)
  // - SF-only edges (user-created, not yet confirmed) are kept
  // - Edges removed from MATLAB are removed from SF
  //
  // Also depends on nodeHandleKey: when port data arrives (handles register),
  // edges must be re-set so Svelte Flow can resolve the handle positions.
  $effect(() => {
    const matlab = icEdges;
    const _handles = nodeHandleKey; // re-run when port handles change
    const matlabIds = new Set(matlab.map((e) => e.id));
    const current = untrack(() => flowEdges);

    // Keep SF-created edges only while MATLAB hasn't confirmed them yet.
    // Drop sf-* edges once a real edge with the same endpoints arrives.
    const sfOnly = current.filter((e) => {
      if (!e.id.startsWith('sf-')) return false;
      if (matlabIds.has(e.id)) return false;
      return !matlab.some(
        (m) =>
          m.source === e.source &&
          m.target === e.target &&
          m.sourceHandle === e.sourceHandle &&
          m.targetHandle === e.targetHandle,
      );
    });

    flowEdges = [...matlab, ...sfOnly];
  });

  // -- Connection: SF shows edge instantly, MATLAB confirms -------------------

  let sfEdgeCounter = 0;

  function handleBeforeConnect(connection: Connection): FlowEdge {
    const sfId = `sf-${++sfEdgeCounter}`;
    return {
      id: sfId,
      source: connection.source!,
      target: connection.target!,
      sourceHandle: connection.sourceHandle ?? undefined,
      targetHandle: connection.targetHandle ?? undefined,
    };
  }

  function handleConnect(connection: Connection): void {
    request?.('connect', {
      source: connection.source,
      sourcePort: connection.sourceHandle ?? '',
      target: connection.target,
      targetPort: connection.targetHandle ?? '',
    })?.catch(() => {
      // Failed — remove the SF edge
      flowEdges = flowEdges.filter(
        (e) =>
          !(
            e.id.startsWith('sf-') &&
            e.source === connection.source &&
            e.target === connection.target
          ),
      );
    });
  }

  // -- Deletion: eagerly remove, request MATLAB -------------------------------

  async function handleBeforeDelete({
    nodes,
    edges,
  }: {
    nodes: FlowNode[];
    edges: FlowEdge[];
  }): Promise<boolean> {
    const deletedNodeIds = new Set(nodes.map((n) => n.id));
    const deletableNodes = nodes.filter((n) => !n.data?.locked);

    if (deletableNodes.length > 0) {
      request?.('deleteNodes', {
        nodeIds: deletableNodes.map((n) => n.id),
      });
    }

    // Standalone edge deletions (not cascade from node delete)
    const standaloneEdges = edges.filter(
      (e) =>
        !deletedNodeIds.has(e.source) &&
        !deletedNodeIds.has(e.target) &&
        !e.id.startsWith('sf-'),
    );
    for (const edge of standaloneEdges) {
      request?.('disconnect', { edgeId: edge.id });
    }

    // Return true to let SF eagerly remove nodes/edges from the view
    return true;
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

  // -- Toolbar: user slot entries ---------------------------------------------

  const toolbarEntries = $derived(childEntries['toolbar'] ?? []);

</script>

<div class="ic-ne" style:height>
  {#if toolbarEntries.length > 0}
    <div class="ic-ne__toolbar">
      {#each toolbarEntries as entry (entry.id)}
        {@render entry.snippet()}
      {/each}
    </div>
  {/if}

  <div class="ic-ne__canvas">
    <SvelteFlow
      bind:nodes={flowNodes}
      bind:edges={flowEdges}
      {nodeTypes}
      {edgeTypes}
      fitView
      deleteKey={['Backspace', 'Delete']}
      onbeforeconnect={handleBeforeConnect}
      onconnect={handleConnect}
      onbeforedelete={handleBeforeDelete}
      onnodedragstop={handleNodeDragStop}
    >
      <Background variant={BackgroundVariant.Dots} gap={gridSize} size={1} />
      <Panel position="top-right">
        <ToolbarControls />
      </Panel>

      <!-- SVG marker definitions for StaticEdge arrow types -->
      <svg class="ic-ne__defs" width="0" height="0">
        <defs>
          <!-- Arrow marker (triangle) -->
          <marker
            id="ic-marker-arrow"
            viewBox="0 0 10 10"
            refX="10"
            refY="5"
            markerWidth="8"
            markerHeight="8"
            orient="auto-start-reverse"
          >
            <path d="M0 0 L10 5 L0 10 Z" fill="var(--ic-muted-foreground)" />
          </marker>
          <!-- Diamond marker -->
          <marker
            id="ic-marker-diamond"
            viewBox="0 0 10 10"
            refX="5"
            refY="5"
            markerWidth="10"
            markerHeight="10"
            orient="auto-start-reverse"
          >
            <path d="M5 0 L10 5 L5 10 L0 5 Z" fill="var(--ic-muted-foreground)" />
          </marker>
          <!-- Circle marker -->
          <marker
            id="ic-marker-circle"
            viewBox="0 0 10 10"
            refX="5"
            refY="5"
            markerWidth="8"
            markerHeight="8"
            orient="auto"
          >
            <circle cx="5" cy="5" r="4" fill="var(--ic-muted-foreground)" />
          </marker>
        </defs>
      </svg>
    </SvelteFlow>
  </div>
</div>

<!--
  ToolbarControls — must be a child of SvelteFlow to access useSvelteFlow().
  Renders built-in viewport controls.
-->
{#snippet ToolbarControls()}
  {@const flow = useSvelteFlow()}
  <div class="ic-ne__controls">
    <!-- Viewport controls -->
    <button
      class="ic-ne__control-btn"
      title="Fit view"
      onclick={() => flow.fitView({ duration: 200 })}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M8 3H5a2 2 0 00-2 2v3m18 0V5a2 2 0 00-2-2h-3m0 18h3a2 2 0 002-2v-3M3 16v3a2 2 0 002 2h3" />
      </svg>
    </button>
    <button
      class="ic-ne__control-btn"
      title="Zoom in"
      onclick={() => flow.zoomIn({ duration: 200 })}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35M11 8v6m-3-3h6" />
      </svg>
    </button>
    <button
      class="ic-ne__control-btn"
      title="Zoom out"
      onclick={() => flow.zoomOut({ duration: 200 })}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35M8 11h6" />
      </svg>
    </button>
  </div>
{/snippet}

<style>
  .ic-ne {
    width: 100%;
    display: flex;
    flex-direction: column;
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

  .ic-ne__toolbar {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    background: var(--ic-muted);
    border-bottom: 1px solid var(--ic-border);
    flex-shrink: 0;
  }

  .ic-ne__canvas {
    flex: 1;
    min-height: 0;
  }

  .ic-ne__defs {
    position: absolute;
    pointer-events: none;
  }

  /* ── Built-in controls (edge mode + viewport) ─── */
  .ic-ne__controls {
    display: flex;
    align-items: center;
    gap: 2px;
    background: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    padding: 2px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .ic-ne__control-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-muted-foreground);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
  }

  .ic-ne__control-btn:hover {
    background: var(--ic-muted);
    color: var(--ic-foreground);
  }

  .ic-ne__control-btn:active {
    background: var(--ic-border);
  }

</style>
