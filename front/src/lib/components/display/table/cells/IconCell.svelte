<script lang="ts">
  import { resolveIcon } from '$lib/utils/icons';

  let { value }: { value?: unknown } = $props();

  const svg = $derived(resolveIcon(value as string, 16));
</script>

{#if svg}
  <span class="ic-tbl-cell-icon">{@html svg}</span>
{/if}

<style>
  .ic-tbl-cell-icon {
    display: inline-flex;
    align-items: center;
    color: var(--ic-foreground);
    line-height: 0;
  }
</style>
