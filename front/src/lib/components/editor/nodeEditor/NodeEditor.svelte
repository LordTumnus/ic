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
    MiniMap,
    Panel,
    useSvelteFlow,
    type Node as FlowNode,
    type Edge as FlowEdge,
    type Connection,
  } from '@xyflow/svelte';
  import '@xyflow/svelte/dist/base.css';

  import type { ChildEntries, ChildEntry, RequestFn, Resolution } from '$lib/types';
  import { extractPorts, type PortDef } from '$lib/utils/node-editor-types';
  import { EDGE_TYPE_MAP } from '$lib/utils/edge-utils';
  import dagre from '@dagrejs/dagre';
  import logger from '$lib/core/logger';
  import ContextMenu from '$lib/components/shared/ContextMenu.svelte';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import StoreCapture from './StoreCapture.svelte';

  // Node type components — one per concrete MATLAB class
  import TransformNode from './nodes/TransformNode.svelte';

  // Edge type components — one per concrete MATLAB edge class
  import StaticEdgeRenderer from './edges/StaticEdgeRenderer.svelte';
  import FlowEdgeRenderer from './edges/FlowEdgeRenderer.svelte';
  import SignalEdgeRenderer from './edges/SignalEdgeRenderer.svelte';

  const OK: Resolution = { success: true, data: null };

  let {
    height = $bindable('100%'),
    gridSize = $bindable(20),
    edgeGeometry = $bindable('bezier'),
    showMiniMap = $bindable(false),
    layout = $bindable('horizontal'),
    snapToGrid = $bindable(false),
    childEntries = {} as ChildEntries,
    request,
    // Selection state (written back to MATLAB)
    selectedNodeIds = $bindable<string[]>([]),
    selectedEdgeIds = $bindable<string[]>([]),
    // Events
    nodeMoved,
    selectionChanged,
    // Methods
    fitView: fitViewMethod = $bindable((): Resolution => OK),
    zoomTo = $bindable((_data: { level: number }): Resolution => OK),
    selectAll: selectAllMethod = $bindable((): Resolution => OK),
    clearSelection: clearSelectionMethod = $bindable((): Resolution => OK),
    relayout: relayoutMethod = $bindable((_data?: unknown): Resolution => OK),
  }: {
    height?: string;
    gridSize?: number;
    edgeGeometry?: string;
    showMiniMap?: boolean;
    layout?: string;
    snapToGrid?: boolean;
    childEntries?: ChildEntries;
    request?: RequestFn;
    selectedNodeIds?: string[];
    selectedEdgeIds?: string[];
    nodeMoved?: (data?: unknown) => void;
    selectionChanged?: (data?: unknown) => void;
    fitView?: () => Resolution;
    zoomTo?: (data: { level: number }) => Resolution;
    selectAll?: () => Resolution;
    clearSelection?: () => Resolution;
    relayout?: (data?: unknown) => Resolution;
  } = $props();

  // -- Snap grid: when enabled, nodes snap to gridSize intervals ---------------
  const snapGrid = $derived<[number, number] | undefined>(
    snapToGrid ? [gridSize, gridSize] : undefined,
  );

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
  let flowEdges: FlowEdge[] = $state.raw([]);

  // -- Nodes: per-node reactive isolation ----------------------------------------
  //
  // Each node gets its own $derived that tracks ONLY its proxy properties.
  // A property change on node1 does NOT cause node2's $derived to re-run.
  // This prevents the cascade where every property change on any node/port
  // would rebuild all nodes, all maps, and all edges.

  const nodeEntries = $derived(childEntries['nodes'] ?? []);

  class NodeState {
    entry: ChildEntry;

    readonly data = $derived.by(() => {
      const e = this.entry;
      const p = e.props;
      return {
        id: e.id,
        type: e.type,
        position: (p.position as number[]) ?? [0, 0],
        disabled: (p.disabled as boolean) ?? false,
        locked: (p.locked as boolean) ?? false,
        parentNodeId: (p.parentNodeId as string) || undefined,
        label: (p.label as string) ?? '',
        expression: (p.expression as string) ?? '',
        color: (p.color as string) ?? '',
        icon: p.icon ?? null,
        inputs: extractPorts(e, 'inputs'),
        outputs: extractPorts(e, 'outputs'),
      };
    });

    constructor(entry: ChildEntry) {
      this.entry = entry;
    }
  }

  // Maintain per-node state objects. Only re-runs on structural changes
  // (add/remove/reorder), NOT on property changes within existing nodes.
  const nodeStateMap = new Map<string, NodeState>();

  const nodeStates = $derived.by(() => {
    const entries = nodeEntries;
    const next = new Map<string, NodeState>();
    for (const entry of entries) {
      const existing = nodeStateMap.get(entry.id);
      if (existing) {
        existing.entry = entry;
        next.set(entry.id, existing);
      } else {
        next.set(entry.id, new NodeState(entry));
      }
    }
    nodeStateMap.clear();
    for (const [k, v] of next) nodeStateMap.set(k, v);
    return [...next.values()];
  });

  // Build lookup: "nodeId:portName" → PortDef (for source port behavior on edges)
  const portBehaviorMap = $derived.by(() => {
    const map = new Map<string, PortDef>();
    for (const ns of nodeStates) {
      for (const p of ns.data.outputs) map.set(`${ns.data.id}:${p.name}`, p);
    }
    return map;
  });

  // Build lookup: "nodeId:portName" → PortDef (all ports, for connection validation)
  const allPortMap = $derived.by(() => {
    const map = new Map<string, PortDef>();
    for (const ns of nodeStates) {
      const d = ns.data;
      for (const p of [...d.inputs, ...d.outputs]) map.set(`${d.id}:${p.name}`, p);
    }
    return map;
  });

  // Stable key that changes only when port handles appear/disappear/rename.
  // Used to re-trigger edge reconciliation after handles register in the DOM.
  const nodeHandleKey = $derived(
    nodeStates
      .map((ns) => {
        const d = ns.data;
        return `${d.id}:${d.inputs.map((p) => p.name).join(',')}:${d.outputs.map((p) => p.name).join(',')}`;
      })
      .join('|'),
  );

  // Map nodeStates → SvelteFlow FlowNode[]. Uses $effect.pre so nodes are set
  // BEFORE the DOM update (handles register during DOM update, edge $effect
  // runs after). When ns.data is the same reference (unchanged $derived),
  // the previous FlowNode is reused — preserving SvelteFlow's handleBounds.
  $effect.pre(() => {
    const states = nodeStates;
    const existing = new Map(untrack(() => flowNodes).map((n) => [n.id, n]));
    let changed = false;

    const mapped = states.map((ns) => {
      const d = ns.data;
      const prev = existing.get(d.id);

      // $derived returns the same object when dependencies haven't changed.
      // Reuse previous FlowNode to prevent SvelteFlow's adoptUserNodes from
      // re-processing it (which can wipe handleBounds before measurement).
      if (prev && (prev as any).__nsData === d) return prev;

      changed = true;
      const node: any = {
        id: d.id,
        type: d.type,
        position: { x: d.position[0], y: d.position[1] },
        data: {
          label: d.label,
          expression: d.expression,
          color: d.color,
          icon: d.icon,
          disabled: d.disabled,
          locked: d.locked,
          inputs: d.inputs,
          outputs: d.outputs,
        },
      };
      if (d.parentNodeId) {
        node.parentId = d.parentNodeId;
        node.extent = 'parent';
      }
      if (d.locked) node.draggable = false;
      node.__nsData = d;
      return node;
    });

    if (changed || mapped.length !== untrack(() => flowNodes).length) {
      flowNodes = mapped;
    }
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
  //
  // IMPORTANT: The timer variable lives OUTSIDE the effect so we can cancel
  // it at the START of the next run. MATLAB sends edge updates as separate
  // postMessage events; the browser processes timer callbacks between them,
  // so Svelte's cleanup (which runs at next-effect-start) fires AFTER the
  // timer has already executed with a stale closure.
  let edgeRetryTimer: ReturnType<typeof setTimeout> | null = null;

  $effect(() => {
    const matlab = icEdges;
    const _handles = nodeHandleKey; // re-run when port handles change

    // Cancel any pending retry FIRST — before it fires with stale data
    if (edgeRetryTimer !== null) {
      clearTimeout(edgeRetryTimer);
      edgeRetryTimer = null;
    }

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

    const merged = [...matlab, ...sfOnly];
    flowEdges = merged;

    // Deferred retry: after all edges arrive and ResizeObserver registers
    // handle bounds, check if any edges failed to render. SvelteFlow skips
    // edges when getEdgePosition() can't find handleBounds (race condition
    // during initial load). Fix: force updateNodeInternals for affected
    // nodes, then re-apply edges with new references.
    if (matlab.length > 0) {
      edgeRetryTimer = setTimeout(() => {
        edgeRetryTimer = null;
        const current = flowEdges;
        const domEdges = document.querySelectorAll('.svelte-flow__edge').length;
        if (domEdges < current.length) {
          const store = sfRefs.store;
          if (store) {
            const domEdgeIds = new Set(
              Array.from(document.querySelectorAll('.svelte-flow__edge'))
                .map(el => el.getAttribute('data-id'))
            );
            const missing = current.filter(e => !domEdgeIds.has(e.id));

            // Force updateNodeInternals for nodes with missing handleBounds
            const nodeIdsToFix = new Set<string>();
            for (const e of missing) {
              const srcHB = store.nodeLookup.get(e.source)?.internals?.handleBounds;
              const tgtHB = store.nodeLookup.get(e.target)?.internals?.handleBounds;
              if (!srcHB?.source?.length) nodeIdsToFix.add(e.source);
              if (!tgtHB?.target?.length) nodeIdsToFix.add(e.target);
            }
            if (nodeIdsToFix.size > 0) {
              const updates = new Map<string, { id: string; nodeElement: HTMLDivElement; force: boolean }>();
              for (const nodeId of nodeIdsToFix) {
                const el = document.querySelector(`[data-id="${nodeId}"]`) as HTMLDivElement;
                if (el) updates.set(nodeId, { id: nodeId, nodeElement: el, force: true });
              }
              if (updates.size > 0) store.updateNodeInternals(updates);
            }
          }

          // Re-apply edges with new refs to force visible re-derivation
          flowEdges = current.map((e) => ({ ...e }));
        }
      }, 200);
    }
  });

  // -- Connection validation: MaxConnections enforcement ----------------------

  function isValidConnection(connection: Connection): boolean {
    const { source, target, sourceHandle, targetHandle } = connection;
    if (!source || !target) return false;

    // No self-connections
    if (source === target) return false;

    const srcPort = allPortMap.get(`${source}:${sourceHandle ?? ''}`);
    const tgtPort = allPortMap.get(`${target}:${targetHandle ?? ''}`);
    if (!srcPort || !tgtPort) return false;

    // Count existing edges on each port
    const srcCount = flowEdges.filter(
      (e) => e.source === source && e.sourceHandle === sourceHandle,
    ).length;
    const tgtCount = flowEdges.filter(
      (e) => e.target === target && e.targetHandle === targetHandle,
    ).length;

    if (srcCount >= srcPort.maxConnections) return false;
    if (tgtCount >= tgtPort.maxConnections) return false;

    return true;
  }

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

  /** Write back positions for an array of flow nodes to MATLAB childEntries. */
  function writeBackPositions(nodes: FlowNode[]) {
    const entries = childEntries['nodes'] ?? [];
    for (const fn of nodes) {
      const child = entries.find((c) => c.id === fn.id);
      if (child) {
        child.props.position = [fn.position.x, fn.position.y];
      }
    }
  }

  /** Single-node drag stop. */
  function handleNodeDragStop({ targetNode, nodes: draggedNodes }: { targetNode: FlowNode | null; nodes: FlowNode[] }) {
    if (!targetNode) return;
    writeBackPositions(draggedNodes);
    nodeMoved?.({ value: { nodeId: targetNode.id, position: [targetNode.position.x, targetNode.position.y] } });
  }

  /** Multi-node (selection) drag stop — fires instead of onnodedragstop when dragging a selection. */
  function handleSelectionDragStop(_event: MouseEvent, nodes: FlowNode[]) {
    writeBackPositions(nodes);
    nodeMoved?.({ value: { nodeIds: nodes.map((n) => n.id) } });
  }

  // -- Toolbar: user slot entries ---------------------------------------------

  const toolbarEntries = $derived(childEntries['toolbar'] ?? []);

  // -- Flow API + store references -----------------------------------------------
  // Both captured by child components inside SvelteFlow (where getContext works).
  // Plain object — NOT $state — because these are set during render (snippet/mount).
  const sfRefs: { flow: any; store: any } = { flow: null, store: null };

  // -- Initial fit: one-time fitView after first nodes arrive ------------------

  let initialFitDone = false;
  $effect(() => {
    if (initialFitDone || !sfRefs.flow || flowNodes.length === 0) return;
    initialFitDone = true;
    const flow = sfRefs.flow;
    queueMicrotask(() => flow.fitView({ duration: 0 }));
  });

  // -- Selection: bridge SvelteFlow → MATLAB ----------------------------------

  function handleSelectionChange({ nodes, edges }: { nodes: FlowNode[]; edges: FlowEdge[] }) {
    const nodeIds = nodes.map((n) => n.id);
    const edgeIds = edges.map((e) => e.id);
    selectedNodeIds = nodeIds;
    selectedEdgeIds = edgeIds;
    selectionChanged?.({ value: { nodeIds, edgeIds } });
  }

  // -- Keyboard: Ctrl+A (select all), Escape (clear selection) ----------------

  function handleKeyDown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'a') {
      e.preventDefault();
      flowNodes = flowNodes.map((n) => ({ ...n, selected: true }));
      flowEdges = flowEdges.map((fe) => ({ ...fe, selected: true }));
      return;
    }
    if (e.key === 'Escape') {
      flowNodes = flowNodes.map((n) => ({ ...n, selected: false }));
      flowEdges = flowEdges.map((fe) => ({ ...fe, selected: false }));
      return;
    }
  }

  // -- Methods: wire MATLAB → SvelteFlow via captured flow API ----------------

  // Methods that DON'T need the flow API — wire immediately
  selectAllMethod = (): Resolution => {
    flowNodes = flowNodes.map((n) => ({ ...n, selected: true }));
    flowEdges = flowEdges.map((fe) => ({ ...fe, selected: true }));
    return OK;
  };
  clearSelectionMethod = (): Resolution => {
    flowNodes = flowNodes.map((n) => ({ ...n, selected: false }));
    flowEdges = flowEdges.map((fe) => ({ ...fe, selected: false }));
    return OK;
  };

  /** Run dagre layout and update node positions. */
  function runDagreLayout(direction: string) {
    const dir = direction === 'vertical' ? 'TB' : 'LR';
    const g = new dagre.graphlib.Graph();
    g.setDefaultEdgeLabel(() => ({}));
    g.setGraph({ rankdir: dir, nodesep: 50, ranksep: 80 });

    for (const node of flowNodes) {
      const el = document.querySelector(`[data-id="${node.id}"]`);
      const width = el?.clientWidth ?? 180;
      const height = el?.clientHeight ?? 100;
      g.setNode(node.id, { width, height });
    }

    for (const edge of flowEdges) {
      g.setEdge(edge.source, edge.target);
    }

    dagre.layout(g);

    const updated = flowNodes.map((node) => {
      const dagreNode = g.node(node.id);
      return {
        ...node,
        position: {
          x: dagreNode.x - dagreNode.width / 2,
          y: dagreNode.y - dagreNode.height / 2,
        },
      };
    });

    flowNodes = updated;
    writeBackPositions(updated);
    return updated;
  }

  relayoutMethod = (): Resolution => {
    try {
      runDagreLayout(layout);
    } catch (e) {
      logger.error('NodeEditor', 'relayout failed', { error: String(e) });
    }
    return OK;
  };

  // Methods that NEED the flow API — check sfRefs.flow at call time
  fitViewMethod = (): Resolution => {
    sfRefs.flow?.fitView({ duration: 200 });
    return OK;
  };
  zoomTo = (data: { level: number }): Resolution => {
    sfRefs.flow?.zoomTo(data.level, { duration: 200 });
    return OK;
  };

  // -- Context menu state -----------------------------------------------------

  let ctxMenu = $state<{
    entries: ContextMenuEntry[];
    x: number;
    y: number;
    context: { type: 'edge' | 'node' | 'port'; id: string; data?: any };
  } | null>(null);

  function closeCtxMenu() {
    ctxMenu = null;
  }

  // -- Edge context menu ------------------------------------------------------

  function buildEdgeContextMenu(edge: FlowEdge): ContextMenuEntry[] {
    const geom = (edge.data?.geometry as string) || edgeGeometry;
    const startArrow = (edge.data?.startArrow as string) || 'none';
    const endArrow = (edge.data?.endArrow as string) || 'none';
    const edgeType = edge.type || 'static';
    const arrowOptions = ['none', 'arrow', 'diamond', 'circle'] as const;

    const edgeColor = (edge.data?.color as string) || '';
    const thickness = (edge.data?.thickness as number) ?? 1;

    // Shared base-edge entries
    const entries: ContextMenuEntry[] = [
      {
        type: 'folder', label: 'Geometry', icon: 'spline',
        children: (['bezier', 'straight', 'smoothstep', 'step'] as const).map((g) => ({
          type: 'item' as const,
          key: `geometry:${g}`,
          label: g.charAt(0).toUpperCase() + g.slice(1),
          icon: geom === g ? 'check' : undefined,
        })),
      },
      {
        type: 'folder', label: 'Start Arrow', icon: 'arrow-left',
        children: arrowOptions.map((a) => ({
          type: 'item' as const,
          key: `startArrow:${a}`,
          label: a.charAt(0).toUpperCase() + a.slice(1),
          icon: startArrow === a ? 'check' : undefined,
        })),
      },
      {
        type: 'folder', label: 'End Arrow', icon: 'arrow-right',
        children: arrowOptions.map((a) => ({
          type: 'item' as const,
          key: `endArrow:${a}`,
          label: a.charAt(0).toUpperCase() + a.slice(1),
          icon: endArrow === a ? 'check' : undefined,
        })),
      },
      {
        type: 'folder', label: `Thickness (${thickness})`, icon: 'minus',
        children: [1, 2, 3, 4, 5, 6].map((t) => ({
          type: 'item' as const,
          key: `thickness:${t}`,
          label: `${t}px`,
          icon: thickness === t ? 'check' : undefined,
        })),
      },
      { type: 'color', key: 'color', label: 'Edge Color', value: edgeColor },
    ];

    // Edge-type-specific entries
    entries.push({ type: 'separator' });

    if (edgeType === 'static') {
      const animated = (edge.data?.animated as boolean) ?? false;
      entries.push({
        type: 'item', key: 'toggle-animated',
        label: animated ? 'Disable Animation' : 'Enable Animation',
        icon: animated ? 'pause' : 'play',
      });
    } else if (edgeType === 'flow') {
      const pSize = (edge.data?.particleSize as number) ?? 3;
      entries.push({
        type: 'folder', label: `Particle Size (${pSize})`, icon: 'circle-dot',
        children: [1, 2, 3, 4, 5, 6].map((s) => ({
          type: 'item' as const,
          key: `particleSize:${s}`,
          label: `${s}px`,
          icon: pSize === s ? 'check' : undefined,
        })),
      });
      entries.push({
        type: 'color', key: 'particleColor', label: 'Particle Color',
        value: (edge.data?.particleColor as string) || '',
      });
    } else if (edgeType === 'signal') {
      const amp = (edge.data?.amplitude as number) ?? 8;
      entries.push({
        type: 'folder', label: `Amplitude (${amp})`, icon: 'activity',
        children: [4, 6, 8, 12, 16, 24].map((a) => ({
          type: 'item' as const,
          key: `amplitude:${a}`,
          label: `${a}px`,
          icon: amp === a ? 'check' : undefined,
        })),
      });
      const sigThick = (edge.data?.signalThickness as number) ?? 2;
      entries.push({
        type: 'folder', label: `Signal Width (${sigThick})`, icon: 'pen-line',
        children: [1, 2, 3, 4, 5].map((w) => ({
          type: 'item' as const,
          key: `signalThickness:${w}`,
          label: `${w}px`,
          icon: sigThick === w ? 'check' : undefined,
        })),
      });
      entries.push({
        type: 'color', key: 'signalColor', label: 'Signal Color',
        value: (edge.data?.signalColor as string) || '',
      });
    }

    entries.push({ type: 'separator' });
    entries.push({ type: 'item', key: 'delete-edge', label: 'Delete Edge', icon: 'trash-2' });

    return entries;
  }

  function handleEdgeContextMenu(event: MouseEvent, edge: FlowEdge) {
    event.preventDefault();
    ctxMenu = {
      entries: buildEdgeContextMenu(edge),
      x: event.clientX,
      y: event.clientY,
      context: { type: 'edge', id: edge.id, data: edge },
    };
  }

  /** Update a single prop on a flow edge + write back to childEntries. */
  function updateEdgeProp(edgeId: string, prop: string, value: unknown) {
    flowEdges = flowEdges.map((e) =>
      e.id === edgeId ? { ...e, data: { ...e.data, [prop]: value } } : e,
    );
    const edgeEntries = childEntries['edges'] ?? [];
    const entry = edgeEntries.find((c) => c.id === edgeId);
    if (entry) entry.props[prop] = value;
  }

  // -- Node context menu ------------------------------------------------------

  function buildNodeContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    const entries: ContextMenuEntry[] = [
      // Node-specific editable props
      { type: 'text', key: 'label', label: 'Label', value: (node.data?.label as string) || '' },
      { type: 'text', key: 'expression', label: 'f(x)', value: (node.data?.expression as string) || '', placeholder: 'e.g. x + 1' },
      { type: 'color', key: 'nodeColor', label: 'Node Color', value: (node.data?.color as string) || '' },
      { type: 'separator' },
      {
        type: 'item',
        key: 'toggle-lock',
        label: locked ? 'Unlock Node' : 'Lock Node',
        icon: locked ? 'unlock' : 'lock',
      },
      {
        type: 'item',
        key: 'toggle-disabled',
        label: disabled ? 'Enable Node' : 'Disable Node',
        icon: disabled ? 'eye' : 'eye-off',
      },
      { type: 'separator' },
      {
        type: 'item',
        key: 'disconnect-all',
        label: `Disconnect All (${connectedEdgeCount})`,
        icon: 'unplug',
        disabled: connectedEdgeCount === 0,
      },
      { type: 'separator' },
      {
        type: 'item',
        key: 'delete-node',
        label: 'Delete Node',
        icon: 'trash-2',
        disabled: locked,
      },
    ];

    return entries;
  }

  // -- Port context menu ------------------------------------------------------

  function buildPortContextMenu(
    node: FlowNode,
    portName: string,
    portSide: 'input' | 'output',
  ): ContextMenuEntry[] {
    const ports = (portSide === 'input' ? node.data?.inputs : node.data?.outputs) as PortDef[] | undefined;
    const port = ports?.find((p) => p.name === portName);
    if (!port) return [];

    const portEdges = flowEdges.filter((e) =>
      portSide === 'input'
        ? (e.target === node.id && e.targetHandle === portName)
        : (e.source === node.id && e.sourceHandle === portName),
    );

    const entries: ContextMenuEntry[] = [
      {
        type: 'item',
        key: 'port-info',
        label: `${port.label || port.name} (${port.type})`,
        disabled: true,
      },
      { type: 'separator' },
      { type: 'text', key: 'port-label', label: 'Label', value: port.label || '' },
      { type: 'separator' },
    ];

    // Output port props — type, rate, speed, expression, frequency
    if (portSide === 'output') {
      entries.push({
        type: 'folder',
        label: 'Port Type',
        icon: 'cable',
        children: (['static', 'flow', 'signal'] as const).map((t) => ({
          type: 'item' as const,
          key: `port-type:${t}`,
          label: t.charAt(0).toUpperCase() + t.slice(1),
          icon: port.type === t ? 'check' : undefined,
        })),
      });

      // Flow props: output rate + speed
      if (port.type === 'flow' || port.type === 'signal') {
        entries.push({
          type: 'folder',
          label: `Speed (${port.speed})`,
          icon: 'gauge',
          children: [0.25, 0.5, 1, 2, 3, 5].map((s) => ({
            type: 'item' as const,
            key: `port-speed:${s}`,
            label: `${s}x`,
            icon: port.speed === s ? 'check' : undefined,
          })),
        });
      }

      if (port.type === 'flow') {
        entries.push({
          type: 'folder',
          label: `Output Rate (${port.outputRate})`,
          icon: 'rows-3',
          children: [1, 2, 3, 5, 8, 12].map((r) => ({
            type: 'item' as const,
            key: `port-outputRate:${r}`,
            label: `${r}`,
            icon: port.outputRate === r ? 'check' : undefined,
          })),
        });
      }

      // Signal props: expression + frequency
      if (port.type === 'signal') {
        entries.push(
          { type: 'text', key: 'port-expression', label: 'f(t)', value: port.expression || 'sin(2*pi*t)', placeholder: 'e.g. sin(2*pi*t)' },
          {
            type: 'folder',
            label: `Frequency (${port.frequency})`,
            icon: 'audio-waveform',
            children: [1, 2, 3, 4, 6, 8].map((f) => ({
              type: 'item' as const,
              key: `port-frequency:${f}`,
              label: `${f}`,
              icon: port.frequency === f ? 'check' : undefined,
            })),
          },
        );
      }

      entries.push({ type: 'separator' });
    }

    entries.push({
      type: 'item',
      key: 'disconnect-port',
      label: `Disconnect (${portEdges.length})`,
      icon: 'unplug',
      disabled: portEdges.length === 0,
    });

    return entries;
  }

  function handleNodeContextMenu(event: MouseEvent, node: FlowNode) {
    event.preventDefault();

    // Check if the right-click was on a port dot
    const target = event.target as HTMLElement;
    const portEl = target.closest('[data-port-name]') as HTMLElement | null;

    if (portEl) {
      const portName = portEl.dataset.portName!;
      const portSide = portEl.dataset.portSide as 'input' | 'output';
      ctxMenu = {
        entries: buildPortContextMenu(node, portName, portSide),
        x: event.clientX,
        y: event.clientY,
        context: { type: 'port', id: node.id, data: { portName, portSide } },
      };
    } else {
      ctxMenu = {
        entries: buildNodeContextMenu(node),
        x: event.clientX,
        y: event.clientY,
        context: { type: 'node', id: node.id, data: node },
      };
    }
  }

  /** Update a single prop on a node + write back to childEntries. */
  function updateNodeProp(nodeId: string, prop: string, value: unknown) {
    flowNodes = flowNodes.map((n) =>
      n.id === nodeId ? { ...n, data: { ...n.data, [prop]: value } } : n,
    );
    const nodeEntries = childEntries['nodes'] ?? [];
    const entry = nodeEntries.find((c) => c.id === nodeId);
    if (entry) entry.props[prop] = value;
  }

  /** Map output port props to edge data keys. */
  const PORT_TO_EDGE_KEY: Record<string, string> = {
    outputRate: 'sourceOutputRate',
    speed: 'sourceSpeed',
    expression: 'sourceExpression',
    frequency: 'sourceFrequency',
  };

  /** Update a single prop on a port + write back to childEntries + propagate to edges. */
  function updatePortProp(nodeId: string, portName: string, portSide: 'input' | 'output', prop: string, value: unknown) {
    const portsKey = portSide === 'input' ? 'inputs' : 'outputs';
    // Update childEntries
    const nodeEntries = childEntries['nodes'] ?? [];
    const nodeEntry = nodeEntries.find((c) => c.id === nodeId);
    if (nodeEntry) {
      const portEntries = (nodeEntry.props.childEntries as any)?.[portsKey] ?? [];
      const portEntry = portEntries.find((p: any) => p.props.name === portName);
      if (portEntry) portEntry.props[prop] = value;
    }
    // Update flowNodes data
    flowNodes = flowNodes.map((n) => {
      if (n.id !== nodeId) return n;
      const ports = (n.data?.[portsKey] as PortDef[]) ?? [];
      return {
        ...n,
        data: {
          ...n.data,
          [portsKey]: ports.map((p) =>
            p.name === portName ? { ...p, [prop]: value } : p,
          ),
        },
      };
    });
    // Propagate behavior props to connected edges
    const edgeDataKey = PORT_TO_EDGE_KEY[prop];
    if (edgeDataKey && portSide === 'output') {
      flowEdges = flowEdges.map((e) =>
        (e.source === nodeId && e.sourceHandle === portName)
          ? { ...e, data: { ...e.data, [edgeDataKey]: value } }
          : e,
      );
    }
  }

  // Keys whose actions should NOT close the menu (live preview / inline editing)
  const COLOR_PROPS = new Set(['color', 'signalColor', 'particleColor', 'nodeColor']);
  const TEXT_PROPS = new Set(['label', 'expression', 'port-label', 'port-expression']);

  function handleCtxAction(key: string) {
    const ctx = ctxMenu?.context;
    if (!ctx) return;

    const colonIdx0 = key.indexOf(':');
    const propKey = colonIdx0 > 0 ? key.slice(0, colonIdx0) : '';
    const isLiveAction = COLOR_PROPS.has(propKey) || TEXT_PROPS.has(propKey);
    if (!isLiveAction) closeCtxMenu();

    if (ctx.type === 'edge') {
      if (key === 'delete-edge') {
        if (!ctx.id.startsWith('sf-')) {
          request?.('disconnect', { edgeId: ctx.id });
        }
        flowEdges = flowEdges.filter((e) => e.id !== ctx.id);
      } else if (key === 'toggle-animated') {
        const edge = flowEdges.find((e) => e.id === ctx.id);
        const current = (edge?.data?.animated as boolean) ?? false;
        updateEdgeProp(ctx.id, 'animated', !current);
      } else {
        // Generic key:value pattern (geometry, startArrow, endArrow, particleSize, amplitude, signalThickness)
        const colonIdx = key.indexOf(':');
        if (colonIdx > 0) {
          const prop = key.slice(0, colonIdx);
          const raw = key.slice(colonIdx + 1);
          const numericProps = new Set(['thickness', 'particleSize', 'amplitude', 'signalThickness']);
          const value = numericProps.has(prop) ? Number(raw) : raw;
          updateEdgeProp(ctx.id, prop, value);
        }
      }
    } else if (ctx.type === 'node') {
      if (key.startsWith('nodeColor:')) {
        updateNodeProp(ctx.id, 'color', key.slice('nodeColor:'.length));
      } else if (key.startsWith('label:')) {
        updateNodeProp(ctx.id, 'label', key.slice('label:'.length));
      } else if (key.startsWith('expression:')) {
        updateNodeProp(ctx.id, 'expression', key.slice('expression:'.length));
      } else if (key === 'toggle-lock') {
        const node = flowNodes.find((n) => n.id === ctx.id);
        const current = (node?.data?.locked as boolean) ?? false;
        updateNodeProp(ctx.id, 'locked', !current);
      } else if (key === 'toggle-disabled') {
        const node = flowNodes.find((n) => n.id === ctx.id);
        const current = (node?.data?.disabled as boolean) ?? false;
        updateNodeProp(ctx.id, 'disabled', !current);
      } else if (key === 'disconnect-all') {
        const connected = flowEdges.filter(
          (e) => e.source === ctx.id || e.target === ctx.id,
        );
        for (const edge of connected) {
          if (!edge.id.startsWith('sf-')) {
            request?.('disconnect', { edgeId: edge.id });
          }
        }
        flowEdges = flowEdges.filter(
          (e) => e.source !== ctx.id && e.target !== ctx.id,
        );
      } else if (key === 'delete-node') {
        const node = flowNodes.find((n) => n.id === ctx.id);
        if (node && !node.data?.locked) {
          request?.('deleteNodes', { nodeIds: [ctx.id] });
          // Also disconnect all edges connected to this node
          const connected = flowEdges.filter(
            (e) => e.source === ctx.id || e.target === ctx.id,
          );
          for (const edge of connected) {
            if (!edge.id.startsWith('sf-')) {
              request?.('disconnect', { edgeId: edge.id });
            }
          }
          flowEdges = flowEdges.filter(
            (e) => e.source !== ctx.id && e.target !== ctx.id,
          );
          flowNodes = flowNodes.filter((n) => n.id !== ctx.id);
        }
      }
    } else if (ctx.type === 'port') {
      const { portName, portSide } = ctx.data as { portName: string; portSide: 'input' | 'output' };
      if (key.startsWith('port-label:')) {
        const newLabel = key.slice('port-label:'.length);
        updatePortProp(ctx.id, portName, portSide, 'label', newLabel);
      } else if (key === 'disconnect-port') {
        const portEdges = flowEdges.filter((e) =>
          portSide === 'input'
            ? (e.target === ctx.id && e.targetHandle === portName)
            : (e.source === ctx.id && e.sourceHandle === portName),
        );
        for (const edge of portEdges) {
          if (!edge.id.startsWith('sf-')) {
            request?.('disconnect', { edgeId: edge.id });
          }
        }
        flowEdges = flowEdges.filter((e) => !portEdges.includes(e));
      } else if (key.startsWith('port-type:')) {
        updatePortProp(ctx.id, portName, portSide, 'type', key.slice('port-type:'.length));
      } else if (key.startsWith('port-speed:')) {
        updatePortProp(ctx.id, portName, portSide, 'speed', Number(key.slice('port-speed:'.length)));
      } else if (key.startsWith('port-outputRate:')) {
        updatePortProp(ctx.id, portName, portSide, 'outputRate', Number(key.slice('port-outputRate:'.length)));
      } else if (key.startsWith('port-expression:')) {
        updatePortProp(ctx.id, portName, portSide, 'expression', key.slice('port-expression:'.length));
      } else if (key.startsWith('port-frequency:')) {
        updatePortProp(ctx.id, portName, portSide, 'frequency', Number(key.slice('port-frequency:'.length)));
      }
    }
  }

