<!--
  TabPanel.svelte — Content container for a tab.
  Bare container that renders its children via snippets.
-->
<script lang="ts">
  import type { ChildEntries } from '$lib/types';

  let {
    childEntries = {} as ChildEntries,
  }: {
    childEntries?: ChildEntries;
  } = $props();
</script>

{#each childEntries.default ?? [] as child (child)}
  {@render child.snippet()}
{/each}
