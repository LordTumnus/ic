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
    fillFirstChild?: boolean;
  }

  let {
    snippets,
    theme = {},
    colorScheme = $bindable('light'),
    fillFirstChild = $bindable(false),
  }: Props = $props();

  // Build inline style string from theme object and color scheme
  // Theme values are either [light, dark] arrays or single values
  const themeStyle = $derived.by(() => {
    const styles = [
      `color-scheme: ${colorScheme}`,
      ...Object.entries(theme).map(([prop, value]) => {
        const resolved = Array.isArray(value)
          ? value[colorScheme === 'light' ? 0 : 1]
          : value;
        return `--ic-${prop}: ${resolved}`;
      })
    ];

    if (fillFirstChild) {
      styles.push('display: flex', 'flex-direction: column');
    }

    return styles.join('; ');
  });

  const children = $derived(snippets.default ?? []);
</script>

<div id="ic-frame" class="ic-frame" style={themeStyle}>
  {#if fillFirstChild && children.length > 0}
    <!-- First child gets a wrapper to ensure fill behavior -->
    <div class="ic-frame__fill-wrapper">
      {@render children[0]()}
    </div>
    <!-- Remaining children render normally -->
    {#each children.slice(1) as child, i (i + 1)}
      {@render child()}
    {/each}
  {:else}
    {#each children as child, i (i)}
      {@render child()}
    {/each}
  {/if}
</div>

<style>
  .ic-frame {
    width: 100%;
    height: 100%;
  }

  .ic-frame__fill-wrapper {
    flex: 1;
    min-height: 0;
    min-width: 0;
    position: relative;
  }

  .ic-frame__fill-wrapper > :global(*) > :global(*) {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
  }
</style>
