<!--
  TabPanel.svelte — Content container for a tab.
  Bare container that renders its children via snippets.
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

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
