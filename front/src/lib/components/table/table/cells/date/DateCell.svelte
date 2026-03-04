<script lang="ts">
  import type { DateConfig, ColorRuleConfig } from '$lib/utils/table-utils';
  import { formatDate, dateToEpoch, evaluateColorRules } from '$lib/utils/table-utils';
  import { toComparable } from './utils';

  let {
    value,
    config = {} as Partial<DateConfig>,
    style = $bindable(''),
    editing = false,
    oncommitedit,
    oncanceledit,
  }: {
    value?: unknown;
    config?: Partial<DateConfig>;
    style?: string;
    editing?: boolean;
    oncommitedit?: (oldValue: unknown, newValue: unknown) => void;
    oncanceledit?: () => void;
  } = $props();

  const format = $derived(config.format ?? 'short');
  const epoch = $derived(dateToEpoch(value));
  const hasValue = $derived(!isNaN(epoch));
  const display = $derived(hasValue ? formatDate(value, format) : '');

  // Tooltip: full ISO string for precision (e.g. when format is "short")
  const tooltip = $derived(hasValue ? new Date(epoch).toISOString() : '');

  // Color rules
  const colorRules = $derived(config.colorRules as ColorRuleConfig[] | undefined);
  const bgColor = $derived(
    hasValue && colorRules?.length
      ? evaluateColorRules(value, colorRules, toComparable)
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
    // Show tooltip if text is truncated OR always show full ISO for context
    title = tooltip;
  }
  function onleave() { title = ''; }

  // ── Edit mode ──────────────────────────────────

  // Choose input type based on date format
  const inputType = $derived(
    format === 'datetime' ? 'datetime-local' :
    format === 'time' ? 'time' : 'date'
  );

  let editValue = $state('');

  $effect(() => {
    if (editing && hasValue) {
      const d = new Date(epoch);
      if (inputType === 'datetime-local') {
        // YYYY-MM-DDTHH:MM format for datetime-local
        const iso = d.toISOString();
        editValue = iso.slice(0, 16);
      } else if (inputType === 'time') {
        const iso = d.toISOString();
        editValue = iso.slice(11, 16);
      } else {
        // YYYY-MM-DD for date
        editValue = d.toISOString().slice(0, 10);
      }
    } else if (editing) {
      editValue = '';
    }
  });

  function handleEditKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Enter') {
      e.preventDefault();
      commitDate();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      oncanceledit?.();
    }
  }

  function commitDate() {
    if (!editValue) {
      oncanceledit?.();
      return;
    }
    const newDate = new Date(editValue);
    if (isNaN(newDate.getTime())) {
      oncanceledit?.();
    } else {
      oncommitedit?.(value, newDate.toISOString());
    }
  }

  function handleEditBlur() {
    commitDate();
  }

  function autofocus(node: HTMLInputElement) {
    requestAnimationFrame(() => node.focus());
  }
</script>

{#if editing}
  <input
    type={inputType}
    class="ic-tbl-cell-date__edit"
    bind:value={editValue}
    onkeydown={handleEditKeydown}
    onblur={handleEditBlur}
    use:autofocus
  />
{:else if display}
  <span
    bind:this={el}
    class="ic-tbl-cell-date"
    {title}
    onpointerenter={onenter}
    onpointerleave={onleave}
  >{display}</span>
{/if}

<style>
  .ic-tbl-cell-date {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ic-tbl-cell-date__edit {
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
