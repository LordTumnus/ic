<script lang="ts">
  import type { TextConfig } from '$lib/utils/table-utils';
  import { parseInlineRichText } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<TextConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<TextConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
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
    if (el?.scrollWidth > el?.clientWidth) title = isEmpty ? '' : raw;
  }
  function onleave() { title = ''; }

  // ── Edit mode ──────────────────────────────────
  let editValue = $state('');

  $effect(() => {
    if (editing) editValue = raw;
  });

  function handleEditKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Enter') {
      e.preventDefault();
      oncommitedit?.(value, editValue);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      oncanceledit?.();
    }
  }

  function handleEditBlur() {
    oncommitedit?.(value, editValue);
  }

  function autofocus(node: HTMLInputElement) {
    requestAnimationFrame(() => { node.focus(); node.select(); });
  }
</script>

{#if editing}
  <input
    type="text"
    class="ic-tbl-cell-text__edit"
    bind:value={editValue}
    onkeydown={handleEditKeydown}
    onblur={handleEditBlur}
    use:autofocus
  />
{:else if richText && !isEmpty}
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
  .ic-tbl-cell-text__edit {
    width: 100%;
    height: 100%;
    padding: 0 4px;
    margin: 0;
    border: 1px solid var(--ic-primary);
    border-radius: 2px;
    background: var(--ic-background);
    color: var(--ic-foreground);
    font: inherit;
    text-align: inherit;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
    outline: none;
    box-sizing: border-box;
  }
</style>
