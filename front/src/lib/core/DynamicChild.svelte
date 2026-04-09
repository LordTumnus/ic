<!--
  DynamicChild.svelte — Renders a child component without a wrapper div.

  Primary path: renders via <Comp {...svelteProps} />, producing zero extra
  DOM nodes. The $effect finds the root element by id, stamps data-ic-type,
  and calls onMounted/onUnmounted for lifecycle management.

  Fallback path: if the entry has a raw Svelte snippet (standalone usage
  without an IC Component, e.g. DeveloperTools panels), renders it directly.
-->
<script lang="ts">
  import type { ChildEntry } from '$lib/types';

  let { entry, ...extra }: { entry: ChildEntry; [key: string]: unknown } = $props();

  // svelte-ignore state_referenced_locally
  const Comp = entry.component;

  if (Comp) {
    $effect(() => {
      const el = document.getElementById(entry.id);

      if (el) {
        el.dataset.icType = entry.type;
        entry.onMounted?.(el);
      }

      return () => {
        entry.onUnmounted?.();
      };
    });
  }
</script>

{#if Comp}
  <Comp {...entry.svelteProps} {...extra} />
{:else if entry.snippet}
  {@render entry.snippet()}
{/if}
