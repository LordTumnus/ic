<!--
  Frame.svelte - Root container component.

  This is the top-level container that mirrors MATLAB's ic.Frame.
  It receives child components as childEntries and
  renders them using {@render}.
-->
<script lang="ts">
  import type { ChildEntries, ThemeEventData } from '$lib/types';

  interface Props {
    childEntries: ChildEntries;
    theme?: ThemeEventData;
    colorScheme?: 'light' | 'dark';
  }

  let {
    childEntries,
    theme = {},
    colorScheme = $bindable('light'),
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

    return styles.join('; ');
  });

  const children = $derived(childEntries.default ?? []);
  const overlays = $derived(childEntries.overlay ?? []);
</script>

<div id="ic-frame" class="ic-frame" style={themeStyle}>
  {#each children as child (child)}
    {@render child.snippet()}
  {/each}

  <!-- Overlay layer — renders at root level, above normal content -->
  {#each overlays as overlay (overlay)}
    {@render overlay.snippet()}
  {/each}
</div>

<style>
  .ic-frame {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: clip;
  }
</style>
