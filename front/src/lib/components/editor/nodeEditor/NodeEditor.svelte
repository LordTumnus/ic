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
  import { EDGE_TYPE_MAP, setPlaying, setSpeed, registerFeedbackLoop, unregisterFeedbackLoop, getFeedbackLoopIds, feedbackFnName } from '$lib/utils/edge-utils';
  import dagre from '@dagrejs/dagre';
  import logger from '$lib/core/logger';
  import ContextMenu from '$lib/components/shared/ContextMenu.svelte';
  import type { ContextMenuEntry } from '$lib/utils/context-menu-types';
  import StoreCapture from './StoreCapture.svelte';

  // Node type components — one per concrete MATLAB class
  import TransformNode from './nodes/TransformNode.svelte';
  import GroupNode from './nodes/GroupNode.svelte';
  import CollapsibleGroupNode from './nodes/CollapsibleGroupNode.svelte';
  import InputNode from './nodes/InputNode.svelte';
  import OutputNode from './nodes/OutputNode.svelte';
  import ConstantNode from './nodes/ConstantNode.svelte';
  import ClockNode from './nodes/ClockNode.svelte';
  import SignalNode from './nodes/SignalNode.svelte';
  import RandomNode from './nodes/RandomNode.svelte';
  import DisplayNode from './nodes/DisplayNode.svelte';
  import MeterNode from './nodes/MeterNode.svelte';
  import LoggerNode from './nodes/LoggerNode.svelte';
  import GainNode from './nodes/GainNode.svelte';
  import DelayNode from './nodes/DelayNode.svelte';
  import SwitchNode from './nodes/SwitchNode.svelte';
  import MuxNode from './nodes/MuxNode.svelte';
  import DemuxNode from './nodes/DemuxNode.svelte';
  import AccumulatorNode from './nodes/AccumulatorNode.svelte';
  import NoteNode from './nodes/NoteNode.svelte';
  import FunctionNode from './nodes/FunctionNode.svelte';
  import ProcessNode from './nodes/ProcessNode.svelte';
  import DecisionNode from './nodes/DecisionNode.svelte';
  import TerminatorNode from './nodes/TerminatorNode.svelte';
  import DatabaseNode from './nodes/DatabaseNode.svelte';
  import CloudNode from './nodes/CloudNode.svelte';
  import DocumentNode from './nodes/DocumentNode.svelte';
  import QueueNode from './nodes/QueueNode.svelte';
  import ActorNode from './nodes/ActorNode.svelte';
  import IconBoxNode from './nodes/IconBoxNode.svelte';
  import ClassNodeComponent from './nodes/ClassNode.svelte';

  // Unified edge renderer — switches rendering mode based on data.type
  import EdgeRenderer from './edges/EdgeRenderer.svelte';

  const OK: Resolution = { success: true, data: null };

  let {
    height = $bindable('100%'),
    gridSize = $bindable(20),
    edgeGeometry = $bindable('bezier'),
    showMiniMap = $bindable(false),
    layout = $bindable('horizontal'),
    snapToGrid = $bindable(false),
    gridVariant: gridVariantProp = $bindable('dots'),
    playing: playingProp = $bindable(true),
    playSpeed = $bindable(1),
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
    gridVariant?: string;
    playing?: boolean;
    playSpeed?: number;
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

  // -- Global clock: sync MATLAB props → animation coordinator ----------------
  $effect(() => { setPlaying(playingProp); });
  $effect(() => { setSpeed(playSpeed); });

  // -- Snap grid: when enabled, nodes snap to gridSize intervals ---------------
  const snapGrid = $derived<[number, number] | undefined>(
    snapToGrid ? [gridSize, gridSize] : undefined,
  );

  // -- Background variant: map MATLAB string → SvelteFlow enum ----------------
  const BG_VARIANT_MAP: Record<string, BackgroundVariant> = {
    dots: BackgroundVariant.Dots,
    lines: BackgroundVariant.Lines,
    cross: BackgroundVariant.Cross,
  };
  const bgVariant = $derived(
    BG_VARIANT_MAP[gridVariantProp] ?? BackgroundVariant.Dots,
  );

  // -- Node type registry: MATLAB class name → Svelte Flow component ----------

  const nodeTypes = {
    'ic.node.Transform': TransformNode,
    'ic.node.BasicGroup': GroupNode,
    'ic.node.CollapsibleGroup': CollapsibleGroupNode,
    'ic.node.Input': InputNode,
    'ic.node.Output': OutputNode,
    'ic.node.Constant': ConstantNode,
    'ic.node.Clock': ClockNode,
    'ic.node.Signal': SignalNode,
    'ic.node.Random': RandomNode,
    'ic.node.Display': DisplayNode,
    'ic.node.Meter': MeterNode,
    'ic.node.Logger': LoggerNode,
    'ic.node.Gain': GainNode,
    'ic.node.Delay': DelayNode,
    'ic.node.Switch': SwitchNode,
    'ic.node.Mux': MuxNode,
    'ic.node.Demux': DemuxNode,
    'ic.node.Accumulator': AccumulatorNode,
    'ic.node.Note': NoteNode,
    'ic.node.Function': FunctionNode,
    'ic.node.Process': ProcessNode,
    'ic.node.Decision': DecisionNode,
    'ic.node.Terminator': TerminatorNode,
    'ic.node.Database': DatabaseNode,
    'ic.node.Cloud': CloudNode,
    'ic.node.Document': DocumentNode,
    'ic.node.Queue': QueueNode,
    'ic.node.Actor': ActorNode,
    'ic.node.IconBox': IconBoxNode,
    'ic.node.ClassNode': ClassNodeComponent,
  } as Record<string, any>;

  // -- Edge type registry: SvelteFlow edge type key → Svelte component --------

  const edgeTypes = {
    default: EdgeRenderer,
  } as Record<string, any>;

  // -- Node type constants (used throughout for type-checks) ------------------

  const TRANSFORM_TYPE = 'ic.node.Transform';
  const GROUP_TYPES = new Set(['ic.node.BasicGroup', 'ic.node.CollapsibleGroup']);
  const INPUT_TYPE = 'ic.node.Input';
  const OUTPUT_TYPE = 'ic.node.Output';
  const CONSTANT_TYPE = 'ic.node.Constant';
  const CLOCK_TYPE = 'ic.node.Clock';
  const SIGNAL_TYPE = 'ic.node.Signal';
  const RANDOM_TYPE = 'ic.node.Random';
  const DISPLAY_TYPE = 'ic.node.Display';
  const METER_TYPE = 'ic.node.Meter';
  const LOGGER_TYPE = 'ic.node.Logger';
  const GAIN_TYPE = 'ic.node.Gain';
  const DELAY_TYPE = 'ic.node.Delay';
  const SWITCH_TYPE = 'ic.node.Switch';
  const MUX_TYPE = 'ic.node.Mux';
  const DEMUX_TYPE = 'ic.node.Demux';
  const ACCUMULATOR_TYPE = 'ic.node.Accumulator';
  const NOTE_TYPE = 'ic.node.Note';
  const FUNCTION_TYPE = 'ic.node.Function';
  const PROCESS_TYPE = 'ic.node.Process';
  const DECISION_TYPE = 'ic.node.Decision';
  const TERMINATOR_TYPE = 'ic.node.Terminator';
  const DATABASE_TYPE = 'ic.node.Database';
  const CLOUD_TYPE = 'ic.node.Cloud';
  const DOCUMENT_TYPE = 'ic.node.Document';
  const QUEUE_TYPE = 'ic.node.Queue';
  const ACTOR_TYPE = 'ic.node.Actor';
  const ICONBOX_TYPE = 'ic.node.IconBox';
  const CLASSNODE_TYPE = 'ic.node.ClassNode';
  const CLASSICAL_TYPES = new Set([PROCESS_TYPE, DECISION_TYPE, TERMINATOR_TYPE, DATABASE_TYPE, CLOUD_TYPE, DOCUMENT_TYPE, QUEUE_TYPE, ACTOR_TYPE, ICONBOX_TYPE, CLASSNODE_TYPE]);
  const SINK_TYPES = new Set([DISPLAY_TYPE, METER_TYPE, LOGGER_TYPE]);

  function isGroupType(type: string | undefined) {
    return type ? GROUP_TYPES.has(type) : false;
  }

  function isProcessorType(type: string | undefined): boolean {
    return type === GAIN_TYPE || type === DELAY_TYPE || type === SWITCH_TYPE || type === ACCUMULATOR_TYPE || type === TRANSFORM_TYPE || type === FUNCTION_TYPE;
  }

  // -- Svelte Flow state ------------------------------------------------------

  let flowNodes: FlowNode[] = $state.raw([]);
  let flowEdges: FlowEdge[] = $state.raw([]);

  // IDs of nodes hidden due to group collapse — used to hide connected edges
  let hiddenNodeIds: Set<string> = $state.raw(new Set());

  // IDs of nodes eagerly deleted by SF (before MATLAB confirms removal).
  // Prevents $effect.pre from re-adding them from stale nodeStates.
  let pendingDeleteIds: Set<string> = $state.raw(new Set());

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
        accentColor: (p.accentColor as string) ?? '',
        icon: p.icon ?? null,
        width: (p.width as number) ?? 400,
        height: (p.height as number) ?? 300,
        collapsed: (p.collapsed as boolean) ?? false,
        resizable: (p.resizable as boolean) ?? true,
        backgroundColor: (p.backgroundColor as string) ?? '',
        backgroundOpacity: (p.backgroundOpacity as number) ?? 0,
        outlineColor: (p.outlineColor as string) ?? '',
        value: p.value ?? '0',
        // Clock props
        interval: (p.interval as number) ?? 1,
        unit: (p.unit as string) ?? 's',
        animated: (p.animated as boolean) ?? true,
        // Signal props (expression already extracted above)
        frequency: (p.frequency as number) ?? 1,
        previewTime: (p.previewTime as number) ?? 2,
        // Random props
        profile: (p.profile as string) ?? 'white',
        // Display / Mux / Accumulator props
        inputNumber: (p.inputNumber as number) ?? 1,
        // Demux props
        outputNumber: (p.outputNumber as number) ?? 2,
        // Meter props
        min: (p.min as number) ?? 0,
        max: (p.max as number) ?? 100,
        meterUnit: (p.unit as string) ?? '',
        // Logger props
        maxLines: (p.maxLines as number) ?? 100,
        logEntries: Array.isArray(p.logEntries) ? (p.logEntries as string[]) : (p.logEntries ? [p.logEntries as string] : []),
        // Gain props
        factor: (p.factor as number) ?? 1,
        // Delay props
        delayTime: (p.delayTime as number) ?? 1,
        // Note props
        content: (p.content as string) ?? '',
        // ClassNode props
        propertyList: Array.isArray(p.propertyList) ? (p.propertyList as string[]) : [],
        methodList: Array.isArray(p.methodList) ? (p.methodList as string[]) : [],
        eventList: Array.isArray(p.eventList) ? (p.eventList as string[]) : [],
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
  // Group boundary INPUT ports also act as sources for interior ":int" edges,
  // so we add them with the ":int" suffix key (matching edge sourcePortName).
  const portBehaviorMap = $derived.by(() => {
    const map = new Map<string, PortDef>();
    for (const ns of nodeStates) {
      for (const p of ns.data.outputs) map.set(`${ns.data.id}:${p.name}`, p);
      if (isGroupType(ns.data.type)) {
        for (const p of ns.data.inputs) map.set(`${ns.data.id}:${p.name}:int`, p);
      }
    }
    return map;
  });

  // Build lookup: targetNodeId → incoming signal info from connected edges.
  // Used by sink nodes (Display, Meter) to visualize data from connected sources.
  interface InputSignal {
    sourceNodeId: string;
    portName: string;
    expression: string;
    frequency: number;
    speed: number;
    outputRate: number;
    timeOffset: number;
    type: string;
  }

  const inputSignalMap = $derived.by(() => {
    const map = new Map<string, InputSignal[]>();
    for (const edge of childEntries['edges'] ?? []) {
      const p = edge.props;
      const srcPort = portBehaviorMap.get(`${p.sourceNodeId}:${p.sourcePortName}`);
      if (!srcPort) continue;
      const targetId = p.targetNodeId as string;
      if (!map.has(targetId)) map.set(targetId, []);
      map.get(targetId)!.push({
        sourceNodeId: (p.sourceNodeId as string) || '',
        portName: (p.targetPortName as string) || '',
        expression: srcPort.expression,
        frequency: srcPort.frequency,
        speed: srcPort.speed,
        outputRate: srcPort.outputRate,
        timeOffset: srcPort.timeOffset,
        type: srcPort.type,
      });
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
    const sigMap = inputSignalMap; // track as dependency so effect re-runs on edge changes
    const pending = untrack(() => pendingDeleteIds);
    const existing = new Map(untrack(() => flowNodes).map((n) => [n.id, n]));
    let changed = false;

    // Clear pending deletes that MATLAB has now confirmed (no longer in states)
    if (pending.size > 0) {
      const stateIds = new Set(states.map((s) => s.data.id));
      const stillPending = new Set([...pending].filter((id) => stateIds.has(id)));
      if (stillPending.size !== pending.size) {
        pendingDeleteIds = stillPending;
      }
    }

    // Pre-compute collapsed group IDs so child hidden state can be checked
    // even when the child's own data reference hasn't changed.
    const collapsedGroups = new Set(
      states
        .filter((s) => isGroupType(s.data.type) && s.data.collapsed)
        .map((s) => s.data.id),
    );

    // Filter out nodes that are eagerly deleted but not yet removed by MATLAB
    const activeStates = pending.size > 0
      ? states.filter((ns) => !pending.has(ns.data.id))
      : states;

    const mapped = activeStates.map((ns) => {
      const d = ns.data;
      const prev = existing.get(d.id);

      // $derived returns the same object when dependencies haven't changed.
      // Reuse previous FlowNode to prevent SvelteFlow's adoptUserNodes from
      // re-processing it (which can wipe handleBounds before measurement).
      if (prev && (prev as any).__nsData === d) {
        // Check if inputSignals changed (edge added/removed to this node)
        const newSignals = sigMap.get(d.id) ?? [];
        const oldSignals = (prev as any).__signals;
        if (newSignals !== oldSignals) {
          changed = true;
          const updated = { ...prev, data: { ...prev.data, inputSignals: newSignals } };
          (updated as any).__nsData = d;
          (updated as any).__signals = newSignals;
          return updated;
        }
        // Even when reusing, update hidden state for children of groups
        // whose collapsed state may have changed.
        if (d.parentNodeId) {
          const shouldHide = collapsedGroups.has(d.parentNodeId);
          if ((prev.hidden ?? false) !== shouldHide) {
            changed = true;
            return { ...prev, hidden: shouldHide };
          }
        }
        return prev;
      }

      changed = true;
      const node: any = {
        id: d.id,
        type: d.type,
        position: { x: d.position[0], y: d.position[1] },
        data: {
          label: d.label,
          expression: d.expression,
          color: d.color,
          accentColor: d.accentColor,
          icon: d.icon,
          disabled: d.disabled,
          locked: d.locked,
          inputs: d.inputs,
          outputs: d.outputs,
          // Group-specific (ignored by non-group node components)
          width: d.width,
          height: d.height,
          collapsed: d.collapsed,
          resizable: d.resizable,
          backgroundColor: d.backgroundColor,
          backgroundOpacity: d.backgroundOpacity,
          outlineColor: d.outlineColor,
          value: d.value,
          interval: d.interval,
          unit: d.unit,
          animated: d.animated,
          frequency: d.frequency,
          previewTime: d.previewTime,
          profile: d.profile,
          inputNumber: d.inputNumber,
          min: d.min,
          max: d.max,
          meterUnit: d.meterUnit,
          maxLines: d.maxLines,
          logEntries: d.logEntries,
          factor: d.factor,
          delayTime: d.delayTime,
          outputNumber: d.outputNumber,
          content: d.content,
          propertyList: d.propertyList,
          methodList: d.methodList,
          eventList: d.eventList,
          inputSignals: sigMap.get(d.id) ?? [],
          onGroupResize: handleGroupResize,
          onGroupCollapse: handleGroupCollapse,
          onNodeResize: handleNodeResize,
          onpropchange: (prop: string, value: unknown) => handleNodePropChange(d.id, prop, value),
        },
      };
      if (d.parentNodeId) {
        node.parentId = d.parentNodeId;
        node.extent = 'parent';
        if (collapsedGroups.has(d.parentNodeId)) node.hidden = true;
      }
      // Group nodes need explicit dimensions and low zIndex
      if (isGroupType(d.type)) {
        const h = d.collapsed ? groupCollapsedH(d) : d.height;
        node.style = `width: ${d.width}px; height: ${h}px;`;
        node.zIndex = -1;
      }
      // Note nodes need explicit dimensions from MATLAB
      if (d.type === NOTE_TYPE) {
        node.style = `width: ${d.width}px; height: ${d.height}px;`;
      }
      // Restore user-resized dimensions for non-group nodes
      const dims = resizedNodeDims.get(d.id);
      if (dims && !isGroupType(d.type)) {
        node.style = `width: ${dims.width}px; height: ${dims.height}px;`;
      }
      if (d.locked) node.draggable = false;
      node.__nsData = d;
      node.__signals = sigMap.get(d.id) ?? [];
      return node;
    });

    // SvelteFlow requires parent nodes before children in the array.
    // Sort so nodes without parentId come first (stable sort preserves
    // relative order within each group).
    mapped.sort((a, b) => {
      const aChild = a.parentId ? 1 : 0;
      const bChild = b.parentId ? 1 : 0;
      return aChild - bChild;
    });

    // Track which nodes are hidden (children of collapsed groups)
    const newHidden = new Set(mapped.filter((n) => n.hidden).map((n) => n.id));
    const oldHidden = untrack(() => hiddenNodeIds);
    if (newHidden.size !== oldHidden.size || [...newHidden].some((id) => !oldHidden.has(id))) {
      hiddenNodeIds = newHidden;
    }

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
        // Override edge type when source port has been promoted by cascade
        if (srcPort.type === 'signal' || srcPort.type === 'flow') {
          data.type = srcPort.type;
          data.animated = data.animated ?? true;
        }
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

    // Apply hidden flag to edges where BOTH endpoints are hidden
    // (internal to a collapsed group). Cross-boundary edges stay visible.
    const hidden = untrack(() => hiddenNodeIds);
    const merged = [...matlab, ...sfOnly].map((e) => {
      const anyHidden = hidden.has(e.source) || hidden.has(e.target);
      return anyHidden ? { ...e, hidden: true } : e;
    });
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
        const visibleEdges = current.filter(e => !e.hidden);
        const domEdges = document.querySelectorAll('.svelte-flow__edge').length;
        if (domEdges < visibleEdges.length) {
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

  // -- Processor cascade: keep processor output ports in sync with inputs ------
  //
  // When a processor node's input signal changes (edge connected/disconnected,
  // upstream expression changed), recalculate its output port expression.
  // This is the reactive equivalent of MATLAB's onPortEdgeChanged → syncOutput.
  //
  // Uses a cache to avoid infinite loops: only calls updatePortProp when the
  // computed expression actually differs from the last one we set.

  // Cache key encodes both expression and timeOffset so we detect changes to either.
  const processorOutputCache = new Map<string, string>();

  /**
   * Detect cycles and return a Map of back-edge keys → source Delay node IDs.
   * Key: "targetNodeId:targetPortName", Value: source Delay node ID (or "" for non-Delay breaks).
   * The Delay ID is used by the cascade to register feedback buffers.
   */
  function findCycleSkips(
    states: NodeState[],
    edges: ChildEntry[],
  ): Map<string, string> {
    const procNodes = states.filter((ns) => isProcessorType(ns.data.type));
    const procIds = new Set(procNodes.map((ns) => ns.data.id));
    if (procIds.size === 0) return new Map();

    // Build adjacency + in-degree for processor subgraph
    const adj = new Map<string, string[]>();
    const inDeg = new Map<string, number>();
    for (const id of procIds) {
      adj.set(id, []);
      inDeg.set(id, 0);
    }
    for (const e of edges) {
      const src = e.props.sourceNodeId as string;
      const tgt = e.props.targetNodeId as string;
      if (procIds.has(src) && procIds.has(tgt)) {
        adj.get(src)!.push(tgt);
        inDeg.set(tgt, (inDeg.get(tgt) ?? 0) + 1);
      }
    }

    // Kahn's topological sort — nodes remaining are in cycles
    const queue: string[] = [];
    for (const [id, d] of inDeg) {
      if (d === 0) queue.push(id);
    }
    const sorted = new Set<string>();
    while (queue.length > 0) {
      const id = queue.shift()!;
      sorted.add(id);
      for (const next of adj.get(id) ?? []) {
        const nd = (inDeg.get(next) ?? 1) - 1;
        inDeg.set(next, nd);
        if (nd === 0) queue.push(next);
      }
    }

    const cycleIds = new Set([...procIds].filter((id) => !sorted.has(id)));
    if (cycleIds.size === 0) return new Map();

    const skips = new Map<string, string>();
    const nodeTypeMap = new Map(procNodes.map((ns) => [ns.data.id, ns.data.type]));

    // Map back-edges FROM Delay nodes → Delay node ID
    for (const e of edges) {
      const src = e.props.sourceNodeId as string;
      const tgt = e.props.targetNodeId as string;
      if (!cycleIds.has(src) || !cycleIds.has(tgt)) continue;
      if (nodeTypeMap.get(src) === DELAY_TYPE) {
        skips.set(`${tgt}:${e.props.targetPortName}`, src);
      }
    }

    // If no Delay in cycle, break at an arbitrary edge
    if (skips.size === 0) {
      for (const e of edges) {
        const src = e.props.sourceNodeId as string;
        const tgt = e.props.targetNodeId as string;
        if (cycleIds.has(src) && cycleIds.has(tgt)) {
          skips.set(`${tgt}:${e.props.targetPortName}`, '');
          break;
        }
      }
    }

    return skips;
  }

  // Cascade depth limiter: prevents infinite re-triggers.
  let cascadeDepth = 0;
  let cascadeResetTimer: ReturnType<typeof setTimeout> | null = null;

  $effect(() => {
    const sigMap = inputSignalMap; // reactive dependency
    const states = nodeStates;    // reactive dependency
    const edgeEntries = childEntries['edges'] ?? [];

    // Cap cascade depth — reset after effects settle
    cascadeDepth++;
    if (cascadeResetTimer !== null) clearTimeout(cascadeResetTimer);
    cascadeResetTimer = setTimeout(() => { cascadeDepth = 0; cascadeResetTimer = null; }, 0);
    const processorCount = states.filter((ns) => isProcessorType(ns.data.type)).length;
    if (cascadeDepth > processorCount + 3) return;

    // Detect cycles and build skip set for back-edges
    const cycleSkips = findCycleSkips(states, edgeEntries);

    // Cleanup feedback buffers for loops that no longer exist
    const activeDelayIds = new Set(cycleSkips.values());
    for (const existingId of getFeedbackLoopIds()) {
      if (!activeDelayIds.has(existingId)) {
        unregisterFeedbackLoop(existingId);
      }
    }

    for (const ns of states) {
      const d = ns.data;
      if (!isProcessorType(d.type)) continue;

      // Filter out signals from cycle back-edges (non-Delay breaks only).
      // Delay-backed feedback edges are handled specially per node type.
      const rawSigs = sigMap.get(d.id) ?? [];
      const sigs = cycleSkips.size > 0
        ? rawSigs.filter((s: InputSignal) => !cycleSkips.has(`${d.id}:${s.portName}`))
        : rawSigs;
      const sigInput = sigs.find((s: InputSignal) => s.type === 'signal');
      const flowInput = sigs.find((s: InputSignal) => s.type === 'flow');

      let expectedExpr: string | null = null;
      let expectedType: string = 'static';
      let expectedTimeOffset: number = 0;
      let expectedSpeed: number | null = null;

      // --- Transform: N paired in→out channels, apply expression to each ---
      if (d.type === TRANSFORM_TYPE) {
        const transformExpr = d.expression || '';
        const numPorts = d.inputNumber ?? 1;
        const perPortKeys: string[] = [];

        for (let p = 1; p <= numPorts; p++) {
          const portName = `in${p}`;
          const outName = `out${p}`;
          const sig = sigs.find((s: InputSignal) => s.portName === portName);

          let portExpr: string | null = null;
          let portSpeed: number = 1;

          if (sig) {
            if (sig.type === 'signal') {
              portExpr = sig.expression || '0';
              portSpeed = sig.speed ?? 1;
            } else if (sig.type === 'flow') {
              const r = sig.outputRate ?? 1;
              const o = sig.timeOffset ?? 0;
              portExpr = o > 0 ? `pulse((t-${o})*${r},0.05)` : `pulse(t*${r},0.05)`;
              portSpeed = sig.speed ?? 1;
            }
          }

          if (portExpr) {
            const outExpr = transformExpr
              ? transformExpr.replace(/(?<![a-zA-Z_])x(?![a-zA-Z_0-9])/g, `(${portExpr})`)
              : portExpr;
            perPortKeys.push(`${outName}:signal|${outExpr}|${portSpeed}`);
          } else {
            perPortKeys.push(`${outName}:static`);
          }
        }

        const cacheKey = perPortKeys.join('||');
        const cached = processorOutputCache.get(d.id);
        if (cached !== cacheKey) {
          processorOutputCache.set(d.id, cacheKey);
          untrack(() => {
            for (let p = 1; p <= numPorts; p++) {
              const portName = `in${p}`;
              const outName = `out${p}`;
              const sig = sigs.find((s: InputSignal) => s.portName === portName);
              let portExpr: string | null = null;
              let portSpeed: number = 1;
              if (sig) {
                if (sig.type === 'signal') {
                  portExpr = sig.expression || '0';
                  portSpeed = sig.speed ?? 1;
                } else if (sig.type === 'flow') {
                  const r = sig.outputRate ?? 1;
                  const o = sig.timeOffset ?? 0;
                  portExpr = o > 0 ? `pulse((t-${o})*${r},0.05)` : `pulse(t*${r},0.05)`;
                  portSpeed = sig.speed ?? 1;
                }
              }
              if (portExpr) {
                const outExpr = transformExpr
                  ? transformExpr.replace(/(?<![a-zA-Z_])x(?![a-zA-Z_0-9])/g, `(${portExpr})`)
                  : portExpr;
                updatePortProp(d.id, outName, 'output', 'expression', outExpr);
                updatePortProp(d.id, outName, 'output', 'type', 'signal');
                updatePortProp(d.id, outName, 'output', 'speed', portSpeed);
              } else {
                updatePortProp(d.id, outName, 'output', 'type', 'static');
                updatePortProp(d.id, outName, 'output', 'expression', '0');
              }
            }
          });
        }
        continue; // Skip the single-output logic below
      }

      // --- Function: combine N inputs via expression referencing in1, in2, ... ---
      // Feedback-aware: if a Delay back-edge feeds one of the inputs, we
      // register a SignalBuffer and use __fb_{delayId}(t) as the output
      // expression so the edge renderer reads from the IIR buffer.
      if (d.type === FUNCTION_TYPE) {
        let fnExpr = d.expression || '';
        let combinerExpr = d.expression || ''; // version with __prev__ for buffer
        let hasAnyInput = false;
        let hasFeedback = false;
        let feedbackDelayId = '';
        let maxSpd = 1;
        let fbFrequency = 2;

        const resolveInput = (sig: InputSignal | undefined): string | null => {
          if (!sig) return null;
          if (sig.type === 'signal') return sig.expression || '0';
          if (sig.type === 'flow') {
            const r = sig.outputRate ?? 1;
            const o = sig.timeOffset ?? 0;
            return o > 0 ? `pulse((t-${o})*${r},0.05)` : `pulse(t*${r},0.05)`;
          }
          return null;
        };

        const numInputs = d.inputNumber ?? 2;
        // Also look at rawSigs for feedback signals that were filtered out
        for (let p = 1; p <= numInputs; p++) {
          const varName = `in${p}`;
          const varRegex = new RegExp(`(?<![a-zA-Z_])${varName}(?![a-zA-Z_0-9])`, 'g');

          // Check if this port is a feedback back-edge
          const skipKey = `${d.id}:${varName}`;
          const delayId = cycleSkips.get(skipKey);

          if (delayId) {
            // This input is the feedback path from a Delay node
            hasFeedback = true;
            feedbackDelayId = delayId;
            // In combiner expr, replace feedback var with __prev__
            combinerExpr = combinerExpr.replace(varRegex, '__prev__');
            // In display expr, replace with buffer read function
            fnExpr = fnExpr.replace(varRegex, `${feedbackFnName(delayId)}(t)`);
          } else {
            // Normal forward input
            const sig = sigs.find((s: InputSignal) => s.portName === varName);
            const inputExpr = resolveInput(sig);

            if (inputExpr) {
              hasAnyInput = true;
              maxSpd = Math.max(maxSpd, sig!.speed ?? 1);
              fbFrequency = sig!.frequency ?? 2;
              fnExpr = fnExpr.replace(varRegex, `(${inputExpr})`);
              combinerExpr = combinerExpr.replace(varRegex, `(${inputExpr})`);
            } else {
              fnExpr = fnExpr.replace(varRegex, '0');
              combinerExpr = combinerExpr.replace(varRegex, '0');
            }
          }
        }

        // Register or update feedback buffer when we have a feedback loop
        if (hasFeedback && hasAnyInput && feedbackDelayId) {
          // Get Delay node's time and convert to t-units
          const delayNode = states.find((ns) => ns.data.id === feedbackDelayId);
          const delayTime = (delayNode?.data.delayTime as number) ?? 50;
          const delayUnit = String(delayNode?.data.unit ?? 'ms');
          const delaySec = delayUnit === 'ms' ? delayTime / 1000 : delayTime;
          // Convert real seconds to t-units: t advances at BASE_SPEED * speed per second
          const delayT = delaySec * 0.5 * maxSpd;
          registerFeedbackLoop(feedbackDelayId, combinerExpr, maxSpd, fbFrequency, delayT);
          // Output expression reads from the feedback buffer
          expectedExpr = `${feedbackFnName(feedbackDelayId)}(t)`;
          expectedType = 'signal';
          expectedSpeed = maxSpd;
        } else if (hasAnyInput && fnExpr) {
          expectedExpr = fnExpr;
          expectedType = 'signal';
          expectedSpeed = maxSpd;
        }
      }

      // --- Accumulator: sum ALL inputs ---
      if (d.type === ACCUMULATOR_TYPE) {
        const terms: string[] = [];
        let maxSpd = 1;
        for (const s of sigs) {
          if (s.type === 'signal') {
            terms.push(`(${s.expression})`);
            maxSpd = Math.max(maxSpd, s.speed ?? 1);
          } else if (s.type === 'flow') {
            const r = s.outputRate ?? 1;
            const o = s.timeOffset ?? 0;
            terms.push(o > 0 ? `pulse((t-${o})*${r},0.05)` : `pulse(t*${r},0.05)`);
            maxSpd = Math.max(maxSpd, s.speed ?? 1);
          }
        }
        if (terms.length > 0) {
          expectedExpr = terms.join('+');
          expectedType = 'signal';
          expectedSpeed = maxSpd;
        }
      } else if (d.type === SWITCH_TYPE) {
        // --- Switch: select between in1 and in2 based on ctrl ---
        const ctrlSig = sigs.find((s: InputSignal) => s.portName === 'ctrl');
        const in1Sig = sigs.find((s: InputSignal) => s.portName === 'in1');
        const in2Sig = sigs.find((s: InputSignal) => s.portName === 'in2');

        // Build ctrl expression
        let ctrlExpr: string | null = null;
        if (ctrlSig) {
          if (ctrlSig.type === 'signal') {
            ctrlExpr = ctrlSig.expression || '0';
          } else if (ctrlSig.type === 'flow') {
            const r = ctrlSig.outputRate ?? 1;
            const o = ctrlSig.timeOffset ?? 0;
            ctrlExpr = o > 0 ? `pulse((t-${o})*${r},0.05)` : `pulse(t*${r},0.05)`;
          }
        }

        // Helper: resolve an input signal to an expression string
        const resolveInput = (sig: InputSignal | undefined): string | null => {
          if (!sig) return null;
          if (sig.type === 'signal') return sig.expression || '0';
          if (sig.type === 'flow') {
            const r = sig.outputRate ?? 1;
            const o = sig.timeOffset ?? 0;
            return o > 0 ? `pulse((t-${o})*${r},0.05)` : `pulse(t*${r},0.05)`;
          }
          return null;
        };

        const in1Expr = resolveInput(in1Sig);
        const in2Expr = resolveInput(in2Sig);

        // Build output: sel(ctrl, in1, in2)
        if (ctrlExpr && in1Expr && in2Expr) {
          expectedExpr = `sel(${ctrlExpr},${in1Expr},${in2Expr})`;
          expectedType = 'signal';
        } else if (ctrlExpr && in1Expr) {
          expectedExpr = `sel(${ctrlExpr},${in1Expr},0)`;
          expectedType = 'signal';
        } else if (ctrlExpr && in2Expr) {
          expectedExpr = `sel(${ctrlExpr},0,${in2Expr})`;
          expectedType = 'signal';
        } else if (in1Expr) {
          expectedExpr = in1Expr;
          expectedType = 'signal';
        } else if (in2Expr) {
          expectedExpr = in2Expr;
          expectedType = 'signal';
        }

        // Pick the fastest speed from all inputs
        let maxSpd = 1;
        for (const s of [ctrlSig, in1Sig, in2Sig]) {
          if (s) maxSpd = Math.max(maxSpd, s.speed ?? 1);
        }
        expectedSpeed = maxSpd;
      } else {
        // --- Single-input processors: Gain, Delay ---
        // Resolve the effective input expression: signal edges pass through directly,
        // flow edges are converted to a narrow impulse: pulse(t * rate, 0.05)
        let inputExpr: string | null = null;
        if (sigInput) {
          inputExpr = sigInput.expression;
        } else if (flowInput && d.type === GAIN_TYPE) {
          // Flow → signal conversion: impulse train
          const rate = flowInput.outputRate ?? 1;
          const offset = flowInput.timeOffset ?? 0;
          const speed = flowInput.speed ?? 1;
          inputExpr = offset > 0
            ? `pulse((t-${offset})*${rate},0.05)`
            : `pulse(t*${rate},0.05)`;
          expectedSpeed = speed;
        }

        if (inputExpr) {
          if (d.type === GAIN_TYPE) {
            const factor = d.factor ?? 1;
            expectedExpr = `(${factor})*(${inputExpr})`;
          } else if (d.type === DELAY_TYPE) {
            const dt = Number(d.delayTime ?? 1);
            const unit = String(d.unit ?? 's');
            const delaySec = unit === 'ms' ? dt / 1000 : dt;
            expectedExpr = inputExpr.replace(
              /(?<![a-zA-Z_])t(?![a-zA-Z_0-9])/g, `(t-${delaySec})`,
            );
          }
          if (expectedExpr) expectedType = 'signal';
        } else if (flowInput && d.type === DELAY_TYPE) {
          // Flow through Delay — stay flow, shift timeOffset
          const dt = Number(d.delayTime ?? 1);
          const unit = String(d.unit ?? 's');
          const delaySec = unit === 'ms' ? dt / 1000 : dt;
          expectedType = 'flow';
          expectedTimeOffset = (flowInput.timeOffset ?? 0) + delaySec;
        }
      }

      // Cache key encodes all output state
      const cacheKey = `${expectedType}|${expectedExpr}|${expectedTimeOffset}|${expectedSpeed}`;
      const cached = processorOutputCache.get(d.id);
      if (cached !== cacheKey) {
        processorOutputCache.set(d.id, cacheKey);
        untrack(() => {
          if (expectedType === 'signal' && expectedExpr) {
            updatePortProp(d.id, 'out', 'output', 'expression', expectedExpr);
            updatePortProp(d.id, 'out', 'output', 'type', 'signal');
            if (expectedSpeed !== null) {
              updatePortProp(d.id, 'out', 'output', 'speed', expectedSpeed);
            }
          } else if (expectedType === 'flow') {
            updatePortProp(d.id, 'out', 'output', 'type', 'flow');
            updatePortProp(d.id, 'out', 'output', 'outputRate', flowInput!.outputRate);
            updatePortProp(d.id, 'out', 'output', 'speed', flowInput!.speed);
            updatePortProp(d.id, 'out', 'output', 'timeOffset', expectedTimeOffset);
          } else {
            updatePortProp(d.id, 'out', 'output', 'type', 'static');
            updatePortProp(d.id, 'out', 'output', 'expression', '0');
          }
        });
      }
    }
  });

  // -- Group: helpers ----------------------------------------------------------

  /** Collapsed height for a group — grows with port count. */
  function groupCollapsedH(d?: any): number {
    const maxPorts = Math.max(d?.inputs?.length ?? 0, d?.outputs?.length ?? 0);
    if (maxPorts === 0) return 30;
    return 30 + maxPorts * 24 + 20;
  }

  // -- Group: resize and collapse handlers ------------------------------------

  function handleGroupResize(nodeId: string, width: number, height: number, x: number, y: number) {
    // Write back to MATLAB childEntries (dimensions + position)
    const entries = childEntries['nodes'] ?? [];
    const entry = entries.find((c) => c.id === nodeId);
    if (entry) {
      entry.props.width = width;
      entry.props.height = height;
      entry.props.position = [x, y];
    }
    // Update flowNodes with new dimensions and position
    flowNodes = flowNodes.map((n) =>
      n.id === nodeId
        ? {
            ...n,
            position: { x, y },
            style: `width: ${width}px; height: ${height}px;`,
            data: { ...n.data, width, height },
          }
        : n,
    );
  }

  // Track resized node dimensions so they survive MATLAB data updates
  const resizedNodeDims = new Map<string, { width: number; height: number }>();

  function handleNodeResize(nodeId: string, width: number, height: number) {
    resizedNodeDims.set(nodeId, { width, height });
    flowNodes = flowNodes.map((n) =>
      n.id === nodeId
        ? { ...n, style: `width: ${width}px; height: ${height}px;` }
        : n,
    );
  }

  function handleGroupCollapse(nodeId: string, collapsed: boolean) {
    // Write back to MATLAB childEntries
    const entries = childEntries['nodes'] ?? [];
    const entry = entries.find((c) => c.id === nodeId);
    if (entry) entry.props.collapsed = collapsed;

    // Find the group's current dimensions
    const groupNode = flowNodes.find((n) => n.id === nodeId);
    const w = groupNode?.data?.width ?? 400;
    const h = collapsed ? groupCollapsedH(groupNode?.data) : (groupNode?.data?.height ?? 300);

    // Collect child IDs for edge hiding
    const childIds = new Set(
      flowNodes.filter((n) => n.parentId === nodeId).map((n) => n.id),
    );

    // Update group + hide/show children
    flowNodes = flowNodes.map((n) => {
      if (n.id === nodeId) {
        return {
          ...n,
          style: `width: ${w}px; height: ${h}px;`,
          data: { ...n.data, collapsed },
        };
      }
      if (n.parentId === nodeId) {
        return { ...n, hidden: collapsed };
      }
      return n;
    });

    // Update hiddenNodeIds set and hide/show edges
    if (collapsed) {
      hiddenNodeIds = new Set([...hiddenNodeIds, ...childIds]);
    } else {
      const updated = new Set(hiddenNodeIds);
      for (const id of childIds) updated.delete(id);
      hiddenNodeIds = updated;
    }

    // Hide edges where ANY endpoint is a hidden child.
    // Edges to the group's own exterior ports stay visible (group is not hidden).
    flowEdges = flowEdges.map((e) => {
      const touches = childIds.has(e.source) || childIds.has(e.target);
      if (!touches && !e.hidden) return e;
      if (touches && collapsed) return { ...e, hidden: true };
      if (touches && !collapsed) {
        const { hidden: _, ...rest } = e;
        return rest;
      }
      return e;
    });
  }

  // -- Connection validation: MaxConnections enforcement ----------------------

  function isValidConnection(connection: Connection): boolean {
    const { source, target, sourceHandle, targetHandle } = connection;
    if (!source || !target) return false;

    // No self-connections
    if (source === target) return false;

    // :int handles are group interior tunnel ports — bypass port map validation
    const isIntHandle =
      sourceHandle?.endsWith(':int') || targetHandle?.endsWith(':int');

    if (!isIntHandle) {
      const srcPort = allPortMap.get(`${source}:${sourceHandle ?? ''}`);
      const tgtPort = allPortMap.get(`${target}:${targetHandle ?? ''}`);
      if (!srcPort || !tgtPort) return false;

      const srcCount = flowEdges.filter(
        (e) => e.source === source && e.sourceHandle === sourceHandle,
      ).length;
      const tgtCount = flowEdges.filter(
        (e) => e.target === target && e.targetHandle === targetHandle,
      ).length;

      if (srcCount >= srcPort.maxConnections) return false;
      if (tgtCount >= tgtPort.maxConnections) return false;

    }

    // Group boundary enforcement: connections cannot cross group boundaries
    // unless going through a group's boundary port.
    const srcNode = flowNodes.find((n) => n.id === source);
    const tgtNode = flowNodes.find((n) => n.id === target);
    if (srcNode && tgtNode) {
      const srcScope = srcNode.parentId ?? null;
      const tgtScope = tgtNode.parentId ?? null;
      if (srcScope !== tgtScope) {
        // Different scopes — only allowed through group boundary ports:
        // - target IS a group and source is a child inside it
        // - source IS a group and target is a child inside it
        const allowed =
          (isGroupType(tgtNode.type) && srcScope === target) ||
          (isGroupType(srcNode.type) && tgtScope === source);
        if (!allowed) return false;
      }
    }

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
    // Expand: include children of any group nodes being deleted
    const groupIds = new Set(
      nodes.filter((n) => isGroupType(n.type)).map((n) => n.id),
    );
    if (groupIds.size > 0) {
      const children = flowNodes.filter(
        (n) => n.parentId && groupIds.has(n.parentId) && !nodes.some((dn) => dn.id === n.id),
      );
      nodes = [...nodes, ...children];
    }

    const deletedNodeIds = new Set(nodes.map((n) => n.id));
    const deletableNodes = nodes.filter((n) => !n.data?.locked);

    if (deletableNodes.length > 0) {
      // Mark as pending so $effect.pre won't re-add from stale nodeStates
      const deleteIds = new Set(deletableNodes.map((n) => n.id));
      pendingDeleteIds = new Set([...pendingDeleteIds, ...deleteIds]);

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

    // Cascade downstream for removed edges (reset processor nodes that lost input)
    const allRemovedEdges = [...edges, ...standaloneEdges];
    // Defer so flowEdges is updated by SvelteFlow before we check remaining edges
    queueMicrotask(() => handleEdgesRemoved(allRemovedEdges));

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

  // -- Clipboard: copy/paste/duplicate nodes ----------------------------------

  /** Stored node IDs from last copy. */
  let clipboardIds: string[] | null = null;

  /** Get IDs of currently selected nodes. */
  function getSelectedIds(): string[] {
    return flowNodes.filter((n) => n.selected).map((n) => n.id);
  }

  /** Send duplication request to MATLAB (just IDs + offset). */
  async function duplicateNodes(nodeIds: string[], offset: number[]) {
    if (!request || nodeIds.length === 0) return;

    // Expand: include children of any group nodes being duplicated
    const expanded = new Set(nodeIds);
    for (const id of nodeIds) {
      const node = flowNodes.find((n) => n.id === id);
      if (isGroupType(node?.type)) {
        flowNodes
          .filter((n) => n.parentId === id)
          .forEach((n) => expanded.add(n.id));
      }
    }
    nodeIds = [...expanded];

    try {
      const result = await request('duplicateNodes', { nodeIds, offset });
      if (result?.success && result.data?.nodeIds) {
        const newIds = new Set(result.data.nodeIds as string[]);
        setTimeout(() => {
          flowNodes = flowNodes.map((n) => ({
            ...n,
            selected: newIds.has(n.id),
          }));
          flowEdges = flowEdges.map((fe) => ({ ...fe, selected: false }));
        }, 150);
      }
    } catch (err) {
      logger.error('NodeEditor', `duplicateNodes failed: ${String(err)}`);
    }
  }

  // -- Keyboard: Ctrl+A, Escape, Ctrl+C/V/D ---------------------------------

  let canvasEl: HTMLDivElement | undefined = $state();

  function handleKeyDown(e: KeyboardEvent) {
    const contains = canvasEl?.contains(e.target as Node);
    // Only handle shortcuts when the event originates inside the editor canvas
    if (!contains) return;
    // Don't intercept typing in inputs / textareas
    const tag = (e.target as HTMLElement)?.tagName;
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;

    const mod = e.metaKey || e.ctrlKey;
    if (mod && e.key === 'a') {
      e.preventDefault();
      flowNodes = flowNodes.map((n) => ({ ...n, selected: true }));
      flowEdges = flowEdges.map((fe) => ({ ...fe, selected: true }));
      return;
    }
    if (mod && e.key === 'c') {
      e.preventDefault();
      clipboardIds = getSelectedIds();
      return;
    }
    if (mod && e.key === 'v') {
      e.preventDefault();
      if (clipboardIds && clipboardIds.length > 0) duplicateNodes(clipboardIds, [30, 30]);
      return;
    }
    if (mod && e.key === 'd') {
      e.preventDefault();
      const ids = getSelectedIds();
      if (ids.length > 0) duplicateNodes(ids, [30, 30]);
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

    // Only layout top-level nodes (skip children inside groups)
    const topLevel = flowNodes.filter((n) => !n.parentId);
    const topIds = new Set(topLevel.map((n) => n.id));

    for (const node of topLevel) {
      const isGroup = isGroupType(node.type);
      const el = document.querySelector(`[data-id="${node.id}"]`);
      const width = isGroup ? (node.data?.width as number ?? 400) : (el?.clientWidth ?? 180);
      const height = isGroup ? (node.data?.height as number ?? 300) : (el?.clientHeight ?? 100);
      g.setNode(node.id, { width, height });
    }

    // Map child nodes to their parent group for edge routing
    const childToGroup = new Map<string, string>();
    for (const n of flowNodes) {
      if (n.parentId) childToGroup.set(n.id, n.parentId);
    }

    // Add edges between top-level nodes (mapping children to their groups)
    for (const edge of flowEdges) {
      const src = childToGroup.get(edge.source) ?? edge.source;
      const tgt = childToGroup.get(edge.target) ?? edge.target;
      if (topIds.has(src) && topIds.has(tgt) && src !== tgt) {
        g.setEdge(src, tgt);
      }
    }

    dagre.layout(g);

    // Update positions for top-level nodes only; children keep relative positions
    const updated = flowNodes.map((node) => {
      if (node.parentId) return node;
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
    writeBackPositions(updated.filter((n) => !n.parentId));
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
    context: { type: 'edge' | 'node' | 'port' | 'selection'; id: string; data?: any };
  } | null>(null);

  function closeCtxMenu() {
    ctxMenu = null;
  }

  // -- Edge context menu ------------------------------------------------------

  function buildEdgeContextMenu(edge: FlowEdge): ContextMenuEntry[] {
    const geom = (edge.data?.geometry as string) || edgeGeometry;
    const startArrow = (edge.data?.startArrow as string) || 'none';
    const endArrow = (edge.data?.endArrow as string) || 'none';
    const edgeType = (edge.data?.type as string) || 'static';
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

    // Convert edge type
    const typeOptions = ['static', 'flow', 'signal'] as const;
    entries.push({
      type: 'folder', label: 'Edge Type', icon: 'repeat',
      children: typeOptions.map((t) => ({
        type: 'item' as const,
        key: `type:${t}`,
        label: t.charAt(0).toUpperCase() + t.slice(1),
        icon: edgeType === t ? 'check' : undefined,
      })),
    });

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
      const flowAnimated = (edge.data?.animated as boolean) ?? true;
      entries.push({
        type: 'item', key: 'toggle-animated',
        label: flowAnimated ? 'Disable Particles' : 'Enable Particles',
        icon: flowAnimated ? 'pause' : 'play',
      });
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
      const sigAnimated = (edge.data?.animated as boolean) ?? true;
      entries.push({
        type: 'item', key: 'toggle-animated',
        label: sigAnimated ? 'Disable Waveform' : 'Enable Waveform',
        icon: sigAnimated ? 'pause' : 'play',
      });
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
    // Push to MATLAB so reactive setters fire
    request?.('updateEdgeProp', { edgeId, prop, value });
  }

  // -- Node context menu ------------------------------------------------------

  const TERMINAL_TYPES = new Set([INPUT_TYPE, OUTPUT_TYPE]);

  function buildTerminalContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'color', key: 'nodeBgColor', label: 'Background', value: (node.data?.backgroundColor as string) || '' },
      { type: 'color', key: 'nodeOutlineColor', label: 'Outline', value: (node.data?.outlineColor as string) || '' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildConstantContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'color', key: 'nodeBgColor', label: 'Background', value: (node.data?.backgroundColor as string) || '' },
      { type: 'color', key: 'nodeOutlineColor', label: 'Outline', value: (node.data?.outlineColor as string) || '' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildClockContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const animated = (node.data?.animated as boolean) ?? true;
    const unit = (node.data?.unit as string) ?? 's';
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'interval', label: 'Interval', value: String(node.data?.interval ?? 1) },
      {
        type: 'folder', label: `Unit: ${unit}`, icon: 'clock',
        children: [
          { type: 'item', key: 'unit:s', label: 'Seconds (s)', icon: unit === 's' ? 'check' : undefined },
          { type: 'item', key: 'unit:ms', label: 'Milliseconds (ms)', icon: unit === 'ms' ? 'check' : undefined },
          { type: 'item', key: 'unit:Hz', label: 'Hertz (Hz)', icon: unit === 'Hz' ? 'check' : undefined },
        ],
      },
      { type: 'separator' },
      { type: 'item', key: 'toggle-animated', label: animated ? 'Pause Animation' : 'Start Animation', icon: animated ? 'pause' : 'play' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildSignalContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'previewTime', label: 'Preview (s)', value: String(node.data?.previewTime ?? 2) },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  /** Profile → expr-eval expression map (mirrors Random.profileExpression in MATLAB). */
  const RANDOM_PROFILES: Record<string, string> = {
    white: 'sin(floor(t*8)*127.1)*cos(floor(t*8)*269.3)',
    binary: 'sign(sin(floor(t*6)*127.1)*cos(floor(t*6)*269.3))',
    sparse: '((abs(sin(floor(t*4)*127.1)*cos(floor(t*4)*269.3))>0.7) * sign(sin(floor(t*4)*127.1))) * 1',
    smooth: 'sin(t*3.17)*0.5 + cos(t*7.31)*0.3 + sin(t*13.03)*0.2',
  };

  function buildRandomContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const profile = (node.data?.profile as string) ?? 'white';
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      {
        type: 'folder', label: `Profile: ${profile}`, icon: 'dice-5',
        children: [
          { type: 'item', key: 'profile:white', label: 'White Noise', icon: profile === 'white' ? 'check' : undefined },
          { type: 'item', key: 'profile:binary', label: 'Binary (±1)', icon: profile === 'binary' ? 'check' : undefined },
          { type: 'item', key: 'profile:sparse', label: 'Sparse Pulses', icon: profile === 'sparse' ? 'check' : undefined },
          { type: 'item', key: 'profile:smooth', label: 'Smooth', icon: profile === 'smooth' ? 'check' : undefined },
        ],
      },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildDisplayContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const inputNumber = (node.data?.inputNumber as number) ?? 1;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'inputNumber', label: 'Input Count', value: String(inputNumber), placeholder: '1–8' },
      { type: 'text', key: 'previewTime', label: 'Preview Time', value: String((node.data?.previewTime as number) ?? 2), placeholder: 'seconds' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildMeterContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'min', label: 'Min', value: String((node.data?.min as number) ?? 0) },
      { type: 'text', key: 'max', label: 'Max', value: String((node.data?.max as number) ?? 100) },
      { type: 'text', key: 'meterUnit', label: 'Unit', value: (node.data?.meterUnit as string) || '', placeholder: 'e.g. V, dB' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildLoggerContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'maxLines', label: 'Max Lines', value: String((node.data?.maxLines as number) ?? 100), placeholder: '1–1000' },
      { type: 'item', key: 'clear-log', label: 'Clear Log', icon: 'eraser' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildGainContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'lock-open' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildDelayContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const unit = (node.data?.unit as string) ?? 's';
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      {
        type: 'folder', label: `Unit: ${unit}`, icon: 'clock',
        children: (['s', 'ms'] as const).map((u) => ({
          type: 'item' as const,
          key: `delayUnit:${u}`,
          label: u === 's' ? 'Seconds (s)' : 'Milliseconds (ms)',
          icon: u === unit ? 'check' : undefined,
        })),
      },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'lock-open' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildSwitchContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildMuxContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const inputNumber = (node.data?.inputNumber as number) ?? 2;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'inputNumber', label: 'Input Count', value: String(inputNumber), placeholder: '2–16' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildDemuxContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const outputNumber = (node.data?.outputNumber as number) ?? 2;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'outputNumber', label: 'Output Count', value: String(outputNumber), placeholder: '2–16' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildAccumulatorContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const inputNumber = (node.data?.inputNumber as number) ?? 2;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'inputNumber', label: 'Input Count', value: String(inputNumber), placeholder: '2–16' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildFunctionContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'inputNumber', label: 'Inputs', value: String((node.data?.inputNumber as number) ?? 2) },
      { type: 'color', key: 'nodeColor', label: 'Node Color', value: (node.data?.color as string) || '' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock Node' : 'Lock Node', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable Node' : 'Disable Node', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete Node', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildTransformContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'text', key: 'inputNumber', label: 'Channels', value: String((node.data?.inputNumber as number) ?? 1) },
      { type: 'color', key: 'nodeColor', label: 'Node Color', value: (node.data?.color as string) || '' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock Node' : 'Lock Node', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable Node' : 'Disable Node', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete Node', icon: 'trash-2', disabled: locked },
    ];
  }

  // -- Classical node context menus ------------------------------------------

  function buildClassicalContextMenu(node: FlowNode, extraEntries: ContextMenuEntry[] = []): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      ...extraEntries,
      ...(extraEntries.length > 0 ? [{ type: 'separator' as const }] : []),
      { type: 'color', key: 'nodeBgColor', label: 'Background', value: (node.data?.backgroundColor as string) || '' },
      { type: 'color', key: 'nodeOutlineColor', label: 'Outline', value: (node.data?.outlineColor as string) || '' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock' : 'Lock', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable' : 'Disable', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildProcessContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildDecisionContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildTerminatorContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildDatabaseContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildCloudContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildDocumentContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildQueueContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildActorContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildIconBoxContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildClassNodeContextMenu(node: FlowNode): ContextMenuEntry[] {
    return buildClassicalContextMenu(node);
  }

  function buildNodeContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    const disabled = (node.data?.disabled as boolean) ?? false;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    return [
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock Node' : 'Lock Node', icon: locked ? 'unlock' : 'lock' },
      { type: 'item', key: 'toggle-disabled', label: disabled ? 'Enable Node' : 'Disable Node', icon: disabled ? 'eye' : 'eye-off' },
      { type: 'separator' },
      { type: 'item', key: 'disconnect-all', label: `Disconnect All (${connectedEdgeCount})`, icon: 'unplug', disabled: connectedEdgeCount === 0 },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete Node', icon: 'trash-2', disabled: locked },
    ];
  }

  function buildNoteContextMenu(node: FlowNode): ContextMenuEntry[] {
    const locked = (node.data?.locked as boolean) ?? false;
    return [
      { type: 'color', key: 'nodeColor', label: 'Note Color', value: (node.data?.color as string) || '#fef9c3' },
      { type: 'separator' },
      { type: 'item', key: 'toggle-lock', label: locked ? 'Unlock Note' : 'Lock Note', icon: locked ? 'unlock' : 'lock' },
      { type: 'separator' },
      { type: 'item', key: 'delete-node', label: 'Delete Note', icon: 'trash-2', disabled: locked },
    ];
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

    const isGroup = isGroupType(node.type);

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
    // Group boundary ports inherit type from connected nodes — no editing allowed
    if (portSide === 'output' && !isGroup) {
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

  // -- Selection context menu --------------------------------------------------

  function buildSelectionContextMenu(nodes: FlowNode[]): ContextMenuEntry[] {
    return [
      {
        type: 'item',
        key: 'group-selection',
        label: `Group Selection (${nodes.length})`,
        icon: 'group',
      },
      { type: 'separator' },
      {
        type: 'item',
        key: 'delete-selection',
        label: `Delete Selection (${nodes.length})`,
        icon: 'trash-2',
      },
    ];
  }

  // -- Group context menu -----------------------------------------------------

  function buildGroupContextMenu(node: FlowNode): ContextMenuEntry[] {
    const isCollapsible = node.type === 'ic.node.CollapsibleGroup';
    const collapsed = (node.data?.collapsed as boolean) ?? false;
    const locked = (node.data?.locked as boolean) ?? false;
    const childCount = flowNodes.filter((n) => n.parentId === node.id).length;
    const connectedEdgeCount = flowEdges.filter(
      (e) => e.source === node.id || e.target === node.id,
    ).length;

    const entries: ContextMenuEntry[] = [];

    entries.push(
      { type: 'color', key: 'groupBgColor', label: 'Background', value: (node.data?.backgroundColor as string) || '' },
      { type: 'range', key: 'groupBgOpacity', label: 'Opacity', value: (node.data?.backgroundOpacity as number) ?? 0 },
    );

    if (isCollapsible) {
      entries.push(
        { type: 'color', key: 'groupAccent', label: 'Accent', value: (node.data?.accentColor as string) || '' },
      );
    }

    entries.push({ type: 'separator' });

    if (isCollapsible) {
      entries.push({
        type: 'item',
        key: 'toggle-collapse',
        label: collapsed ? 'Expand Group' : 'Collapse Group',
        icon: collapsed ? 'chevron-down' : 'chevron-up',
      });
    }

    entries.push(
      {
        type: 'item',
        key: 'ungroup',
        label: `Ungroup (${childCount})`,
        icon: 'unfold-horizontal',
        disabled: childCount === 0,
      },
      { type: 'separator' },
      {
        type: 'item',
        key: 'toggle-lock',
        label: locked ? 'Unlock Group' : 'Lock Group',
        icon: locked ? 'unlock' : 'lock',
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
        key: 'delete-group',
        label: 'Delete Group',
        icon: 'trash-2',
        disabled: locked,
      },
    );

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
      // Multi-selection: groupable top-level non-group nodes
      const selIds = new Set(selectedNodeIds);
      const selected = flowNodes.filter((n) => selIds.has(n.id));
      const groupable = selected.filter(
        (n) => !isGroupType(n.type) && !n.parentId,
      );

      if (selIds.has(node.id) && groupable.length >= 2) {
        ctxMenu = {
          entries: buildSelectionContextMenu(groupable),
          x: event.clientX,
          y: event.clientY,
          context: { type: 'selection', id: '', data: { nodeIds: groupable.map((n) => n.id) } },
        };
      } else if (isGroupType(node.type)) {
        ctxMenu = {
          entries: buildGroupContextMenu(node),
          x: event.clientX,
          y: event.clientY,
          context: { type: 'node', id: node.id, data: node },
        };
      } else {
        const entries = TERMINAL_TYPES.has(node.type!)
          ? buildTerminalContextMenu(node)
          : node.type === CONSTANT_TYPE
            ? buildConstantContextMenu(node)
            : node.type === CLOCK_TYPE
              ? buildClockContextMenu(node)
              : node.type === SIGNAL_TYPE
                ? buildSignalContextMenu(node)
                : node.type === RANDOM_TYPE
                  ? buildRandomContextMenu(node)
                  : node.type === DISPLAY_TYPE
                    ? buildDisplayContextMenu(node)
                    : node.type === METER_TYPE
                      ? buildMeterContextMenu(node)
                      : node.type === LOGGER_TYPE
                        ? buildLoggerContextMenu(node)
                        : node.type === GAIN_TYPE
                          ? buildGainContextMenu(node)
                          : node.type === DELAY_TYPE
                            ? buildDelayContextMenu(node)
                            : node.type === SWITCH_TYPE
                              ? buildSwitchContextMenu(node)
                              : node.type === MUX_TYPE
                                ? buildMuxContextMenu(node)
                                : node.type === DEMUX_TYPE
                                  ? buildDemuxContextMenu(node)
                                  : node.type === ACCUMULATOR_TYPE
                                    ? buildAccumulatorContextMenu(node)
                                    : node.type === TRANSFORM_TYPE
                                      ? buildTransformContextMenu(node)
                                      : node.type === FUNCTION_TYPE
                                        ? buildFunctionContextMenu(node)
                                        : node.type === NOTE_TYPE
                                          ? buildNoteContextMenu(node)
                                          : node.type === PROCESS_TYPE
                                            ? buildProcessContextMenu(node)
                                            : node.type === DECISION_TYPE
                                              ? buildDecisionContextMenu(node)
                                              : node.type === TERMINATOR_TYPE
                                                ? buildTerminatorContextMenu(node)
                                                : node.type === DATABASE_TYPE
                                                  ? buildDatabaseContextMenu(node)
                                                  : node.type === CLOUD_TYPE
                                                    ? buildCloudContextMenu(node)
                                                    : node.type === DOCUMENT_TYPE
                                                      ? buildDocumentContextMenu(node)
                                                      : node.type === QUEUE_TYPE
                                                        ? buildQueueContextMenu(node)
                                                        : node.type === ACTOR_TYPE
                                                          ? buildActorContextMenu(node)
                                                          : node.type === ICONBOX_TYPE
                                                            ? buildIconBoxContextMenu(node)
                                                            : node.type === CLASSNODE_TYPE
                                                              ? buildClassNodeContextMenu(node)
                                                              : buildNodeContextMenu(node);
        ctxMenu = {
          entries,
          x: event.clientX,
          y: event.clientY,
          context: { type: 'node', id: node.id, data: node },
        };
      }
    }
  }

  function handlePaneContextMenu(event: MouseEvent) {
    event.preventDefault();
  }

  /** SvelteFlow fires this when right-clicking the multi-selection overlay. */
  function handleSelectionContextMenu({ nodes: selNodes, event }: { nodes: FlowNode[]; event: MouseEvent }) {
    event.preventDefault();
    event.stopPropagation();

    const groupable = selNodes.filter(
      (n) => !isGroupType(n.type) && !n.parentId,
    );
    if (groupable.length < 2) return;

    ctxMenu = {
      entries: buildSelectionContextMenu(groupable),
      x: event.clientX,
      y: event.clientY,
      context: { type: 'selection', id: '', data: { nodeIds: groupable.map((n) => n.id) } },
    };
  }

  /** Update a single prop on a node + write back to childEntries + push to MATLAB. */
  function updateNodeProp(nodeId: string, prop: string, value: unknown) {
    // Update SvelteFlow's internal store + flowNodes array
    sfRefs.flow?.updateNodeData(nodeId, { [prop]: value });
    flowNodes = flowNodes.map((n) =>
      n.id === nodeId ? { ...n, data: { ...n.data, [prop]: value } } : n,
    );
    // Write back to childEntries for IC bridge sync
    const nodeEntries = childEntries['nodes'] ?? [];
    const entry = nodeEntries.find((c) => c.id === nodeId);
    if (entry) entry.props[prop] = value;
    // Push to MATLAB so reactive setters fire (e.g., Gain.syncOutput, Delay.syncOutput)
    request?.('updateNodeProp', { nodeId, prop, value });
  }

  /**
   * Recalculate a processor node's output expression based on its input.
   * Pass null inputExpression to reset (input disconnected).
   * Returns the new output expression, or null if not a processor.
   */
  function recalcProcessorOutput(nodeId: string, inputExpression: string | null): string | null {
    const node = flowNodes.find((n) => n.id === nodeId);
    if (!node || !isProcessorType(node.type)) return null;

    // No input → reset to static, clear expression on connected edges
    if (inputExpression === null) {
      updatePortProp(nodeId, 'out', 'output', 'type', 'static');
      updatePortProp(nodeId, 'out', 'output', 'expression', '0');
      return null;
    }

    if (node.type === GAIN_TYPE) {
      const factor = (node.data as any).factor ?? 1;
      const expr = `(${factor})*(${inputExpression})`;
      updatePortProp(nodeId, 'out', 'output', 'expression', expr);
      updatePortProp(nodeId, 'out', 'output', 'type', 'signal');
      return expr;
    }

    if (node.type === DELAY_TYPE) {
      const dt = Number((node.data as any).delayTime ?? 1);
      const unit = String((node.data as any).unit ?? 's');
      const delaySec = unit === 'ms' ? dt / 1000 : dt;
      const expr = inputExpression.replace(
        /(?<![a-zA-Z_])t(?![a-zA-Z_0-9])/g, `(t-${delaySec})`,
      );
      updatePortProp(nodeId, 'out', 'output', 'expression', expr);
      updatePortProp(nodeId, 'out', 'output', 'type', 'signal');
      return expr;
    }

    return null;
  }

  /**
   * Walk downstream from sourceNodeId through processor nodes, recalculating
   * their outputs. Pass null expression to signal "input disconnected".
   */
  function cascadeDownstream(sourceNodeId: string, outputExpression: string | null) {
    const visited = new Set<string>();
    const queue: Array<{ nodeId: string; expression: string | null }> = [];

    for (const e of flowEdges) {
      if (e.source === sourceNodeId) {
        queue.push({ nodeId: e.target, expression: outputExpression });
      }
    }

    while (queue.length > 0) {
      const { nodeId, expression } = queue.shift()!;
      if (visited.has(nodeId)) continue;
      visited.add(nodeId);

      const newExpr = recalcProcessorOutput(nodeId, expression);
      // Continue downstream: newExpr if processor produced output, null if it reset
      const isProcessor = isProcessorType(flowNodes.find((n) => n.id === nodeId)?.type);
      if (isProcessor) {
        for (const e of flowEdges) {
          if (e.source === nodeId && !visited.has(e.target)) {
            queue.push({ nodeId: e.target, expression: newExpr });
          }
        }
      }
    }
  }

  /**
   * After edges are removed, reset any downstream processor nodes that lost
   * their input and cascade the change further downstream.
   */
  function handleEdgesRemoved(removedEdges: FlowEdge[]) {
    const removedIds = new Set(removedEdges.map((e) => e.id));
    for (const edge of removedEdges) {
      const targetNode = flowNodes.find((n) => n.id === edge.target);
      if (!targetNode || !isProcessorType(targetNode.type)) continue;

      // Check if the processor still has an input edge (excluding removed ones)
      const stillHasInput = flowEdges.some(
        (e) => !removedIds.has(e.id) && e.target === edge.target && e.targetHandle === 'in',
      );

      if (!stillHasInput) {
        recalcProcessorOutput(edge.target, null);
        cascadeDownstream(edge.target, null);
      }
    }
  }

  /** Handle inline prop changes from node components (double-click edit). */
  function handleNodePropChange(nodeId: string, prop: string, value: unknown) {
    updateNodeProp(nodeId, prop, value);
    const node = flowNodes.find((n) => n.id === nodeId);
    if (!node) return;

    let outputExpr: string | null = null;

    // Side effects: propagate to port props where needed (mirrors MATLAB setters)
    if (prop === 'expression' && node.type === SIGNAL_TYPE) {
      outputExpr = String(value);
      updatePortProp(nodeId, 'signal', 'output', 'expression', outputExpr);
    } else if (prop === 'value' && node.type === CONSTANT_TYPE) {
      outputExpr = String(value);
      updatePortProp(nodeId, 'value', 'output', 'expression', outputExpr);
    } else if (prop === 'interval' && node.type === CLOCK_TYPE) {
      const val = Number(value);
      if (val > 0) {
        updatePortProp(nodeId, 'tick', 'output', 'outputRate', 1);
        updatePortProp(nodeId, 'tick', 'output', 'speed', 2 / val);
      }
    } else if (prop === 'factor' && node.type === GAIN_TYPE) {
      const inputSigs = (node.data as any).inputSignals as InputSignal[] ?? [];
      const sig = inputSigs.find((s) => s.type === 'signal');
      if (sig) {
        outputExpr = `(${value})*(${sig.expression})`;
        updatePortProp(nodeId, 'out', 'output', 'expression', outputExpr);
        updatePortProp(nodeId, 'out', 'output', 'type', 'signal');
      }
    } else if ((prop === 'delayTime' || prop === 'unit') && node.type === DELAY_TYPE) {
      const inputSigs = (node.data as any).inputSignals as InputSignal[] ?? [];
      const sig = inputSigs.find((s) => s.type === 'signal');
      if (sig) {
        const dt = Number(node.data.delayTime ?? 1);
        const unit = String(node.data.unit ?? 's');
        const delaySec = unit === 'ms' ? dt / 1000 : dt;
        outputExpr = sig.expression.replace(
          /(?<![a-zA-Z_])t(?![a-zA-Z_0-9])/g, `(t-${delaySec})`,
        );
        updatePortProp(nodeId, 'out', 'output', 'expression', outputExpr);
        updatePortProp(nodeId, 'out', 'output', 'type', 'signal');
      }
    }

    // Cascade expression change through downstream processor nodes
    if (outputExpr) {
      cascadeDownstream(nodeId, outputExpr);
    }
  }

  /** Map output port props to edge data keys. */
  const PORT_TO_EDGE_KEY: Record<string, string> = {
    type: 'type',
    outputRate: 'sourceOutputRate',
    speed: 'sourceSpeed',
    expression: 'sourceExpression',
    frequency: 'sourceFrequency',
    timeOffset: 'sourceTimeOffset',
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
      flowEdges = flowEdges.map((e) => {
        if (e.source !== nodeId || e.sourceHandle !== portName) return e;
        const updated: Record<string, unknown> = { ...e.data, [edgeDataKey]: value };
        // Auto-enable animation when type changes to signal/flow
        if (prop === 'type' && (value === 'signal' || value === 'flow')) {
          updated.animated = true;
        }
        return { ...e, data: updated };
      });
    }
  }

  // Keys whose actions should NOT close the menu (live preview / inline editing)
  const COLOR_PROPS = new Set(['color', 'signalColor', 'particleColor', 'nodeColor', 'groupAccent', 'groupBgColor', 'nodeBgColor', 'nodeOutlineColor']);
  const TEXT_PROPS = new Set(['label', 'expression', 'port-label', 'port-expression', 'value', 'interval', 'previewTime', 'inputNumber', 'min', 'max', 'meterUnit', 'maxLines', 'factor', 'delayTime']);
  const RANGE_PROPS = new Set(['groupBgOpacity']);

  function handleCtxAction(key: string) {
    const ctx = ctxMenu?.context;
    if (!ctx) return;

    const colonIdx0 = key.indexOf(':');
    const propKey = colonIdx0 > 0 ? key.slice(0, colonIdx0) : '';
    const isLiveAction = COLOR_PROPS.has(propKey) || TEXT_PROPS.has(propKey) || RANGE_PROPS.has(propKey);
    if (!isLiveAction) closeCtxMenu();

    if (ctx.type === 'edge') {
      if (key === 'delete-edge') {
        const removed = flowEdges.filter((e) => e.id === ctx.id);
        if (!ctx.id.startsWith('sf-')) {
          request?.('disconnect', { edgeId: ctx.id });
        }
        flowEdges = flowEdges.filter((e) => e.id !== ctx.id);
        handleEdgesRemoved(removed);
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
      } else if (key.startsWith('groupAccent:')) {
        updateNodeProp(ctx.id, 'accentColor', key.slice('groupAccent:'.length));
      } else if (key.startsWith('groupBgColor:')) {
        updateNodeProp(ctx.id, 'backgroundColor', key.slice('groupBgColor:'.length));
      } else if (key.startsWith('groupBgOpacity:')) {
        updateNodeProp(ctx.id, 'backgroundOpacity', Number(key.slice('groupBgOpacity:'.length)));
      } else if (key.startsWith('nodeBgColor:')) {
        updateNodeProp(ctx.id, 'backgroundColor', key.slice('nodeBgColor:'.length));
      } else if (key.startsWith('nodeOutlineColor:')) {
        updateNodeProp(ctx.id, 'outlineColor', key.slice('nodeOutlineColor:'.length));
      } else if (key.startsWith('value:')) {
        const rawVal = key.slice('value:'.length);
        const numVal = Number(rawVal);
        const val = isNaN(numVal) ? 0 : numVal;
        handleNodePropChange(ctx.id, 'value', val);
      } else if (key.startsWith('label:')) {
        handleNodePropChange(ctx.id, 'label', key.slice('label:'.length));
      } else if (key.startsWith('expression:')) {
        handleNodePropChange(ctx.id, 'expression', key.slice('expression:'.length));
      } else if (key.startsWith('interval:')) {
        const val = Number(key.slice('interval:'.length));
        if (val > 0) handleNodePropChange(ctx.id, 'interval', val);
      } else if (key.startsWith('previewTime:')) {
        const val = Number(key.slice('previewTime:'.length));
        if (val > 0) updateNodeProp(ctx.id, 'previewTime', val);
      } else if (key === 'toggle-animated') {
        const node = flowNodes.find((n) => n.id === ctx.id);
        const current = (node?.data?.animated as boolean) ?? true;
        updateNodeProp(ctx.id, 'animated', !current);
      } else if (key.startsWith('unit:')) {
        updateNodeProp(ctx.id, 'unit', key.slice('unit:'.length));
      } else if (key.startsWith('profile:')) {
        const prof = key.slice('profile:'.length);
        updateNodeProp(ctx.id, 'profile', prof);
        // Update port expression to match the new noise profile
        const expr = RANDOM_PROFILES[prof];
        if (expr) {
          updatePortProp(ctx.id, 'value', 'output', 'expression', expr);
        }
      } else if (key.startsWith('inputNumber:')) {
        const val = Math.round(Number(key.slice('inputNumber:'.length)));
        if (val > 0 && val <= 8) updateNodeProp(ctx.id, 'inputNumber', val);
      } else if (key.startsWith('min:')) {
        updateNodeProp(ctx.id, 'min', Number(key.slice('min:'.length)));
      } else if (key.startsWith('max:')) {
        updateNodeProp(ctx.id, 'max', Number(key.slice('max:'.length)));
      } else if (key.startsWith('meterUnit:')) {
        updateNodeProp(ctx.id, 'unit', key.slice('meterUnit:'.length));
      } else if (key.startsWith('maxLines:')) {
        const val = Math.round(Number(key.slice('maxLines:'.length)));
        if (val > 0) updateNodeProp(ctx.id, 'maxLines', val);
      } else if (key.startsWith('factor:')) {
        const val = Number(key.slice('factor:'.length));
        if (!isNaN(val)) handleNodePropChange(ctx.id, 'factor', val);
      } else if (key.startsWith('delayTime:')) {
        const val = Number(key.slice('delayTime:'.length));
        if (!isNaN(val) && val >= 0) handleNodePropChange(ctx.id, 'delayTime', val);
      } else if (key.startsWith('delayUnit:')) {
        handleNodePropChange(ctx.id, 'unit', key.slice('delayUnit:'.length));
      } else if (key === 'clear-log') {
        updateNodeProp(ctx.id, 'logEntries', []);
      } else if (key === 'toggle-collapse') {
        const node = flowNodes.find((n) => n.id === ctx.id);
        const current = (node?.data?.collapsed as boolean) ?? false;
        handleGroupCollapse(ctx.id, !current);
      } else if (key === 'ungroup') {
        request?.('ungroupNodes', { groupId: ctx.id });
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
        handleEdgesRemoved(connected);
      } else if (key === 'delete-node' || key === 'delete-group') {
        const node = flowNodes.find((n) => n.id === ctx.id);
        if (node && !node.data?.locked) {
          request?.('deleteNodes', { nodeIds: [ctx.id] });
          // Collect all nodes to remove (include group children)
          const idsToRemove = new Set([ctx.id]);
          if (isGroupType(node.type)) {
            flowNodes.filter((n) => n.parentId === ctx.id).forEach((n) => idsToRemove.add(n.id));
          }
          // Disconnect all edges connected to removed nodes
          const connected = flowEdges.filter(
            (e) => idsToRemove.has(e.source) || idsToRemove.has(e.target),
          );
          for (const edge of connected) {
            if (!edge.id.startsWith('sf-')) {
              request?.('disconnect', { edgeId: edge.id });
            }
          }
          flowEdges = flowEdges.filter(
            (e) => !idsToRemove.has(e.source) && !idsToRemove.has(e.target),
          );
          flowNodes = flowNodes.filter((n) => !idsToRemove.has(n.id));
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
        handleEdgesRemoved(portEdges);
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
    } else if (ctx.type === 'selection') {
      const { nodeIds } = ctx.data as { nodeIds: string[] };
      if (key === 'group-selection') {
        request?.('groupSelection', { nodeIds });
      } else if (key === 'delete-selection') {
        request?.('deleteNodes', { nodeIds });
        const idsToRemove = new Set(nodeIds);
        flowEdges = flowEdges.filter(
          (e) => !idsToRemove.has(e.source) && !idsToRemove.has(e.target),
        );
        flowNodes = flowNodes.filter((n) => !idsToRemove.has(n.id));
      }
    }
  }

</script>

<svelte:window onkeydown={handleKeyDown} />

<div class="ic-ne" style:height>
  {#if toolbarEntries.length > 0}
    <div class="ic-ne__toolbar">
      {#each toolbarEntries as entry (entry.id)}
        {@render entry.snippet()}
      {/each}
    </div>
  {/if}

  <div class="ic-ne__canvas" bind:this={canvasEl}>
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
      onpanecontextmenu={({ event }) => handlePaneContextMenu(event)}
      onselectioncontextmenu={handleSelectionContextMenu}
    >
      <Background variant={bgVariant} gap={gridSize} size={1} />
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
    <div class="ic-ne__control-sep"></div>
    <!-- Play/Pause toggle -->
    <button
      class="ic-ne__control-btn"
      class:ic-ne__control-btn--active={playingProp}
      title={playingProp ? 'Pause animations' : 'Play animations'}
      onclick={() => { playingProp = !playingProp; }}
    >
      {#if playingProp}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
          <rect x="6" y="4" width="4" height="16" rx="1" />
          <rect x="14" y="4" width="4" height="16" rx="1" />
        </svg>
      {:else}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
          <polygon points="6,4 20,12 6,20" />
        </svg>
      {/if}
    </button>
    <!-- Speed dropdown -->
    <select
      class="ic-ne__speed-select"
      title="Animation speed"
      value={String(playSpeed)}
      onchange={(e) => { playSpeed = parseFloat((e.target as HTMLSelectElement).value); }}
    >
      <option value="0.5">0.5x</option>
      <option value="1">1x</option>
      <option value="2">2x</option>
      <option value="5">5x</option>
      <option value="10">10x</option>
    </select>
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

  .ic-ne__speed-select {
    height: 26px;
    padding: 0 4px;
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    background: var(--ic-background);
    color: var(--ic-muted-foreground);
    font-family: var(--ic-font-family);
    font-size: 11px;
    cursor: pointer;
    outline: none;
  }

  .ic-ne__speed-select:hover {
    border-color: var(--ic-muted-foreground);
    color: var(--ic-foreground);
  }

  .ic-ne__speed-select:focus {
    border-color: var(--ic-primary);
  }

  /* ── MiniMap ─── */
  .ic-ne :global(.svelte-flow__minimap) {
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

</style>
