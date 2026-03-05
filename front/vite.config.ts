/// <reference types="vitest" />
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { lezer } from '@lezer/generator/rollup'
import wasm from 'vite-plugin-wasm'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [wasm(), lezer(), svelte()],
  // Use relative paths so the build works with file:// URLs (MATLAB's uihtml)
  base: './',
  resolve: {
    alias: {
      $lib: path.resolve('./src/lib'),
    },
    // Ensure browser conditions are used for Svelte in tests
    conditions: ['browser'],
  },
  build: {
    chunkSizeWarningLimit: 2000,
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./test/setup.ts'],
    include: ['test/**/*.test.ts'],
  },
})