</script>

<div class="ic-ne" style:height>
  {#if toolbarEntries.length > 0}
    <div class="ic-ne__toolbar">
      {#each toolbarEntries as entry (entry.id)}
        {@render entry.snippet()}
      {/each}
    </div>
  {/if}

  <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="ic-ne__canvas" tabindex={-1} onkeydown={handleKeyDown}>
    <SvelteFlow
      bind:nodes={flowNodes}
      bind:edges={flowEdges}
      {nodeTypes}
      {edgeTypes}
      {snapGrid}
      deleteKey={['Backspace', 'Delete']}
      multiSelectionKeyCode="Meta"
      selectionKeyCode="Shift"
      {isValidConnection}
      onbeforeconnect={handleBeforeConnect}
      onconnect={handleConnect}
      onbeforedelete={handleBeforeDelete}
      onnodedragstop={handleNodeDragStop}
      onselectiondragstop={handleSelectionDragStop}
      onselectionchange={handleSelectionChange}
      onedgecontextmenu={({ event, edge }) => handleEdgeContextMenu(event, edge)}
      onnodecontextmenu={({ event, node }) => handleNodeContextMenu(event, node)}
      onpanecontextmenu={({ event }) => event.preventDefault()}
    >
      <Background variant={BackgroundVariant.Dots} gap={gridSize} size={1} />
      <Panel position="top-right">
        <ToolbarControls />
      </Panel>

      <!-- Capture SvelteFlow's internal store (getContext only works during component init) -->
      <StoreCapture onstore={(s) => { sfRefs.store = s; }} />

      {#if showMiniMap}
        <MiniMap
          nodeColor="var(--ic-muted)"
          nodeStrokeColor="var(--ic-foreground)"
          maskColor="rgba(0, 0, 0, 0.08)"
          position="bottom-left"
        />
      {/if}
    </SvelteFlow>
  </div>

  {#if ctxMenu}
    <ContextMenu
      entries={ctxMenu.entries}
      x={ctxMenu.x}
      y={ctxMenu.y}
      onaction={handleCtxAction}
      onclose={closeCtxMenu}
    />
  {/if}
</div>

<!--
  ToolbarControls — must be a child of SvelteFlow to access useSvelteFlow().
  Renders built-in viewport controls.
-->
{#snippet ToolbarControls()}
  {@const flow = (() => { const f = useSvelteFlow(); sfRefs.flow = f; return f; })()}
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
    <div class="ic-ne__control-sep"></div>
    <button
      class="ic-ne__control-btn"
      title="Auto layout"
      onclick={() => runDagreLayout(layout)}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="8" y="14" width="7" height="7" rx="1" />
        <path d="M6.5 10v2a2 2 0 002 2h1m8-4v2a2 2 0 01-2 2h-1" />
      </svg>
    </button>
    <button
      class="ic-ne__control-btn"
      class:ic-ne__control-btn--active={snapToGrid}
      title={snapToGrid ? 'Disable snap to grid' : 'Enable snap to grid'}
      onclick={() => { snapToGrid = !snapToGrid; }}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="m12 15 4 4" />
        <path d="M2.352 10.648a1.205 1.205 0 0 0 0 1.704l2.296 2.296a1.205 1.205 0 0 0 1.704 0l6.029-6.029a1 1 0 1 1 3 3l-6.029 6.029a1.205 1.205 0 0 0 0 1.704l2.296 2.296a1.205 1.205 0 0 0 1.704 0l6.365-6.367A1 1 0 0 0 8.716 4.282z" />
        <path d="m5 8 4 4" />
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

  .ic-ne__control-btn--active {
    background: var(--ic-muted);
    color: var(--ic-primary);
  }

  .ic-ne__control-sep {
    width: 1px;
    height: 16px;
    background: var(--ic-border);
    margin: 0 2px;
    flex-shrink: 0;
  }

  /* ── MiniMap ─── */
  .ic-ne :global(.svelte-flow__minimap) {
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

</style>
