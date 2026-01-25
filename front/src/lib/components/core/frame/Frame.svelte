<!--
  Frame.svelte - Root container component.

  This is the top-level container that mirrors MATLAB's ic.Frame.
  It receives child components as snippets in the `slots` prop and
  renders them using {@render}.

  Unlike other components, Frame:
  - Is created directly during setup, not via @insert
  - Has a fixed ID: "@ic.frame"
  - Is mounted directly to document.body
-->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let { default: defaultSlot = [] }: { default?: Snippet[] } = $props();
</script>

<div class="ic-frame">
  {#each defaultSlot as child}
    {@render child()}
  {/each}
</div>

<style>
  .ic-frame {
    width: 100%;
    height: 100%;
  }
</style>
