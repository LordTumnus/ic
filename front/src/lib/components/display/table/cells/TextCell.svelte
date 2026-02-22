<script lang="ts">
  let {
    value,
  }: {
    value?: unknown;
  } = $props();

  const display = $derived(String(value ?? ''));

  let el = $state<HTMLSpanElement>(null!);
  let title = $state('');

  function onenter() {
    if (el.scrollWidth > el.clientWidth) title = display;
  }
  function onleave() { title = ''; }
</script>

<span
  bind:this={el}
  class="ic-tbl-cell-text"
  {title}
  onpointerenter={onenter}
  onpointerleave={onleave}
>{display}</span>

<style>
  .ic-tbl-cell-text {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
