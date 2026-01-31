<script lang="ts">
  import type { Snippets } from '$lib/types';
  import type { CssGridTemplate, CssSpacing } from '$lib/utils/css';
  import { toGridTemplate, toSpacing } from '$lib/utils/css';

  let {
    columns = $bindable<CssGridTemplate>('1fr'),
    rows = $bindable<CssGridTemplate>('auto'),
    gap = $bindable<CssSpacing>(8),
    alignItems = $bindable('stretch'),
    justifyItems = $bindable('stretch'),
    autoFlow = $bindable('row'),
    padding = $bindable<CssSpacing>(0),
    snippets = { default: [] } as Snippets,
  }: {
    columns?: CssGridTemplate;
    rows?: CssGridTemplate;
    gap?: CssSpacing;
    alignItems?: 'start' | 'center' | 'end' | 'stretch' | 'baseline';
    justifyItems?: 'start' | 'center' | 'end' | 'stretch';
    autoFlow?: 'row' | 'column' | 'dense' | 'row-dense' | 'column-dense';
    padding?: CssSpacing;
    snippets?: Snippets;
  } = $props();
</script>

<div
  class="ic-grid"
  style:grid-template-columns={toGridTemplate(columns)}
  style:grid-template-rows={toGridTemplate(rows)}
  style:gap={toSpacing(gap)}
  style:align-items={alignItems}
  style:justify-items={justifyItems}
  style:grid-auto-flow={autoFlow}
  style:padding={toSpacing(padding)}
>
  {#each snippets.default ?? [] as child, i (i)}
    {@render child()}
  {/each}
</div>

<style>
  .ic-grid {
    display: grid;
    min-width: 0;
    min-height: 0;
  }
</style>
