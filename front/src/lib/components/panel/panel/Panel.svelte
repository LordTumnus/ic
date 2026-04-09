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

<div {id} class="ic-panel">
  {#each childEntries as child (child.id)}
    <DynamicChild entry={child} />
  {/each}
</div>

<style>
  .ic-panel {
    display: block;
  }
</style>
