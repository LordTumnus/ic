<!--
  InlineEdit.svelte — Double-click-to-edit inline text/number input.
  Default: renders value as a span. On dblclick: replaces with an input.
  Enter → commit, Escape → cancel, blur → commit.
  Wrapper has class="nodrag" to prevent SvelteFlow node dragging during edit.
-->
<script lang="ts">
  let {
    value = '',
    oncommit,
    inputType = 'text',
    className = '',
    placeholder = '',
    selectOnFocus = true,
  }: {
    value: string | number;
    oncommit: (newValue: string | number) => void;
    inputType?: 'text' | 'number';
    className?: string;
    placeholder?: string;
    selectOnFocus?: boolean;
  } = $props();

  let editing = $state(false);
  let editValue = $state('');
  let committed = false;
  let inputEl: HTMLInputElement | undefined = $state();

  // Local override: shows committed value immediately without waiting for parent re-render.
  // Cleared when the parent prop actually updates (or on next edit start).
  let localValue: string | number | null = $state(null);
  const displayValue = $derived(localValue !== null ? localValue : value);

  // Clear local override when prop catches up
  $effect(() => {
    if (localValue !== null && value === localValue) {
      localValue = null;
    }
  });

  function startEdit(e: MouseEvent) {
    e.stopPropagation();
    committed = false;
    localValue = null;
    editing = true;
    editValue = String(displayValue);
    // Focus the input after Svelte renders it
    queueMicrotask(() => {
      if (inputEl) {
        inputEl.focus();
        if (selectOnFocus) inputEl.select();
      }
    });
  }

  function commit() {
    // Guard against double-commit (Enter hides input → blur fires again)
    if (committed) return;
    committed = true;
    editing = false;
    const trimmed = editValue.trim();
    if (trimmed === '' && inputType === 'number') return;
    const result = inputType === 'number' ? Number(trimmed) : trimmed;
    if (inputType === 'number' && isNaN(result as number)) return;
    // Show committed value immediately (don't wait for SvelteFlow data propagation)
    localValue = result;
    // Defer callback so the component finishes its state transition
    // before the parent re-renders (avoids crash during blur → re-render)
    queueMicrotask(() => oncommit(result));
  }

  function cancel() {
    committed = true;
    editing = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    e.stopPropagation();
    if (e.key === 'Enter') {
      commit();
    } else if (e.key === 'Escape') {
      cancel();
    }
  }
</script>

{#if editing}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <span
    class="ic-ie nodrag nowheel {className}"
    ondblclick={(e) => e.stopPropagation()}
  >
    <input
      bind:this={inputEl}
      bind:value={editValue}
      type="text"
      inputmode={inputType === 'number' ? 'decimal' : 'text'}
      {placeholder}
      class="ic-ie__input"
      onblur={commit}
      onkeydown={handleKeydown}
      onpointerdown={(e) => e.stopPropagation()}
    />
  </span>
{:else}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <span
    class="ic-ie ic-ie--display {className}"
    ondblclick={startEdit}
  >
    <span class="ic-ie__text">{displayValue}{placeholder && !displayValue ? placeholder : ''}</span>
  </span>
{/if}

<style>
  .ic-ie {
    display: inline-flex;
    align-items: center;
    cursor: default;
  }

  .ic-ie--display {
    cursor: text;
  }

  .ic-ie--display:hover .ic-ie__text {
    text-decoration-style: dotted;
    text-decoration-line: underline;
    text-underline-offset: 2px;
    text-decoration-color: var(--ic-muted-foreground);
  }

  .ic-ie__text {
    user-select: none;
  }

  .ic-ie__input {
    all: unset;
    font: inherit;
    color: inherit;
    background: rgba(0, 0, 0, 0.15);
    border: 1px solid var(--ic-primary);
    border-radius: 2px;
    padding: 0 2px;
    min-width: 20px;
    width: 100%;
    box-sizing: border-box;
  }

  .ic-ie__input:focus {
    outline: none;
  }
</style>
