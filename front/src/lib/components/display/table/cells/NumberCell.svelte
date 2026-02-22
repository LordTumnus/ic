<script lang="ts">
  import type { NumberConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { formatNumberWithConfig, evaluateColorRules } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<NumberConfig>,
  }: {
    value?: unknown;
    config?: Partial<NumberConfig>;
  } = $props();

  const numVal = $derived(value != null ? Number(value) : null);

  const cfg: NumberConfig = $derived({
    decimals: config.decimals ?? -1,
    prefix: config.prefix ?? '',
    suffix: config.suffix ?? '',
    thousandsSeparator: config.thousandsSeparator ?? false,
    colorRules: config.colorRules,
  });

  const display = $derived(
    numVal != null ? formatNumberWithConfig(numVal, cfg) : ''
  );

  const bgColor = $derived(
    numVal != null && cfg.colorRules?.length
      ? evaluateColorRules(numVal, cfg.colorRules)
      : null
  );
</script>

<span
  class="ic-tbl-cell-number"
  class:ic-tbl-cell-number--tinted={bgColor != null}
  style:background-color={bgColor}
>{display}</span>

<style>
  .ic-tbl-cell-number {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    border-radius: 2px;
    transition: background-color 0.15s ease;
  }
  .ic-tbl-cell-number--tinted {
    padding: 0 4px;
    color: rgba(0, 0, 0, 0.85);
  }
</style>
