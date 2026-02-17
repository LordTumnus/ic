/**
 * Asset cache — stores decoded file/url assets by hash.
 *
 * MATLAB sends binary assets (files, downloaded URLs) as `{ hash, mime, data }` on first
 * encounter, then only `{ hash }` for subsequent references (per-View dedup via AssetRegistry).
 * This module caches the full payload so hash-only stubs can be resolved instantly.
 */

const cache = new Map<string, { mime: string; data: string }>();

export interface AssetData {
  hash: string;
  mime?: string;
  data?: string;
}

/**
 * Resolve an asset descriptor to its full payload.
 * If `mime` + `data` are present, caches them. Otherwise looks up by hash.
 */
export function resolveAsset(asset: AssetData): { mime: string; data: string } | null {
  if (asset.data && asset.mime) {
    cache.set(asset.hash, { mime: asset.mime, data: asset.data });
    return { mime: asset.mime, data: asset.data };
  }
  return cache.get(asset.hash) ?? null;
}

/** Resolve an asset to a decoded UTF-8 string (e.g. SVG markup). */
export function resolveAssetAsString(asset: AssetData): string {
  const r = resolveAsset(asset);
  return r ? atob(r.data) : '';
}

/** Resolve an asset to a data URI suitable for `<img src>`. */
export function resolveAssetAsDataUri(asset: AssetData): string {
  const r = resolveAsset(asset);
  return r ? `data:${r.mime};base64,${r.data}` : '';
}
