<!--
  Tab.svelte — Empty shell for IC framework tab components.

  This component exists only as a prop container. Its reactive state
  (label, icon, closable, disabled, editable) is read by TabContainer
  via the ChildEntry proxy — no template rendering needed.
-->
<script lang="ts">
  import type { IconSource } from '$lib/utils/icons';

  let {
    label = $bindable(''),
    closable = $bindable(false),
    disabled = $bindable(false),
    editable = $bindable(false),
    icon = $bindable<IconSource>(null),
  }: {
    label?: string;
    closable?: boolean;
    disabled?: boolean;
    editable?: boolean;
    icon?: IconSource;
  } = $props();
</script>
