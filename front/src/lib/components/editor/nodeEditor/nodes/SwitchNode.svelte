<!--
  SwitchNode.svelte — Electrical switch with animated lever.
  3 inputs: ctrl (top), in1 (top-left), in2 (bottom-left). 1 output: out (right).
  When control signal >= 1, lever connects to in1; otherwise in2.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';
  import { evaluateExpression, registerAnimationCallback } from '$lib/utils/edge-utils';
  import { onMount, onDestroy } from 'svelte';

  type InputSignal = {
    portName: string;
    expression: string;
    frequency: number;
    speed: number;
    outputRate: number;
    timeOffset: number;
    type: string;
  };

  type SwitchData = {
    label: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
    inputSignals: InputSignal[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type SwitchNodeType = Node<SwitchData, 'ic.node.Switch'>;

  let { data, selected, dragging }: NodeProps<SwitchNodeType> = $props();

  let hovered = $state(false);
  let switchState = $state(false); // false = in1 (ctrl low), true = in2 (ctrl high)

  const BASE_SPEED = 0.5;

  const strokeColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : 'var(--ic-border)',
  );

  let unregister: (() => void) | null = null;

  onMount(() => {
    unregister = registerAnimationCallback((globalTime: number) => {
      const signals = data.inputSignals;
      if (!signals || signals.length === 0) {
        switchState = false;
        return;
      }
      // Find ctrl signal
      const ctrl = signals.find((s) => s.portName === 'ctrl');
      if (!ctrl || ctrl.type === 'static') {
        switchState = false;
        return;
      }

      let val: number;
      if (ctrl.type === 'flow') {
        const rate = ctrl.outputRate ?? 1;
        const speed = ctrl.speed ?? 1;
        const offset = ctrl.timeOffset ?? 0;
        const t = globalTime * BASE_SPEED * speed - offset;
        const phase = ((t * rate) % 1 + 1) % 1;
        val = phase < 0.05 ? 1 : 0;
      } else {
        const t = globalTime * BASE_SPEED * (ctrl.speed ?? 1);
        val = evaluateExpression(ctrl.expression || '0', t);
      }
      switchState = val >= 1;
    });
  });

  onDestroy(() => {
    if (unregister) unregister();
  });

  // Lever endpoint: pivots from center-left to either in1 (top) or in2 (bottom)
  const leverAngle = $derived(switchState ? 30 : -30);
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-switch"
  class:ic-ne-switch--hovered={hovered && !selected && !dragging}
  class:ic-ne-switch--selected={selected}
  class:ic-ne-switch--dragging={dragging}
  class:ic-ne-switch--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-switch__svg" viewBox="0 0 60 50">
    <!-- Lever arm: pivots from right-center, free end swings left toward in1/in2 -->
    <line
      x1="11"
      y1="25"
      x2="49"
      y2="25"
      stroke={switchState ? 'var(--ic-primary)' : 'var(--ic-muted-foreground)'}
      stroke-width="2.5"
      stroke-linecap="round"
      transform="rotate({leverAngle} 49 25)"
      style="transition: transform 0.15s ease;"
    />

    <!-- Pivot point (right side) -->
    <circle cx="49" cy="25" r="3.5" fill="var(--ic-background)" stroke={strokeColor} stroke-width="1.5" />
  </svg>

  <!-- Label -->
  {#if data.label}
    <div class="ic-ne-switch__label">
      <InlineEdit value={data.label} className="ic-ne-switch__label-edit" oncommit={(v) => data.onpropchange?.('label', v)} />
    </div>
  {/if}

  <!-- Ports -->
  <!-- ctrl: top center -->
  {#if data.inputs?.find((p) => p.name === 'ctrl')}
    <PortHandle
      type="target"
      position={Position.Top}
      id="ctrl"
      variant="dot"
      style="top: -3px; left: 50%; transform: translateX(-50%);"
    />
  {/if}

  <!-- in1: upper-left -->
  {#if data.inputs?.find((p) => p.name === 'in1')}
    <PortHandle
      type="target"
      position={Position.Left}
      id="in1"
      variant="circle"
      style="top: 22%; left: -3px; transform: translateY(-50%);"
    />
  {/if}

  <!-- in2: lower-left -->
  {#if data.inputs?.find((p) => p.name === 'in2')}
    <PortHandle
      type="target"
      position={Position.Left}
      id="in2"
      variant="circle"
      style="top: 78%; left: -3px; transform: translateY(-50%);"
    />
  {/if}

  <!-- out: right -->
  {#if data.outputs?.[0]}
    <PortHandle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
      variant="circle"
    />
  {/if}
</div>

<style>
  .ic-ne-switch {
    position: relative;
    width: 60px;
  }

  .ic-ne-switch--selected {
    filter: drop-shadow(0 0 2px var(--ic-primary));
  }

  .ic-ne-switch--dragging {
    filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.3));
  }

  .ic-ne-switch--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-switch__svg {
    width: 100%;
    height: auto;
    display: block;
  }

  .ic-ne-switch__label {
    text-align: center;
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    overflow: clip;
    text-overflow: ellipsis;
    padding: 0 2px;
  }
</style>
