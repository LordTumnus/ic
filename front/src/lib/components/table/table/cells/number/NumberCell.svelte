<script lang="ts">
  import type { NumberConfig } from '$lib/utils/table-utils';
  import { formatNumberWithConfig, evaluateColorRules } from '$lib/utils/table-utils';
  import { toComparable } from './utils';

  let {
    value,
    config = {} as Partial<NumberConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<NumberConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
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
      ? evaluateColorRules(numVal, cfg.colorRules, toComparable)
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

  // ── Edit mode ──────────────────────────────────
  let editValue = $state('');

  $effect(() => {
    if (editing) editValue = numVal != null ? String(numVal) : '';
  });

  function handleEditKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Enter') {
      e.preventDefault();
      commitNumber();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      oncanceledit?.();
    }
  }

  function commitNumber() {
    const parsed = parseFloat(editValue);
    if (isNaN(parsed)) {
      oncanceledit?.();
    } else {
      oncommitedit?.(value, parsed);
    }
  }

  function handleEditBlur() {
    commitNumber();
  }

  function autofocus(node: HTMLInputElement) {
    requestAnimationFrame(() => { node.focus(); node.select(); });
  }
</script>

{#if editing}
  <input
    type="number"
    class="ic-tbl-cell-number__edit"
    bind:value={editValue}
    onkeydown={handleEditKeydown}
    onblur={handleEditBlur}
    use:autofocus
  />
{:else}
  <span
    bind:this={el}
    class="ic-tbl-cell-number"
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{display}</span>
{/if}

<style>
  .ic-tbl-cell-number {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }
  .ic-tbl-cell-number__edit {
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
    font-variant-numeric: tabular-nums;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
    outline: none;
    box-sizing: border-box;
  }
  /* Hide browser number spinner — Industrial Flat doesn't use them */
  .ic-tbl-cell-number__edit::-webkit-inner-spin-button,
  .ic-tbl-cell-number__edit::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }
</style>
