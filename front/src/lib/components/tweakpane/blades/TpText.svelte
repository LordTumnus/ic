<!--
  TpText.svelte — String input blade.
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable(''),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanged,
    submitted,
  }: {
    label?: string;
    value?: string;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    valueChanged?: (data: { value: string }) => void;
    submitted?: (data: { value: string }) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let binding: BindingApi | undefined;
  const params = { value };

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    params.value = untrack(() => value);
    binding = container.addBinding(params, 'value', {
      label: label || undefined,
      index: bladeIndex,
    });

    binding.on('change', (ev) => {
      value = ev.value;
      valueChanged?.({ value: ev.value });
    });

    // Listen for Enter key on the input element
    const inputEl = binding.element.querySelector('input');
    const handleKeydown = (e: KeyboardEvent) => {
      if (e.key === 'Enter') {
        submitted?.({ value: params.value });
      }
    };
    inputEl?.addEventListener('keydown', handleKeydown);

    return () => {
      inputEl?.removeEventListener('keydown', handleKeydown);
      binding?.dispose();
      binding = undefined;
    };
  });

  $effect(() => {
    if (binding && params.value !== value) {
      params.value = value;
      binding.refresh();
    }
  });

  $effect(() => {
    if (binding) {
      binding.disabled = disabled;
      binding.hidden = hidden;
    }
  });
</script>
