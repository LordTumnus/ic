<!--
  DelayNode.svelte — Hourglass time-shift node.
  Clean Industrial Flat silhouette: two solid bars framing a smooth glass body.
  Dynamically mirrors input port type on output.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';

  type DelayData = {
    label: string;
    delayTime: number;
    unit: string;
    disabled: boolean;
    locked: boolean;
    inputs: PortDef[];
    outputs: PortDef[];
  };

  type DelayNodeType = Node<DelayData, 'ic.node.Delay'>;

  let { data, selected, dragging }: NodeProps<DelayNodeType> = $props();

  let hovered = $state(false);

  const displayDelay = $derived(() => {
    const t = data.delayTime ?? 1;
    const u = data.unit ?? 's';
    const formatted = Number.isInteger(t) ? t.toString() : t.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
    return `${formatted} ${u}`;
  });

  const strokeColor = $derived(
    selected
      ? 'var(--ic-primary)'
      : hovered && !dragging
        ? 'var(--ic-muted-foreground)'
        : 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-delay"
  class:ic-ne-delay--hovered={hovered && !selected && !dragging}
  class:ic-ne-delay--selected={selected}
  class:ic-ne-delay--dragging={dragging}
  class:ic-ne-delay--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg class="ic-ne-delay__svg" viewBox="0 0 36 48" xmlns="http://www.w3.org/2000/svg">
    <!--
      Simple hourglass: two bars + glass body
      viewBox 36×48

      Top bar:     rect y=2..6, x=2..34  (solid frame piece)
      Glass body:  smooth bezier from (4,7) pinching to waist at y=24, back out to (4,41)
      Bottom bar:  rect y=42..46, x=2..34
    -->

    <!-- Glass body — single symmetric path -->
    <path
      d="M 5,7 C 5,18 16,21 16,24 C 16,27 5,30 5,41
         L 31,41 C 31,30 20,27 20,24 C 20,21 31,18 31,7 Z"
      fill="var(--ic-muted)"
      stroke={strokeColor}
      stroke-width="1"
      stroke-linejoin="round"
    />

    <!-- Sand pile in bottom -->
    <path d="M 11,37 Q 18,33 25,37"
      fill="none" stroke="var(--ic-muted-foreground)" stroke-width="0.8"
      stroke-linecap="round" opacity="0.5" />

    <!-- Sand trickle -->
    <line x1="18" y1="22" x2="18" y2="28"
      stroke="var(--ic-muted-foreground)" stroke-width="0.6" opacity="0.4" />

    <!-- Top bar -->
    <rect x="2" y="2" width="32" height="5" rx="1.5"
      fill="var(--ic-secondary)"
      stroke={strokeColor}
      stroke-width="1"
    />

    <!-- Bottom bar -->
    <rect x="2" y="41" width="32" height="5" rx="1.5"
      fill="var(--ic-secondary)"
      stroke={strokeColor}
      stroke-width="1"
    />

    <!-- Delay value text -->
    <text
      x="18" y="24"
      class="ic-ne-delay__value"
      text-anchor="middle"
      dominant-baseline="middle"
    >{displayDelay()}</text>
  </svg>

  <!-- Input handle: left midpoint -->
  {#if data.inputs?.[0]}
    <Handle
      type="target"
      position={Position.Left}
      id={data.inputs[0].name}
    />
  {/if}

  <!-- Output handle: right midpoint -->
  {#if data.outputs?.[0]}
    <Handle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-delay__label">{data.label}</div>
{/if}

<style>
  .ic-ne-delay {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    transition: filter 0.15s ease;
  }

  .ic-ne-delay--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-delay--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-delay--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-delay--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-delay__svg {
    width: 36px;
    height: 48px;
    display: block;
  }

  .ic-ne-delay__value {
    font-family: monospace;
    font-size: 5.5px;
    font-weight: 700;
    fill: var(--ic-foreground);
    user-select: none;
    pointer-events: none;
  }

  .ic-ne-delay__label {
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
    pointer-events: none;
    user-select: none;
  }

  /* Hide SF's default handle visuals */
  .ic-ne-delay :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
