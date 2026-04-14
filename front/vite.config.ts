/// <reference types="vitest" />
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { lezer } from '@lezer/generator/rollup'
import wasm from 'vite-plugin-wasm'
import { viteStaticCopy } from 'vite-plugin-static-copy'
import path from 'path'

const cesiumSource = 'node_modules/@cesium/engine'
const cesiumBaseUrl = 'cesium'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    wasm(),
    lezer(),
    svelte(),
    viteStaticCopy({
      targets: [
        // strips `node_modules/@cesium/engine/Build/Workers/` (5 segments), preserves any subdirs below
        { src: `${cesiumSource}/Build/Workers/**/*`, dest: `${cesiumBaseUrl}/Workers`, rename: { stripBase: 5 } },
        // built ThirdParty workers (zip-web-worker.js etc.) — strips up to and including `Workers/`
        { src: `${cesiumSource}/Build/ThirdParty/Workers/**/*`, dest: `${cesiumBaseUrl}/ThirdParty/Workers`, rename: { stripBase: 6 } },
        // source ThirdParty WASM binaries + JS (preserves subdirs like Workers/)
        { src: `${cesiumSource}/Source/ThirdParty/**/*`, dest: `${cesiumBaseUrl}/ThirdParty`, rename: { stripBase: 5 } },
        // source Assets (preserves Textures/, IAU2006_XYS/, Images/ subdirs)
        { src: `${cesiumSource}/Source/Assets/**/*`, dest: `${cesiumBaseUrl}/Assets`, rename: { stripBase: 5 } },
      ],
    }),
  ],
  // relative paths to local HTTPS server
  base: './',
  resolve: {
    alias: {
      $lib: path.resolve('./src/lib'),
    },
    // Ensure browser conditions are used for Svelte in tests
    conditions: ['browser'],
  },
  define: {
    // CesiumJS resolves Workers/, Assets/, ThirdParty/ relative to this URL.
    // Relative path because uihtml serves with relative base.
    CESIUM_BASE_URL: JSON.stringify(`./${cesiumBaseUrl}/`),
  },
  build: {
    chunkSizeWarningLimit: 2000,
  },
  worker: {
    format: 'iife',
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./test/setup.ts'],
    include: ['test/**/*.test.ts'],
  },
})
