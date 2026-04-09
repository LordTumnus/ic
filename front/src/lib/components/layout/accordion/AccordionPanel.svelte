<!--
  AccordionPanel.svelte — Content container for an accordion panel.

  This component holds reactive props (label, icon, open, disabled) that
  are read by Accordion.svelte via the ChildEntry proxy, and renders its
  children via the default slot.
-->
<script lang="ts">
  import type { ChildEntries } from '$lib/types';
  import type { IconSource } from '$lib/utils/icons';
  import DynamicChild from '$lib/core/DynamicChild.svelte';

  let {
    id = '',
    label = $bindable(''),
    icon = $bindable<IconSource>(null),
    open = $bindable(false),
    disabled = $bindable(false),
    childEntries = [] as ChildEntries,
  }: {
    id?: string;
    label?: string;
    icon?: IconSource;
    open?: boolean;
    disabled?: boolean;
    childEntries?: ChildEntries;
  } = $props();
</script>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}
