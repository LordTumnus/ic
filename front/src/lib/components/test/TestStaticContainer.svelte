<!--
  TestStaticContainer.svelte - Test container with a single static TestComponent child.

  This component tests the static composition pattern where a child is
  declared in MATLAB constructor and passed as a pre-built Map.

  Expects a static child with suffix 'child' (a TestComponent).
-->
<script lang="ts">
  import { untrack } from 'svelte';
  import type { Snippets, StaticChildrenMap } from '$lib/types';

  let {
    title = $bindable('Static Container'),
    childCounter = $bindable(0),
    snippets = { default: [] } as Snippets,
    staticChildren = new Map() as StaticChildrenMap,
  }: {
    title?: string;
    childCounter?: number;
    snippets?: Snippets;
    staticChildren?: StaticChildrenMap;
  } = $props();

  // Access the static child by its suffix name
  const child = $derived(staticChildren.get('child'));

  // FRONTEND-ONLY WIRING: Bidirectional sync between parent and child counter
  // This happens entirely in Svelte - no roundtrip to MATLAB!
  // Uses untrack() to prevent circular dependency issues.

  // Child → Parent: Mirror child's counter to parent's childCounter
  $effect(() => {
    if (child?.props.counter !== undefined) {
      const childValue = child.props.counter as number;
      const parentValue = untrack(() => childCounter);
      if (childValue !== parentValue) {
        childCounter = childValue;
      }
    }
  });

  // Parent → Child: Mirror parent's childCounter to child's counter
  $effect(() => {
    const parentValue = childCounter;
    if (child?.props.counter !== undefined) {
      const childValue = untrack(() => child.props.counter as number);
      if (parentValue !== childValue) {
        child.props.counter = parentValue;
      }
    }
  });
</script>

<div class="test-static-container" data-testid="test-static-container">
  <div class="title" data-testid="container-title">{title}</div>
  <div class="child-counter" data-testid="child-counter">Child counter: {childCounter}</div>

  <div class="child-slot" data-testid="child-slot">
    {#if child}
      {@render child.snippet()}
    {:else}
      <span class="empty-slot">No static child</span>
    {/if}
  </div>

  <div class="dynamic-slot" data-testid="dynamic-slot">
    {#each snippets.default ?? [] as dynamicChild}
      {@render dynamicChild()}
    {/each}
  </div>
</div>

<style>
  .test-static-container {
    padding: 1rem;
    border: 2px solid #333;
    border-radius: 8px;
    font-family: system-ui, sans-serif;
  }

  .title {
    font-size: 1.4rem;
    font-weight: bold;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #ccc;
  }

  .child-slot,
  .dynamic-slot {
    margin: 0.5rem 0;
    padding: 0.5rem;
    border: 1px dashed #999;
    border-radius: 4px;
    min-height: 2rem;
  }

  .empty-slot {
    color: #999;
    font-style: italic;
  }
</style>
