<script lang="ts">
  import type { ChildEntries } from '$lib/types';
  import type { CssGridTemplate, CssSpacing } from '$lib/utils/css';
  import { toGridTemplate, toSpacing } from '$lib/utils/css';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    columns = $bindable<CssGridTemplate>('1fr'),
    rows = $bindable<CssGridTemplate>('auto'),
    gap = $bindable<CssSpacing>(8),
    alignItems = $bindable('stretch'),
    justifyItems = $bindable('stretch'),
    autoFlow = $bindable('row'),
    padding = $bindable<CssSpacing>(0),
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    columns?: CssGridTemplate;
    rows?: CssGridTemplate;
    gap?: CssSpacing;
    alignItems?: 'start' | 'center' | 'end' | 'stretch' | 'baseline';
    justifyItems?: 'start' | 'center' | 'end' | 'stretch';
    autoFlow?: 'row' | 'column' | 'dense' | 'row-dense' | 'column-dense';
    padding?: CssSpacing;
    childEntries?: ChildEntries;
  } = $props();
</script>

<div {id}
  class="ic-grid"
  style:grid-template-columns={toGridTemplate(columns)}
  style:grid-template-rows={toGridTemplate(rows)}
  style:gap={toSpacing(gap)}
  style:align-items={alignItems}
  style:justify-items={justifyItems}
  style:grid-auto-flow={autoFlow}
  style:padding={toSpacing(padding)}
>
  {#each childEntries as child (child.id)}
    <DynamicChild entry={child} />
  {/each}
</div>

<style>
  .ic-grid {
    display: grid;
    min-width: 0;
    min-height: 0;
  }
</style>
