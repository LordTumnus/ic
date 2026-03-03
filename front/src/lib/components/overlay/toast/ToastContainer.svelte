<!--
  ToastContainer.svelte — renders all active toasts from the store.

  Mounted once in Frame.svelte. Groups toasts by position (top/bottom)
  and renders them in fixed-position containers. Each ToastItem handles
  its own auto-dismiss timer and animations.
-->
<script lang="ts">
  import { getToasts } from './toast-store.svelte';
  import ToastItem from './ToastItem.svelte';

  const toasts = $derived(getToasts());
  const topToasts = $derived(toasts.filter(t => t.position === 'top'));
  const bottomToasts = $derived(toasts.filter(t => t.position === 'bottom'));
</script>

{#if topToasts.length > 0}
  <div class="ic-toast-container ic-toast-container--top">
    {#each topToasts as toast (toast.id)}
      <ToastItem {toast} />
    {/each}
  </div>
{/if}

{#if bottomToasts.length > 0}
  <div class="ic-toast-container ic-toast-container--bottom">
    {#each bottomToasts as toast (toast.id)}
      <ToastItem {toast} />
    {/each}
  </div>
{/if}

<style>
  .ic-toast-container {
    position: fixed;
    z-index: 9000;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    gap: 8px;
    pointer-events: none;
    max-width: calc(100vw - 32px);
  }

  .ic-toast-container--top {
    top: 16px;
    flex-direction: column;
  }

  .ic-toast-container--bottom {
    bottom: 16px;
    flex-direction: column-reverse;
  }
</style>
