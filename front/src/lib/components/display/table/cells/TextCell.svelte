<script lang="ts">
  let { value }: { value?: unknown } = $props();
</script>

<span class="ic-tbl-cell-text">{value ?? ''}</span>

<style>
  .ic-tbl-cell-text {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
