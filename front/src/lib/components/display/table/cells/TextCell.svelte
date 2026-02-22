<script lang="ts">
  import type { TextConfig } from '$lib/utils/table-utils';
  import { parseInlineRichText } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<TextConfig>,
  }: {
    value?: unknown;
    config?: Partial<TextConfig>;
  } = $props();

  const raw = $derived(String(value ?? ''));
  const isEmpty = $derived(value == null || raw === '');
  const placeholder = $derived(config.placeholder ?? '');
  const richText = $derived(config.richText ?? false);
  const transform = $derived(config.transform ?? 'none');

  // For tooltip: always show raw text, not HTML
  const display = $derived(isEmpty ? placeholder : raw);
  // For rich text rendering
  const html = $derived(richText && !isEmpty ? parseInlineRichText(raw) : '');

  let el = $state<HTMLSpanElement>(null!);
  let title = $state('');

  function onenter() {
    if (el.scrollWidth > el.clientWidth) title = isEmpty ? '' : raw;
  }
  function onleave() { title = ''; }
</script>

{#if richText && !isEmpty}
  <span
    bind:this={el}
    class="ic-tbl-cell-text"
    class:ic-tbl-cell-text--transform={transform !== 'none'}
    style:text-transform={transform !== 'none' ? transform : undefined}
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{@html html}</span>
{:else}
  <span
    bind:this={el}
    class="ic-tbl-cell-text"
    class:ic-tbl-cell-text--placeholder={isEmpty && placeholder !== ''}
    class:ic-tbl-cell-text--transform={transform !== 'none'}
    style:text-transform={transform !== 'none' ? transform : undefined}
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{display}</span>
{/if}

<style>
  .ic-tbl-cell-text {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ic-tbl-cell-text--placeholder {
    color: var(--ic-muted-foreground);
    font-style: italic;
  }
</style>
