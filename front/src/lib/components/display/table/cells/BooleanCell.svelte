<script lang="ts">
  import type { BooleanConfig } from '$lib/utils/table-utils';
  import { evaluateColorRules } from '$lib/utils/table-utils';

  let {
    value,
    config = {} as Partial<BooleanConfig>,
  }: {
    value?: unknown;
    config?: Partial<BooleanConfig>;
  } = $props();

  const checked = $derived(Boolean(value));
  const mode = $derived(config.displayMode ?? 'checkbox');
  const bgColor = $derived(
    config.colorRules?.length
      ? evaluateColorRules(checked ? 1 : 0, config.colorRules)
      : null
  );
</script>

{#if mode === 'text'}
  <span
    class="ic-tbl-cell-bool-text"
    class:ic-tbl-cell-bool-text--tinted={bgColor != null}
    style:background-color={bgColor}
  >{checked ? 'True' : 'False'}</span>
{:else if mode === 'numeric'}
  <span
    class="ic-tbl-cell-bool-text"
    class:ic-tbl-cell-bool-text--tinted={bgColor != null}
    style:background-color={bgColor}
  >{checked ? '1' : '0'}</span>
{:else}
  <span
    class="ic-tbl-cell-bool"
    class:ic-tbl-cell-bool--checked={checked}
    class:ic-tbl-cell-bool--tinted={bgColor != null}
    style:background-color={bgColor != null ? bgColor : undefined}
  >
    {#if checked}
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M2.5 6L5 8.5L9.5 3.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    {/if}
  </span>
{/if}

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
  /* Color rule overrides the default checkbox bg */
  .ic-tbl-cell-bool--tinted {
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.15);
  }
  .ic-tbl-cell-bool-text {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    border-radius: 2px;
    transition: background-color 0.15s ease;
  }
  .ic-tbl-cell-bool-text--tinted {
    padding: 0 4px;
    color: rgba(0, 0, 0, 0.85);
  }
</style>
