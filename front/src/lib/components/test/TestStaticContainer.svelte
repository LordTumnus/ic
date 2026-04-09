<!--
  TestStaticContainer.svelte - Test container with a single static TestComponent child.

  This component tests the static composition pattern where a child is
  declared in MATLAB constructor and passed as a pre-built Map.

  Expects a static child in target 'child' (a TestComponent).
-->
<script lang="ts">
  import { untrack } from 'svelte';
  import type { Resolution, ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    title = $bindable('Static Container'),
    childCounter = $bindable(0),
    childEntries = [] as ChildEntries,

    // Method handler (MATLAB calls this, we provide implementation)
    getState = $bindable((): Resolution => ({ success: true, data: null })),
  }: {
    id?: string;
    title?: string;
    childCounter?: number;
    childEntries?: ChildEntries;
    getState?: () => Resolution;
  } = $props();

  // Set up method implementation
  $effect(() => {
    getState = (): Resolution => {
      return {
        success: true,
        data: { title, childCounter }
      };
    };
  });

  // Access the static child (first entry in the flat array)
  const childSlot = $derived(childEntries);
  const child = $derived(childSlot[0]);

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

<div {id} class="test-static-container" data-testid="test-static-container">
  <div class="title" data-testid="container-title">{title}</div>
  <div class="child-counter" data-testid="child-counter">Child counter: {childCounter}</div>

  <div class="child-slot" data-testid="child-slot">
    {#each childSlot as staticChild (staticChild.id)}
      <DynamicChild entry={staticChild} />
    {:else}
      <span class="empty-slot">No static child</span>
    {/each}
  </div>

  <div class="dynamic-slot" data-testid="dynamic-slot">
    {#each childEntries.slice(1) as dynamicChild (dynamicChild.id)}
      <DynamicChild entry={dynamicChild} />
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
