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
    colorScheme?: 'light' | 'dark';
  }

  let { snippets, theme = {}, colorScheme = $bindable('light') }: Props = $props();

  // Build inline style string from theme object and color scheme
  // Theme values are either [light, dark] arrays or single values
  const themeStyle = $derived(
    [
      `color-scheme: ${colorScheme}`,
      ...Object.entries(theme).map(([prop, value]) => {
        const resolved = Array.isArray(value)
          ? value[colorScheme === 'light' ? 0 : 1]
          : value;
        return `--ic-${prop}: ${resolved}`;
      })
    ].join('; ')
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
