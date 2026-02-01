<script lang="ts">
  import type { Snippets } from '$lib/types';
  import type { CssSpacing } from '$lib/utils/css';
  import { toSpacing } from '$lib/utils/css';

  let {
    direction = $bindable('row'),
    wrap = $bindable('nowrap'),
    justifyContent = $bindable('start'),
    alignItems = $bindable('stretch'),
    gap = $bindable<CssSpacing>(8),
    padding = $bindable<CssSpacing>(0),
    snippets = { default: [] } as Snippets,
  }: {
    direction?: 'row' | 'column' | 'row-reverse' | 'column-reverse';
    wrap?: 'nowrap' | 'wrap' | 'wrap-reverse';
    justifyContent?: 'start' | 'center' | 'end' | 'space-between' | 'space-around' | 'space-evenly';
    alignItems?: 'start' | 'center' | 'end' | 'stretch' | 'baseline';
    gap?: CssSpacing;
    padding?: CssSpacing;
    snippets?: Snippets;
  } = $props();

  // Map shorthand values to CSS values
  const justifyMap: Record<string, string> = {
    start: 'flex-start',
    center: 'center',
    end: 'flex-end',
    'space-between': 'space-between',
    'space-around': 'space-around',
    'space-evenly': 'space-evenly',
  };

  const alignMap: Record<string, string> = {
    start: 'flex-start',
    center: 'center',
    end: 'flex-end',
    stretch: 'stretch',
    baseline: 'baseline',
  };
</script>

<div
  class="ic-flex"
  style:flex-direction={direction}
  style:flex-wrap={wrap}
  style:justify-content={justifyMap[justifyContent]}
  style:align-items={alignMap[alignItems]}
  style:gap={toSpacing(gap)}
  style:padding={toSpacing(padding)}
>
  {#each snippets.default ?? [] as child (child)}
    {@render child()}
  {/each}
</div>

<style>
  .ic-flex {
    display: flex;
    min-width: 0;
    min-height: 0;
  }
</style>
