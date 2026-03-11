<!--
  TpTextarea.svelte — Multi-line text input blade (plugin-textarea).
-->
<script lang="ts">
  import { getContext, untrack } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { BindingApi } from 'tweakpane';

  let {
    label = $bindable(''),
    value = $bindable(''),
    rows = $bindable(3),
    placeholder = $bindable(''),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    valueChanged,
  }: {
    label?: string;
    value?: string;
    rows?: number;
    placeholder?: string;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    valueChanged?: (data: { value: string }) => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let binding: BindingApi | undefined;
  const params = { value };

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    params.value = untrack(() => value);
    binding = container.addBinding(params, 'value', {
      view: 'textarea',
      label: label || undefined,
      rows,
      placeholder: placeholder || undefined,
      index: bladeIndex,
    } as Record<string, unknown>);

    binding.on('change', (ev) => {
      value = ev.value;
      valueChanged?.({ value: ev.value });
    });

    return () => {
      binding?.dispose();
      binding = undefined;
    };
  });

  // Sync MATLAB → Tweakpane
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
