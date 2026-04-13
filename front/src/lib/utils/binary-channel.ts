/**
 * Binary data transfer via the uihtml static file server.
 *
 * MATLAB writes binary files to the dist/ directory and notifies the frontend
 * via a lightweight bridge event. This module fetches those files as raw
 * ArrayBuffer, bypassing JSON serialization entirely.
 *
 * Performance: ~6ms for 500KB, ~30ms for 5MB (vs 100-500ms+ for JSON/base64).
 */

/**
 * Fetch a binary file from the uihtml static file server.
 * Uses a version query parameter for cache-busting.
 */
export async function fetchBinary(file: string, version: number): Promise<ArrayBuffer> {
  const response = await fetch(`./${file}?v=${version}`);
  if (!response.ok) {
    throw new Error(`Binary fetch failed: ${response.status} ${response.statusText} for ${file}`);
  }
  return response.arrayBuffer();
}

/** Fetch binary data and return as Float32Array. */
export async function fetchFloat32(file: string, version: number): Promise<Float32Array> {
  return new Float32Array(await fetchBinary(file, version));
}

/** Fetch binary data and return as Float64Array. */
export async function fetchFloat64(file: string, version: number): Promise<Float64Array> {
  return new Float64Array(await fetchBinary(file, version));
}

/** Fetch binary data and return as Uint8Array. */
export async function fetchUint8(file: string, version: number): Promise<Uint8Array> {
  return new Uint8Array(await fetchBinary(file, version));
}

/** Fetch binary data and return as Int32Array. */
export async function fetchInt32(file: string, version: number): Promise<Int32Array> {
  return new Int32Array(await fetchBinary(file, version));
}
