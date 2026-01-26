<!--
  Frame.svelte - Root container component.

  This is the top-level container that mirrors MATLAB's ic.Frame.
  It receives child components as snippets in the `snippets` prop and
  renders them using {@render}.
-->
<script lang="ts">
  import type { Snippets } from '$lib/types';

  let { snippets }: { snippets: Snippets } = $props();
</script>

<div class="ic-frame">
  {#each snippets.default ?? [] as child}
    {@render child()}
  {/each}
</div>

<style>
  .ic-frame {
    width: 100%;
    height: 100%;
    background-color: red;
  }
</style>
