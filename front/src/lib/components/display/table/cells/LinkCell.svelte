<script lang="ts">
  let {
    value,
    onclick,
  }: {
    value?: unknown;
    onclick?: () => void;
  } = $props();
</script>

{#if value != null && value !== ''}
  <button
    class="ic-tbl-cell-link"
    onclick={(e: MouseEvent) => { e.stopPropagation(); onclick?.(); }}
  >
    {value}
  </button>
{/if}

<style>
  .ic-tbl-cell-link {
    display: inline;
    background: none;
    border: none;
    padding: 0;
    margin: 0;
    color: var(--ic-primary);
    cursor: pointer;
    font: inherit;
    text-decoration: underline;
    text-decoration-thickness: 1px;
    text-underline-offset: 2px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
    transition: opacity 0.15s ease;
  }
  .ic-tbl-cell-link:hover {
    opacity: 0.8;
  }
</style>
