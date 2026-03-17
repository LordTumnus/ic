<!--
  StoreCapture — invisible child of SvelteFlow that captures the reactive store
  during component initialization (where getContext works).
-->
<script lang="ts">
  import { useStore } from '@xyflow/svelte';
  import { onMount } from 'svelte';

  let { onstore }: { onstore: (store: ReturnType<typeof useStore>) => void } = $props();

  const store = useStore();
  onMount(() => onstore(store));
</script>
