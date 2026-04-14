/**
 * Registry of CesiumJS worker constructors.
 *
 * Each entry is imported via Vite's `?worker` suffix, which bundles the
 * worker source into a standalone classic IIFE file (because our
 * `worker: { format: 'iife' }` Vite config). The `new X()` call returns
 * a `Worker` backed by that IIFE served from `dist/assets/`.
 *
 * This bypasses CesiumJS's default `TaskProcessor.createWorker` path,
 * which would construct module workers (unsupported in MATLAB's
 * Chromium 104).
 *
 * The keys match the CesiumJS worker module IDs that `TaskProcessor`
 * looks up via `buildModuleUrl("Workers/{name}.js")`.
 */

/* eslint-disable @typescript-eslint/ban-ts-comment */
// @ts-ignore — Vite ?worker import
import CombineGeometry from '@cesium/engine/Build/Workers/combineGeometry.js?worker';
// @ts-ignore
import CreateGeometry from '@cesium/engine/Build/Workers/createGeometry.js?worker';
// @ts-ignore
import CreateVectorTileClampedPolylines from '@cesium/engine/Build/Workers/createVectorTileClampedPolylines.js?worker';
// @ts-ignore
import CreateVectorTileGeometries from '@cesium/engine/Build/Workers/createVectorTileGeometries.js?worker';
// @ts-ignore
import CreateVectorTilePoints from '@cesium/engine/Build/Workers/createVectorTilePoints.js?worker';
// @ts-ignore
import CreateVectorTilePolygons from '@cesium/engine/Build/Workers/createVectorTilePolygons.js?worker';
// @ts-ignore
import CreateVectorTilePolylines from '@cesium/engine/Build/Workers/createVectorTilePolylines.js?worker';
// @ts-ignore
import CreateVerticesFromCesium3DTilesTerrain from '@cesium/engine/Build/Workers/createVerticesFromCesium3DTilesTerrain.js?worker';
// @ts-ignore
import CreateVerticesFromGoogleEarthEnterpriseBuffer from '@cesium/engine/Build/Workers/createVerticesFromGoogleEarthEnterpriseBuffer.js?worker';
// @ts-ignore
import CreateVerticesFromHeightmap from '@cesium/engine/Build/Workers/createVerticesFromHeightmap.js?worker';
// @ts-ignore
import CreateVerticesFromQuantizedTerrainMesh from '@cesium/engine/Build/Workers/createVerticesFromQuantizedTerrainMesh.js?worker';
// @ts-ignore
import DecodeDraco from '@cesium/engine/Build/Workers/decodeDraco.js?worker';
// @ts-ignore
import DecodeGoogleEarthEnterprisePacket from '@cesium/engine/Build/Workers/decodeGoogleEarthEnterprisePacket.js?worker';
// @ts-ignore
import DecodeI3S from '@cesium/engine/Build/Workers/decodeI3S.js?worker';
// @ts-ignore
import GaussianSplatSorter from '@cesium/engine/Build/Workers/gaussianSplatSorter.js?worker';
// @ts-ignore
import GaussianSplatTextureGenerator from '@cesium/engine/Build/Workers/gaussianSplatTextureGenerator.js?worker';
// @ts-ignore
import IncrementallyBuildTerrainPicker from '@cesium/engine/Build/Workers/incrementallyBuildTerrainPicker.js?worker';
// @ts-ignore
import TranscodeKTX2 from '@cesium/engine/Build/Workers/transcodeKTX2.js?worker';
// @ts-ignore
import TransferTypedArrayTest from '@cesium/engine/Build/Workers/transferTypedArrayTest.js?worker';
// @ts-ignore
import UpsampleQuantizedTerrainMesh from '@cesium/engine/Build/Workers/upsampleQuantizedTerrainMesh.js?worker';
// @ts-ignore
import UpsampleVerticesFromCesium3DTilesTerrain from '@cesium/engine/Build/Workers/upsampleVerticesFromCesium3DTilesTerrain.js?worker';
/* eslint-enable @typescript-eslint/ban-ts-comment */

export type WorkerCtor = new () => Worker;

export const cesiumWorkerRegistry: Record<string, WorkerCtor> = {
  combineGeometry: CombineGeometry,
  createGeometry: CreateGeometry,
  createVectorTileClampedPolylines: CreateVectorTileClampedPolylines,
  createVectorTileGeometries: CreateVectorTileGeometries,
  createVectorTilePoints: CreateVectorTilePoints,
  createVectorTilePolygons: CreateVectorTilePolygons,
  createVectorTilePolylines: CreateVectorTilePolylines,
  createVerticesFromCesium3DTilesTerrain: CreateVerticesFromCesium3DTilesTerrain,
  createVerticesFromGoogleEarthEnterpriseBuffer: CreateVerticesFromGoogleEarthEnterpriseBuffer,
  createVerticesFromHeightmap: CreateVerticesFromHeightmap,
  createVerticesFromQuantizedTerrainMesh: CreateVerticesFromQuantizedTerrainMesh,
  decodeDraco: DecodeDraco,
  decodeGoogleEarthEnterprisePacket: DecodeGoogleEarthEnterprisePacket,
  decodeI3S: DecodeI3S,
  gaussianSplatSorter: GaussianSplatSorter,
  gaussianSplatTextureGenerator: GaussianSplatTextureGenerator,
  incrementallyBuildTerrainPicker: IncrementallyBuildTerrainPicker,
  transcodeKTX2: TranscodeKTX2,
  transferTypedArrayTest: TransferTypedArrayTest,
  upsampleQuantizedTerrainMesh: UpsampleQuantizedTerrainMesh,
  upsampleVerticesFromCesium3DTilesTerrain: UpsampleVerticesFromCesium3DTilesTerrain,
};
