<!--
  Globe.svelte — Root CesiumJS globe container.

  Creates a CesiumWidget (widget-less 3D globe canvas) and sets Svelte
  context ('ic-globe') so child layer components can find it. Children
  are rendered via DynamicChild; each layer adds itself imperatively to
  widget.scene.imageryLayers / widget.scene.primitives / etc.

  This commit is the minimal bootstrap — no imagery, no camera sync, no
  events. Just a bare 3D ellipsoid rotatable with mouse. Later commits
  layer on imagery, camera API, terrain, 3D Tiles, and models.
-->
<script lang="ts">
  import { setContext, onMount, untrack } from 'svelte';
  import { CesiumWidget, SceneMode, Color } from '@cesium/engine';
  import '@cesium/engine/Source/Widget/CesiumWidget.css';
  import { initCesium } from '$lib/utils/cesium-init';
  import DynamicChild from '$lib/core/DynamicChild.svelte';
  import logger from '$lib/core/logger';
  import type { ChildEntries, PublishFn, SubscribeFn, RequestFn } from '$lib/types';

  export interface GlobeContext {
    widget: CesiumWidget | undefined;
    loading: boolean;
  }

  export interface GlobeUtils {
    publish: PublishFn | undefined;
    subscribe: SubscribeFn | undefined;
    request: RequestFn | undefined;
  }

  let {
    id = '',
    height = $bindable('400px'),
    sceneMode = $bindable<'3D' | '2D' | 'Columbus'>('3D'),
    enableAtmosphere = $bindable(true),
    childEntries = [] as ChildEntries,
    // Framework-injected
    publish,
    subscribe,
    request,
  }: {
    id?: string;
    height?: string;
    sceneMode?: '3D' | '2D' | 'Columbus';
    enableAtmosphere?: boolean;
    childEntries?: ChildEntries;
    publish?: PublishFn;
    subscribe?: SubscribeFn;
    request?: RequestFn;
  } = $props();

  let containerEl: HTMLDivElement;
  let widget: CesiumWidget | undefined;

  // Reactive context so children's $effects re-run when `widget` appears.
  const ctx: GlobeContext = $state({ widget: undefined, loading: false });
  setContext('ic-globe', ctx);

  // Framework utils exposed via getters — children read these on demand.
  const globeUtils: GlobeUtils = {
    get publish() { return publish; },
    get subscribe() { return subscribe; },
    get request() { return request; },
  };
  setContext('ic-globe-utils', globeUtils);

  function sceneModeEnum(mode: '3D' | '2D' | 'Columbus'): SceneMode {
    switch (mode) {
      case '2D': return SceneMode.SCENE2D;
      case 'Columbus': return SceneMode.COLUMBUS_VIEW;
      case '3D':
      default: return SceneMode.SCENE3D;
    }
  }

  // Widget lifecycle. This $effect only depends on containerEl — everything
  // else is untracked so prop changes don't destroy/recreate the canvas.
  $effect(() => {
    if (!containerEl) return;
    let disposed = false;

    (async () => {
      await initCesium();
      if (disposed) return;

      const w = untrack(() => new CesiumWidget(containerEl, {
        baseLayer: false,           // no imagery — commit 5 wires this
        skyAtmosphere: enableAtmosphere ? undefined : false,
        sceneMode: sceneModeEnum(sceneMode),
      }));

      // Visible globe color until an imagery layer is added (commit 5).
      // A dark gray-blue makes the sphere pop against the atmosphere.
      w.scene.globe.baseColor = Color.fromCssColorString('#1e293b');

      widget = w;
      ctx.widget = w;
      logger.info('Globe', 'CesiumWidget ready', { sceneMode });
    })().catch((err) => {
      logger.error('Globe', 'init failed', { error: String(err) });
    });

    return () => {
      disposed = true;
      ctx.widget = undefined;
      if (widget) {
        widget.destroy();
        widget = undefined;
      }
    };
  });

  // Sync prop → widget for enableAtmosphere.
  $effect(() => {
    const enabled = enableAtmosphere;
    if (!widget) return;
    widget.scene.skyAtmosphere.show = enabled;
  });

  // Sync prop → widget for sceneMode. Initial mode is set in the widget
  // constructor; subsequent changes animate via CesiumJS's morph methods.
  let lastSceneMode: '3D' | '2D' | 'Columbus' = sceneMode;
  const MORPH_DURATION = 0;
  $effect(() => {
    const mode = sceneMode;
    if (!widget) return;
    if (mode === lastSceneMode) return;
    lastSceneMode = mode;
    switch (mode) {
      case '2D':       widget.scene.morphTo2D(MORPH_DURATION); break;
      case 'Columbus': widget.scene.morphToColumbusView(MORPH_DURATION); break;
      case '3D':       widget.scene.morphTo3D(MORPH_DURATION); break;
    }
  });

  onMount(() => {
    return () => {
      // safety: covered by the $effect cleanup above, but this keeps
      // widget.destroy() idempotent if the effect never ran.
      if (widget) widget.destroy();
    };
  });
</script>

<div class="ic-globe-wrapper" style:height>
  <div {id} bind:this={containerEl} class="ic-globe"></div>
</div>

{#each childEntries as child (child.id)}
  <DynamicChild entry={child} />
{/each}

<style>
  .ic-globe-wrapper {
    position: relative;
    width: 100%;
  }
  .ic-globe {
    width: 100%;
    height: 100%;
    min-height: 100px;
    /* CesiumWidget fills the container */
  }
  /* Ensure the Cesium canvas itself fills correctly */
  .ic-globe :global(.cesium-widget),
  .ic-globe :global(.cesium-widget canvas) {
    width: 100% !important;
    height: 100% !important;
  }
</style>
