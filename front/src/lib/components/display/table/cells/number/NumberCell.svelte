<script lang="ts">
  import type { NumberConfig } from '$lib/utils/table-utils';
  import { formatNumberWithConfig, evaluateColorRules } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<NumberConfig>,
    style = $bindable(''),
  }: {
    value?: unknown;
    config?: Partial<NumberConfig>;
    style?: string;
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

  $effect(() => {
    style = bgColor
      ? `background-color: ${bgColor}; color: rgba(0,0,0,0.85);`
      : '';
  });

  let el = $state<HTMLSpanElement>(null!);
  let title = $state('');

  function onenter() {
    if (el.scrollWidth > el.clientWidth) title = display;
  }
  function onleave() { title = ''; }
</script>

<span
  bind:this={el}
  class="ic-tbl-cell-number"
  {title}
  onpointerenter={onenter}
  onpointerleave={onleave}
>{display}</span>

<style>
  .ic-tbl-cell-number {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }
</style>
