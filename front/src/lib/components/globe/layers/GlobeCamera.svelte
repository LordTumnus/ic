<!--
  GlobeCamera.svelte — Zero-DOM child wiring the CesiumJS camera.

  Syncs reactive position/altitude/heading/pitch/roll with widget.camera
  bidirectionally, binds the reactive methods (flyTo / setView / lookAt /
  flyHome) to actual CesiumJS calls, and emits Changed after user drag.

  A "guard" flag prevents the classic reactive reflex where widget →
  bindable update triggers a MATLAB publish that echoes back down and
  re-moves the camera. Changes that originate from Cesium itself skip
  the widget.setView round-trip.
-->
<script lang="ts">
  import { getContext, onMount, untrack } from 'svelte';
  import {
    Cartesian3,
    Cartographic,
    Math as CesiumMath,
    HeadingPitchRange,
    Rectangle,
  } from '@cesium/engine';
  import type { GlobeContext } from '../Globe.svelte';
  import type { Resolution } from '$lib/types';
  import logger from '$lib/core/logger';

  interface FlyToData {
    position: [number, number];
    altitude: number;
    heading: number;
    pitch: number;
    roll: number;
    duration: number;
  }
  interface SetViewData {
    position: [number, number];
    altitude: number;
    heading: number;
    pitch: number;
    roll: number;
  }
  interface LookAtData {
    target: [number, number];
    range: number;
    heading: number;
    pitch: number;
  }
  interface FlyHomeData {
    duration: number;
  }
  interface FitBoundsData {
    // 2x2: [[south, west], [north, east]] in degrees
    bounds: [[number, number], [number, number]];
    duration: number;
  }

  let {
    position = $bindable<[number, number]>([0, 0]),
    altitude = $bindable(1.5e7),
    heading = $bindable(0),
    pitch = $bindable(-90),
    roll = $bindable(0),
    // Events
    changed,
    // Methods (bound in onMount)
    flyTo = $bindable((_data: FlyToData): Resolution => ({ success: true, data: null })),
    setView = $bindable((_data: SetViewData): Resolution => ({ success: true, data: null })),
    lookAt = $bindable((_data: LookAtData): Resolution => ({ success: true, data: null })),
    flyHome = $bindable((_data: FlyHomeData): Resolution => ({ success: true, data: null })),
    fitBounds = $bindable((_data: FitBoundsData): Resolution => ({ success: true, data: null })),
  }: {
    position?: [number, number];
    altitude?: number;
    heading?: number;
    pitch?: number;
    roll?: number;
    changed?: (data: {
      position: [number, number];
      altitude: number;
      heading: number;
      pitch: number;
      roll: number;
      bounds: number[][];
    }) => void;
    flyTo?: (data: FlyToData) => Resolution;
    setView?: (data: SetViewData) => Resolution;
    lookAt?: (data: LookAtData) => Resolution;
    flyHome?: (data: FlyHomeData) => Resolution;
    fitBounds?: (data: FitBoundsData) => Resolution;
  } = $props();

  const globeCtx = getContext<GlobeContext>('ic-globe');

  // Track the last state we read from Cesium so prop → Cesium sync can
  // distinguish "MATLAB set this value" from "Cesium just echoed it back".
  let cesiumPos: [number, number] = [position[0], position[1]];
  let cesiumAlt = altitude;
  let cesiumHeading = heading;
  let cesiumPitch = pitch;
  let cesiumRoll = roll;

  function cameraStateFromWidget(widget: NonNullable<GlobeContext['widget']>) {
    const cart = Cartographic.fromCartesian(widget.camera.position);
    return {
      lat: CesiumMath.toDegrees(cart.latitude),
      lon: CesiumMath.toDegrees(cart.longitude),
      alt: cart.height,
      heading: CesiumMath.toDegrees(widget.camera.heading),
      pitch: CesiumMath.toDegrees(widget.camera.pitch),
      roll: CesiumMath.toDegrees(widget.camera.roll),
    };
  }

  function currentBounds(widget: NonNullable<GlobeContext['widget']>): number[][] {
    // computeViewRectangle returns undefined when the camera is looking
    // off-globe (e.g., zoomed far out into space). We mirror that as [].
    const rect = widget.camera.computeViewRectangle();
    if (!rect) return [];
    return [
      [CesiumMath.toDegrees(rect.south), CesiumMath.toDegrees(rect.west)],
      [CesiumMath.toDegrees(rect.north), CesiumMath.toDegrees(rect.east)],
    ];
  }

  let unbind: (() => void) | undefined;

  // Wire widget.camera event listeners + seed initial state when the
  // widget becomes available. Everything else is untracked.
  $effect(() => {
    const widget = globeCtx.widget;
    if (!widget) return;

    untrack(() => {
      // Seed: publish the actual Cesium starting camera up to MATLAB
      const s = cameraStateFromWidget(widget);
      cesiumPos = [s.lat, s.lon];
      cesiumAlt = s.alt;
      cesiumHeading = s.heading;
      cesiumPitch = s.pitch;
      cesiumRoll = s.roll;
      position = cesiumPos;
      altitude = cesiumAlt;
      heading = cesiumHeading;
      pitch = cesiumPitch;
      roll = cesiumRoll;
    });

    // moveEnd fires once after a user drag/zoom settles (not during the
    // animation). That maps cleanly to our "Changed" event and also
    // gives a stable moment to sync props back to MATLAB.
    const off = widget.camera.moveEnd.addEventListener(() => {
      const s = cameraStateFromWidget(widget);
      cesiumPos = [s.lat, s.lon];
      cesiumAlt = s.alt;
      cesiumHeading = s.heading;
      cesiumPitch = s.pitch;
      cesiumRoll = s.roll;
      position = cesiumPos;
      altitude = cesiumAlt;
      heading = cesiumHeading;
      pitch = cesiumPitch;
      roll = cesiumRoll;
      changed?.({
        position: cesiumPos,
        altitude: cesiumAlt,
        heading: cesiumHeading,
        pitch: cesiumPitch,
        roll: cesiumRoll,
        bounds: currentBounds(widget),
      });
    });
    unbind = off;

    return () => {
      unbind?.();
      unbind = undefined;
    };
  });

  // Prop → widget sync (MATLAB-driven changes). Guarded to avoid the
  // echo loop where our own moveEnd handler triggered this effect.
  $effect(() => {
    const widget = globeCtx.widget;
    if (!widget) return;
    const p = position;
    const a = altitude;
    const h = heading;
    const pi = pitch;
    const r = roll;
    const fromCesium =
      Math.abs(p[0] - cesiumPos[0]) < 1e-6 &&
      Math.abs(p[1] - cesiumPos[1]) < 1e-6 &&
      Math.abs(a - cesiumAlt) < 1 &&
      Math.abs(h - cesiumHeading) < 1e-3 &&
      Math.abs(pi - cesiumPitch) < 1e-3 &&
      Math.abs(r - cesiumRoll) < 1e-3;
    if (fromCesium) return;
    widget.camera.setView({
      destination: Cartesian3.fromDegrees(p[1], p[0], a),
      orientation: {
        heading: CesiumMath.toRadians(h),
        pitch: CesiumMath.toRadians(pi),
        roll: CesiumMath.toRadians(r),
      },
    });
  });

  // Method bindings. These are invoked by MATLAB via publish("flyTo", ...)
  // etc. The framework routes each publish to the corresponding bindable
  // method prop on this component.
  onMount(() => {
    flyTo = (data): Resolution => {
      const widget = globeCtx.widget;
      if (!widget) return { success: false, data: 'widget not ready' };
      widget.camera.flyTo({
        destination: Cartesian3.fromDegrees(data.position[1], data.position[0], data.altitude),
        orientation: {
          heading: CesiumMath.toRadians(data.heading),
          pitch: CesiumMath.toRadians(data.pitch),
          roll: CesiumMath.toRadians(data.roll),
        },
        duration: data.duration,
      });
      return { success: true, data: null };
    };

    setView = (data): Resolution => {
      const widget = globeCtx.widget;
      if (!widget) return { success: false, data: 'widget not ready' };
      widget.camera.setView({
        destination: Cartesian3.fromDegrees(data.position[1], data.position[0], data.altitude),
        orientation: {
          heading: CesiumMath.toRadians(data.heading),
          pitch: CesiumMath.toRadians(data.pitch),
          roll: CesiumMath.toRadians(data.roll),
        },
      });
      return { success: true, data: null };
    };

    lookAt = (data): Resolution => {
      const widget = globeCtx.widget;
      if (!widget) return { success: false, data: 'widget not ready' };
      widget.camera.lookAt(
        Cartesian3.fromDegrees(data.target[1], data.target[0]),
        new HeadingPitchRange(
          CesiumMath.toRadians(data.heading),
          CesiumMath.toRadians(data.pitch),
          data.range,
        ),
      );
      return { success: true, data: null };
    };

    flyHome = (data): Resolution => {
      const widget = globeCtx.widget;
      if (!widget) return { success: false, data: 'widget not ready' };
      widget.camera.flyHome(data.duration);
      return { success: true, data: null };
    };

    fitBounds = (data): Resolution => {
      const widget = globeCtx.widget;
      if (!widget) return { success: false, data: 'widget not ready' };
      const [[south, west], [north, east]] = data.bounds;
      widget.camera.flyTo({
        destination: Rectangle.fromDegrees(west, south, east, north),
        duration: data.duration,
      });
      return { success: true, data: null };
    };

    logger.info('GlobeCamera', 'camera methods bound');
  });
</script>
