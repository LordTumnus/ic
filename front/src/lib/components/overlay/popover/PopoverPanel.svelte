<!--
  PopoverPanel.svelte — Content container for a Popover.

  Renders children inside a styled panel. Visual styling (background, border,
  shadow) lives here; positioning/transitions are on the parent Popover.
-->
<script lang="ts">
  import type { ChildEntries } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    childEntries?: ChildEntries;
  } = $props();
</script>

<div {id} class="ic-po-panel">
  {#each childEntries as child (child.id)}
    <DynamicChild entry={child} />
  {/each}
</div>

<style>
  .ic-po-panel {
    background-color: var(--ic-background);
    border: 1px solid var(--ic-border);
    border-radius: 3px;
    box-shadow:
      0 4px 16px rgba(0, 0, 0, 0.2),
      0 1px 4px rgba(0, 0, 0, 0.1),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
    min-width: 120px;
    overflow: clip;
    padding: 8px;
  }
</style>
