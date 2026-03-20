<!--
  PortHandle.svelte — Visible port handle for node editor nodes.
  Wraps SvelteFlow's invisible <Handle> with a visible SVG indicator.

  Variants:
    dot       6px colored square, 2px radius (default)
    chevron   Small > arrow (Gain output)
    bar       Horizontal bar 4×8px (Delay ports)
    wave      Tiny sine squiggle (Signal/Random output)
    diamond   Small rotated square (Clock output)
-->
<script lang="ts">
  import { Handle, Position } from '@xyflow/svelte';

  type Variant = 'dot' | 'chevron' | 'bar' | 'wave' | 'diamond';

  let {
    type,
    position,
    id,
    variant = 'dot',
    color = 'var(--ic-muted-foreground)',
    style = '',
  }: {
    type: 'source' | 'target';
    position: Position;
    id: string;
    variant?: Variant;
    color?: string;
    style?: string;
  } = $props();

  const isLeft = $derived(position === Position.Left);
</script>

<div
  class="ic-ph"
  class:ic-ph--left={isLeft}
  class:ic-ph--right={!isLeft}
  {style}
>
  <!-- Invisible SvelteFlow handle (connection target) -->
  <Handle {type} {position} {id} />

  <!-- Visible indicator -->
  {#if variant === 'dot'}
    <span class="ic-ph__dot" style:background-color={color}></span>

  {:else if variant === 'chevron'}
    <svg class="ic-ph__icon" viewBox="0 0 8 10" xmlns="http://www.w3.org/2000/svg">
      <polyline
        points="1,1 6,5 1,9"
        fill="none"
        stroke={color}
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>

  {:else if variant === 'bar'}
    <span class="ic-ph__bar" style:background-color={color}></span>

  {:else if variant === 'wave'}
    <svg class="ic-ph__icon" viewBox="0 0 12 8" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M 0.5,4 C 2,1 4,1 5.5,4 C 7,7 9,7 11.5,4"
        fill="none"
        stroke={color}
        stroke-width="1.2"
        stroke-linecap="round"
      />
    </svg>

  {:else if variant === 'diamond'}
    <svg class="ic-ph__icon ic-ph__icon--diamond" viewBox="0 0 8 8" xmlns="http://www.w3.org/2000/svg">
      <rect
        x="1" y="1" width="6" height="6" rx="0.5"
        fill={color}
        transform="rotate(45 4 4)"
      />
    </svg>
  {/if}
</div>

<style>
  .ic-ph {
    position: absolute;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
    z-index: 1;
  }

  /* Position the indicator near the edge of the node */
  .ic-ph--left {
    left: -3px;
    top: 50%;
    transform: translateY(-50%);
  }

  .ic-ph--right {
    right: -3px;
    top: 50%;
    transform: translateY(-50%);
  }

  /* The SvelteFlow handle stays invisible but fully clickable */
  .ic-ph :global(.svelte-flow__handle) {
    width: 14px;
    height: 14px;
    border-radius: 2px;
    background: transparent;
    border: none;
    pointer-events: all;
  }

  /* -- Variant: dot -- */
  .ic-ph__dot {
    width: 6px;
    height: 6px;
    border-radius: 2px;
    position: absolute;
    pointer-events: none;
  }

  /* -- Variant: bar -- */
  .ic-ph__bar {
    width: 8px;
    height: 4px;
    border-radius: 1px;
    position: absolute;
    pointer-events: none;
  }

  /* -- Variant: chevron / wave / diamond -- */
  .ic-ph__icon {
    width: 10px;
    height: 10px;
    position: absolute;
    pointer-events: none;
  }

  .ic-ph__icon--diamond {
    width: 8px;
    height: 8px;
  }
</style>
