<!--
  Frame.svelte - Root container component.

  This is the top-level container that mirrors MATLAB's ic.Frame.
  It receives child components as childEntries and
  renders them using {@render}.
-->
<script lang="ts">
  import type { ChildEntries, ThemeEventData } from '$lib/types';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  interface Props {
    id?: string;
    childEntries: ChildEntries;
    theme?: ThemeEventData;
    colorScheme?: 'light' | 'dark';
  }

  let {
    id = '',
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
        // camelCase → kebab-case (e.g. primaryForeground → primary-foreground)
        const kebab = prop.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
        return `--ic-${kebab}: ${resolved}`;
      })
    ];

    return styles.join('; ');
  });

  const children = $derived(childEntries.filter(c => !c.meta.mixins.includes('overlay')));
  const overlays = $derived(childEntries.filter(c => c.meta.mixins.includes('overlay')));
</script>

<div id={id || 'ic-frame'} class="ic-frame" style={themeStyle}>
  {#each children as child (child.id)}
    <DynamicChild entry={child} />
  {/each}

  <!-- Overlay layer — renders at root level, above normal content -->
  {#each overlays as overlay (overlay.id)}
    <DynamicChild entry={overlay} />
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
