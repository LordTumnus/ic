/**
 * Asset cache — stores decoded file/url assets by hash as Uint8Array.
 *
 * Assets arrive inline as `{hash, mime, data}` (base64 string) on first
 * reference. `resolveAsset()` decodes base64 → Uint8Array once and caches
 * by hash. Subsequent references arrive as `{hash}` only and resolve
 * from cache instantly — no re-decoding.
 */

const cache = new Map<string, { mime: string; bytes: Uint8Array }>();

export interface AssetData {
  hash: string;
  mime?: string;
  data?: string; // inline base64 (first reference only)
}

// ---------------------------------------------------------------------------
// Binary encode/decode utilities
// ---------------------------------------------------------------------------

/** Decode a base64 string to Uint8Array. */
export function base64ToUint8Array(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/** Convert Uint8Array to base64 string (chunked to avoid stack overflow). */
export function uint8ArrayToBase64(bytes: Uint8Array): string {
  const chunkSize = 8192;
  let binary = '';
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

// ---------------------------------------------------------------------------
// Asset resolvers
// ---------------------------------------------------------------------------

/**
 * Resolve an asset descriptor to its full payload (mime + bytes).
 * If inline `data` is present, decodes base64 and caches by hash.
 * Subsequent calls with the same hash resolve from cache.
 */
export function resolveAsset(asset: AssetData): { mime: string; bytes: Uint8Array } | null {
  if (asset.data && asset.mime) {
    // Inline base64 → decode once and cache
    const bytes = base64ToUint8Array(asset.data);
    cache.set(asset.hash, { mime: asset.mime, bytes });
    return { mime: asset.mime, bytes };
  }
  return cache.get(asset.hash) ?? null;
}

/** Resolve an asset to raw bytes. */
export function resolveAssetAsBytes(asset: AssetData): Uint8Array | null {
  return resolveAsset(asset)?.bytes ?? null;
}

/** Resolve an asset to a decoded UTF-8 string (e.g. SVG markup). */
export function resolveAssetAsString(asset: AssetData): string {
  const r = resolveAsset(asset);
  return r ? new TextDecoder().decode(r.bytes) : '';
}

/** Resolve an asset to a data URI suitable for `<img src>`. */
export function resolveAssetAsDataUri(asset: AssetData): string {
  const r = resolveAsset(asset);
  if (!r) return '';
  const b64 = uint8ArrayToBase64(r.bytes);
  return `data:${r.mime};base64,${b64}`;
}

/** Resolve an asset to a Blob object URL. Caller should revoke when done. */
export function resolveAssetAsObjectUrl(asset: AssetData): string | null {
  const r = resolveAsset(asset);
  if (!r) return null;
  return URL.createObjectURL(new Blob([r.bytes], { type: r.mime }));
}
