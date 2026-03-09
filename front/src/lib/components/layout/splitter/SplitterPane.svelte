<script lang="ts">
	import { getContext, onMount, onDestroy } from 'svelte';
	import type { ChildEntries } from '$lib/types';
	import type { SplitterContext } from './splitter-types';

	let {
		size = $bindable<number | null>(null),
		minSize = $bindable(0),
		maxSize = $bindable(100),
		snapSize = $bindable(0),
		childEntries = { default: [] } as ChildEntries
	}: {
		size?: number | null;
		minSize?: number;
		maxSize?: number;
		snapSize?: number;
		childEntries?: ChildEntries;
	} = $props();

	const ctx = getContext<SplitterContext>('ic-splitter');
	let myIndex = -1;

	onMount(() => {
		myIndex = ctx.register({
			setSize: (v: number) => {
				size = v;
			}
		});
	});

	// Push config updates to parent whenever props change
	$effect(() => {
		if (myIndex >= 0) {
			ctx.update(myIndex, { size, minSize, maxSize, snapSize });
		}
	});

	onDestroy(() => {
		if (myIndex >= 0) ctx.deregister(myIndex);
	});
</script>

{#each childEntries.default ?? [] as child (child)}
	{@render child.snippet()}
{/each}
