<script lang="ts">
  let {
    value,
    config = {},
    rowData = {},
  }: {
    value?: unknown;
    config?: Record<string, unknown>;
    rowData?: Record<string, unknown>;
  } = $props();

  const textField = $derived(config.textField as string | undefined);
  const radius = $derived((config.radius as number) ?? 14);
  const src = $derived(value != null ? String(value) : '');
  const text = $derived(textField && rowData[textField] != null ? String(rowData[textField]) : '');

  // Generate initials fallback
  const initials = $derived(
    text
      ? text.split(/\s+/).slice(0, 2).map(w => w[0]?.toUpperCase() ?? '').join('')
      : ''
  );
</script>

<span class="ic-tbl-cell-avatar">
  {#if src}
    <img
      class="ic-tbl-cell-avatar__img"
      src={src}
      alt={text || 'avatar'}
      style:width="{radius * 2}px"
      style:height="{radius * 2}px"
      style:border-radius="{radius}px"
    />
  {:else if initials}
    <span
      class="ic-tbl-cell-avatar__fallback"
      style:width="{radius * 2}px"
      style:height="{radius * 2}px"
      style:border-radius="{radius}px"
      style:font-size="{radius * 0.7}px"
    >
      {initials}
    </span>
  {/if}
  {#if text}
    <span class="ic-tbl-cell-avatar__text">{text}</span>
  {/if}
</span>

<style>
  .ic-tbl-cell-avatar {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    overflow: hidden;
  }
  .ic-tbl-cell-avatar__img {
    object-fit: cover;
    flex-shrink: 0;
  }
  .ic-tbl-cell-avatar__fallback {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    background: var(--ic-secondary);
    color: var(--ic-muted-foreground);
    font-weight: 600;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
  }
  .ic-tbl-cell-avatar__text {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
