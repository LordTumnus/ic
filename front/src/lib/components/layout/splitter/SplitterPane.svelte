<script lang="ts">
	import { getContext, onMount, onDestroy } from 'svelte';
	import type { ChildEntries } from '$lib/types';
	import DynamicChild from '$lib/core/DynamicChild.svelte';
	import type { SplitterContext } from './splitter-types';

	let {
		id = '',
		size = $bindable<number | null>(null),
		minSize = $bindable(0),
		maxSize = $bindable(100),
		snapSize = $bindable(0),
		childEntries = [] as ChildEntries
	}: {
		id?: string;
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

{#each childEntries as child (child.id)}
	<DynamicChild entry={child} />
{/each}
