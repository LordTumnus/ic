<script lang="ts">
  let {
    value,
    config = {},
  }: {
    value?: unknown;
    config?: Record<string, unknown>;
  } = $props();

  const colorMap = $derived((config.colorMap as Record<string, string>) ?? {});

  const variant = $derived(
    value != null ? (colorMap[String(value)] ?? 'secondary') : 'secondary'
  );

  const VARIANT_STYLES: Record<string, string> = {
    primary: 'var(--ic-primary)',
    secondary: 'var(--ic-secondary)',
    success: 'var(--ic-success)',
    warning: 'var(--ic-warning)',
    destructive: 'var(--ic-destructive)',
  };

  const bg = $derived(VARIANT_STYLES[variant] ?? VARIANT_STYLES.secondary);
  const isBright = $derived(variant === 'primary' || variant === 'destructive');
</script>

{#if value != null && value !== ''}
  <span
    class="ic-tbl-cell-badge"
    class:ic-tbl-cell-badge--bright={isBright}
    style:background-color={bg}
  >
    {value}
  </span>
{/if}

<style>
  .ic-tbl-cell-badge {
    display: inline-flex;
    align-items: center;
    padding: 1px 6px;
    border-radius: 2px;
    font-size: 0.75em;
    font-weight: 500;
    white-space: nowrap;
    color: var(--ic-secondary-foreground);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
  }
  .ic-tbl-cell-badge--bright {
    color: var(--ic-primary-foreground);
  }
</style>
