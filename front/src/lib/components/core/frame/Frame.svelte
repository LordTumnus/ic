<!--
  Frame.svelte - Root container component.

  This is the top-level container that mirrors MATLAB's ic.Frame.
  It receives child components as snippets in the `snippets` prop and
  renders them using {@render}.
-->
<script lang="ts">
  import type { Snippets, ThemeEventData } from '$lib/types';

  interface Props {
    snippets: Snippets;
    theme?: ThemeEventData;
  }

  let { snippets, theme = {} }: Props = $props();

  // Build inline style string from theme object
  const themeStyle = $derived(
    Object.entries(theme)
      .map(([prop, value]) => `${prop}: ${value}`)
      .join('; ')
  );
</script>

<div id="ic-frame" class="ic-frame" style={themeStyle}>
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
