<!--
  ClockNode.svelte — Circular clock face source node with animated rotating hand.
  Industrial Flat: dark ring, 12 tick marks, single rotating hand.
  Animation controlled by `animated` prop; speed linked to `interval` + `unit`.
-->
<script lang="ts">
  import { Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';
  import PortHandle from '../shared/PortHandle.svelte';
  import InlineEdit from '../shared/InlineEdit.svelte';

  type ClockData = {
    label: string;
    interval: number;
    unit: string;
    animated: boolean;
    disabled: boolean;
    locked: boolean;
    outputs: PortDef[];
    onpropchange?: (prop: string, value: unknown) => void;
  };

  type ClockNodeType = Node<ClockData, 'ic.node.Clock'>;

  let { data, selected, dragging }: NodeProps<ClockNodeType> = $props();

  let hovered = $state(false);

  /** Convert interval + unit to seconds for CSS animation-duration. */
  const durationSec = $derived.by(() => {
    const iv = data.interval ?? 1;
    const u = data.unit ?? 's';
    if (u === 'ms') return iv / 1000;
    if (u === 'Hz') return iv > 0 ? 1 / iv : 1;
    return iv; // seconds
  });

  const strokeColor = $derived(
    selected ? 'var(--ic-primary)' : 'var(--ic-border)',
  );

  // 12 tick marks: longer at 12/3/6/9
  const ticks = Array.from({ length: 12 }, (_, i) => {
    const angle = (i * 30 - 90) * (Math.PI / 180);
    const major = i % 3 === 0;
    const r1 = major ? 18 : 20;
    const r2 = 23;
    return {
      x1: 28 + r1 * Math.cos(angle),
      y1: 28 + r1 * Math.sin(angle),
      x2: 28 + r2 * Math.cos(angle),
      y2: 28 + r2 * Math.sin(angle),
      major,
    };
  });
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-clock"
  class:ic-ne-clock--hovered={hovered && !selected && !dragging}
  class:ic-ne-clock--selected={selected}
  class:ic-ne-clock--dragging={dragging}
  class:ic-ne-clock--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg
    class="ic-ne-clock__face"
    viewBox="0 0 56 56"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- Outer ring -->
    <circle
      cx="28"
      cy="28"
      r="26"
      fill="var(--ic-background)"
      stroke={strokeColor}
      stroke-width="1.5"
    />
    <!-- Inner shadow ring (inset effect) -->
    <circle
      cx="28"
      cy="28"
      r="24"
      fill="none"
      stroke="rgba(0,0,0,0.08)"
      stroke-width="1"
    />

    <!-- Tick marks -->
    {#each ticks as tick}
      <line
        x1={tick.x1}
        y1={tick.y1}
        x2={tick.x2}
        y2={tick.y2}
        stroke="var(--ic-muted-foreground)"
        stroke-width={tick.major ? 1.5 : 0.8}
        stroke-linecap="round"
      />
    {/each}

    <!-- Rotating hand -->
    <line
      class="ic-ne-clock__hand"
      x1="28"
      y1="28"
      x2="28"
      y2="10"
      stroke="var(--ic-primary)"
      stroke-width="1.5"
      stroke-linecap="round"
      style:animation-duration="{durationSec}s"
      style:animation-play-state={data.animated ? 'running' : 'paused'}
    />

    <!-- Center dot -->
    <circle cx="28" cy="28" r="2.5" fill="var(--ic-primary)" />
  </svg>

  <!-- Output handle on right -->
  {#if data.outputs?.[0]}
    <PortHandle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
      variant="diamond"
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-clock__label">
    <InlineEdit value={data.label} className="ic-ne-clock__label-edit" oncommit={(v) => data.onpropchange?.('label', v)} />
  </div>
{/if}

<style>
  .ic-ne-clock {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    transition: filter 0.15s ease;
  }

  .ic-ne-clock--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-clock--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-clock--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-clock--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-clock__face {
    width: 56px;
    height: 56px;
    display: block;
  }

  .ic-ne-clock__hand {
    transform-origin: 28px 28px;
    animation: ic-clock-rotate 1s linear infinite;
  }

  @keyframes ic-clock-rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .ic-ne-clock__label {
    position: absolute;
    top: 100%;
    left: 50%;
    transform: translateX(-50%);
    margin-top: 4px;
    font-family: var(--ic-font-family);
    font-size: 10px;
    color: var(--ic-muted-foreground);
    white-space: nowrap;
    text-align: center;
  }
</style>
