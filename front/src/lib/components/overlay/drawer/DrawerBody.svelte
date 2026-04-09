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

<div {id} class="ic-drawer-body">
  {#each childEntries as child (child.id)}
    <DynamicChild entry={child} />
  {/each}
</div>

<style>
  .ic-drawer-body {
    flex: 1;
    overflow: auto;
    padding: 16px;
  }
</style>
