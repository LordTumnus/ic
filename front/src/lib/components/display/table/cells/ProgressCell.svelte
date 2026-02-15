<script lang="ts">
  let {
    value,
    config = {},
  }: {
    value?: unknown;
    config?: Record<string, unknown>;
  } = $props();

  const variant = $derived((config.variant as string) ?? 'primary');
  const pct = $derived(Math.max(0, Math.min(100, Number(value ?? 0) * 100)));
  const colorVar = $derived(`var(--ic-${variant})`);
</script>

<div class="ic-tbl-cell-progress">
  <div class="ic-tbl-cell-progress__track">
    <div
      class="ic-tbl-cell-progress__fill"
      style:width="{pct}%"
      style:background-color={colorVar}
    ></div>
  </div>
</div>

<style>
  .ic-tbl-cell-progress {
    display: flex;
    align-items: center;
    width: 100%;
    padding: 0 2px;
  }
  .ic-tbl-cell-progress__track {
    flex: 1;
    height: 4px;
    border-radius: 2px;
    background: var(--ic-secondary);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    overflow: hidden;
  }
  .ic-tbl-cell-progress__fill {
    height: 100%;
    border-radius: 2px;
    opacity: 0.85;
    transition: width 0.15s ease;
  }
</style>
