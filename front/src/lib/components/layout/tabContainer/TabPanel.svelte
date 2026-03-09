<!--
  TabPanel.svelte — Content container for a tab.
  Bare container that renders its children via snippets.
-->
<script lang="ts">
  import type { Snippets } from '$lib/types';

  let {
    snippets = {} as Snippets,
  }: {
    snippets?: Snippets;
  } = $props();
</script>

{#each snippets.default ?? [] as child (child)}
  {@render child()}
{/each}
