<!--
  RandomNode.svelte — 3D isometric dice source node.
  Three visible faces (top, front, right) with pip patterns.
  Industrial Flat: muted face colors, sharp edges.
-->
<script lang="ts">
  import { Handle, Position, type NodeProps, type Node } from '@xyflow/svelte';
  import type { PortDef } from '$lib/utils/node-editor-types';

  type RandomData = {
    label: string;
    disabled: boolean;
    locked: boolean;
    outputs: PortDef[];
  };

  type RandomNodeType = Node<RandomData, 'ic.node.Random'>;

  let { data, selected, dragging }: NodeProps<RandomNodeType> = $props();

  let hovered = $state(false);

  const strokeColor = $derived(
    selected ? 'var(--ic-primary)' : 'var(--ic-border)',
  );
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="ic-ne-random"
  class:ic-ne-random--hovered={hovered && !selected && !dragging}
  class:ic-ne-random--selected={selected}
  class:ic-ne-random--dragging={dragging}
  class:ic-ne-random--disabled={data.disabled}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <svg
    class="ic-ne-random__die"
    viewBox="0 0 52 56"
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- 3D isometric dice: top, front (left-facing), right (right-facing) -->

    <!-- Top face (lightest) -->
    <polygon
      points="26,4 48,16 26,28 4,16"
      fill="var(--ic-muted)"
      stroke={strokeColor}
      stroke-width="1.2"
      stroke-linejoin="round"
    />
    <!-- Front face (medium) -->
    <polygon
      points="4,16 26,28 26,52 4,40"
      fill="var(--ic-background)"
      stroke={strokeColor}
      stroke-width="1.2"
      stroke-linejoin="round"
    />
    <!-- Right face (darkest) -->
    <polygon
      points="26,28 48,16 48,40 26,52"
      fill="var(--ic-secondary)"
      stroke={strokeColor}
      stroke-width="1.2"
      stroke-linejoin="round"
    />

    <!--
      Isometric pip placement using face basis vectors.
      Top face: origin(4,16), u=(22,12) to (48,16), v=(22,-12) to (26,4)
      Front face: origin(4,16), u=(22,12) to (26,28), v=(0,24) to (4,40)
      Right face: origin(48,16), u=(-22,12) to (26,28), v=(0,24) to (48,40)
    -->

    <!-- Top face pips: 3 (diagonal) -->
    <!-- Positions at (0.25,0.25), (0.5,0.5), (0.75,0.75) in face-local coords -->
    <circle cx="15" cy="16" r="1.8" fill="var(--ic-muted-foreground)" opacity="0.7" />
    <circle cx="26" cy="16" r="1.8" fill="var(--ic-muted-foreground)" opacity="0.7" />
    <circle cx="37" cy="16" r="1.8" fill="var(--ic-muted-foreground)" opacity="0.7" />

    <!-- Front face pips: 5 (X pattern) -->
    <!-- Face spans (4,16)→(26,28)→(26,52)→(4,40), center at (15,34) -->
    <circle cx="10" cy="24" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.6" />
    <circle cx="20" cy="30" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.6" />
    <circle cx="15" cy="34" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.6" />
    <circle cx="10" cy="38" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.6" />
    <circle cx="20" cy="44" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.6" />

    <!-- Right face pips: 2 (diagonal) -->
    <!-- Face spans (26,28)→(48,16)→(48,40)→(26,52), center at (37,34) -->
    <circle cx="32" cy="30" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.5" />
    <circle cx="42" cy="38" r="1.6" fill="var(--ic-muted-foreground)" opacity="0.5" />
  </svg>

  <!-- Output handle on right -->
  {#if data.outputs?.[0]}
    <Handle
      type="source"
      position={Position.Right}
      id={data.outputs[0].name}
    />
  {/if}
</div>

{#if data.label}
  <div class="ic-ne-random__label">{data.label}</div>
{/if}

<style>
  .ic-ne-random {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    transition: filter 0.15s ease;
  }

  .ic-ne-random--hovered {
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.12));
  }

  .ic-ne-random--selected {
    filter: drop-shadow(0 0 4px rgba(var(--ic-primary-rgb, 59, 130, 246), 0.4));
  }

  .ic-ne-random--dragging {
    filter: drop-shadow(0 3px 8px rgba(0, 0, 0, 0.25));
  }

  .ic-ne-random--disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  .ic-ne-random__die {
    width: 52px;
    height: 56px;
    display: block;
  }

  .ic-ne-random__label {
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
  .ic-ne-random :global(.svelte-flow__handle) {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    background: transparent;
    border: none;
  }
</style>
