<!--
  TpButton.svelte — Action button blade.
-->
<script lang="ts">
  import { getContext } from 'svelte';
  import type { TpContext } from '../TweakPane.svelte';
  import type { ButtonApi } from 'tweakpane';

  let {
    label = $bindable('Button'),
    disabled = $bindable(false),
    hidden = $bindable(false),
    bladeIndex = $bindable(0),
    clicked,
  }: {
    label?: string;
    disabled?: boolean;
    hidden?: boolean;
    bladeIndex?: number;
    clicked?: () => void;
  } = $props();

  const ctx = getContext<TpContext>('ic-tp');
  let button: ButtonApi | undefined;

  $effect(() => {
    const container = ctx.container;
    if (!container) return;

    button = container.addButton({
      title: label,
      index: bladeIndex,
    });

    button.on('click', () => {
      clicked?.();
    });

    return () => {
      button?.dispose();
      button = undefined;
    };
  });

  $effect(() => {
    if (button) {
      button.title = label;
      button.disabled = disabled;
      button.hidden = hidden;
    }
  });
</script>
