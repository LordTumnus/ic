<script lang="ts">
  let { value }: { value?: unknown } = $props();
  const checked = $derived(Boolean(value));
</script>

<span class="ic-tbl-cell-bool" class:ic-tbl-cell-bool--checked={checked}>
  {#if checked}
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M2.5 6L5 8.5L9.5 3.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  {/if}
</span>

<style>
  .ic-tbl-cell-bool {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    border-radius: 2px;
    background: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    color: var(--ic-primary-foreground);
    transition: all 0.1s ease;
  }
  .ic-tbl-cell-bool--checked {
    background: var(--ic-primary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.18);
  }
</style>
