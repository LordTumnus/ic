<script lang="ts">
  import type { ChildEntries } from '$lib/types';

  let {
    childEntries = { default: [] } as ChildEntries,
  }: {
    childEntries?: ChildEntries;
  } = $props();
</script>

<div class="ic-panel">
  {#each childEntries.default ?? [] as child (child)}
    {@render child.snippet()}
  {/each}
</div>

<style>
  .ic-panel {
    display: block;
  }
</style>
