<script lang="ts">
  import type { Snippets } from '$lib/types';

  let {
    snippets = { default: [] } as Snippets,
  }: {
    snippets?: Snippets;
  } = $props();
</script>

<div class="ic-panel">
  {#each snippets.default ?? [] as child (child)}
    {@render child()}
  {/each}
</div>

<style>
  .ic-panel {
    display: block;
  }
</style>
