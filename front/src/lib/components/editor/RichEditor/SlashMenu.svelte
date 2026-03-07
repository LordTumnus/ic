<script lang="ts">
  import { resolveIcon } from '$lib/utils/icons';
  import { groupCommands, type SlashCommand } from './slash-commands';

  let {
    items = [],
    command,
  }: {
    items: SlashCommand[];
    command: (item: SlashCommand) => void;
  } = $props();

  let selectedIndex = $state(0);
  const grouped = $derived(groupCommands(items));

  // Flatten for keyboard nav
  const flatItems = $derived(items);

  export function onKeyDown(event: KeyboardEvent): boolean {
    if (event.key === 'ArrowDown') {
      selectedIndex = (selectedIndex + 1) % flatItems.length;
      return true;
    }
    if (event.key === 'ArrowUp') {
      selectedIndex = (selectedIndex - 1 + flatItems.length) % flatItems.length;
      return true;
    }
    if (event.key === 'Enter') {
      const item = flatItems[selectedIndex];
      if (item) command(item);
      return true;
    }
    return false;
  }

  // Reset selection when items change
  $effect(() => {
    items;
    selectedIndex = 0;
  });
</script>

<div class="ic-rte-slash" role="listbox">
  {#each [...grouped] as [group, cmds]}
    <div class="ic-rte-slash__group-label">{group}</div>
    {#each cmds as item, i}
      {@const flatIdx = flatItems.indexOf(item)}
      <button
        class="ic-rte-slash__item"
        class:ic-rte-slash__item--selected={flatIdx === selectedIndex}
        role="option"
        aria-selected={flatIdx === selectedIndex}
        onclick={() => command(item)}
        onmouseenter={() => { selectedIndex = flatIdx; }}
      >
        <span class="ic-rte-slash__icon">{@html resolveIcon(item.icon, 16)}</span>
        <span class="ic-rte-slash__text">
          <span class="ic-rte-slash__title">{item.title}</span>
          <span class="ic-rte-slash__desc">{item.description}</span>
        </span>
      </button>
    {/each}
  {/each}
  {#if items.length === 0}
    <div class="ic-rte-slash__empty">No results</div>
  {/if}
</div>

<style>
  .ic-rte-slash {
    min-width: 200px;
    max-width: 280px;
    max-height: 300px;
    overflow-y: auto;
    background-color: var(--ic-popover, var(--ic-background));
    border: 1px solid var(--ic-border);
    border-radius: 2px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    padding: 4px;
  }

  .ic-rte-slash__group-label {
    padding: 4px 8px 2px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--ic-muted-foreground);
    user-select: none;
  }

  .ic-rte-slash__item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 6px 8px;
    border: none;
    border-radius: 2px;
    background: transparent;
    color: var(--ic-foreground);
    cursor: pointer;
    text-align: left;
  }

  .ic-rte-slash__item:hover,
  .ic-rte-slash__item--selected {
    background-color: var(--ic-muted);
  }

  .ic-rte-slash__icon {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--ic-muted-foreground);
  }

  .ic-rte-slash__text {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .ic-rte-slash__title {
    font-size: 12px;
    font-weight: 500;
  }

  .ic-rte-slash__desc {
    font-size: 10px;
    color: var(--ic-muted-foreground);
  }

  .ic-rte-slash__empty {
    padding: 12px 8px;
    text-align: center;
    font-size: 12px;
    color: var(--ic-muted-foreground);
  }
</style>
