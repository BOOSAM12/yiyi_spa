import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

const backend = 'http://127.0.0.1:8000'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    // Same-origin API calls: Sanctum cookie auth requires the SPA and the API on one origin.
    proxy: {
      '/api': backend,
      '/sanctum': backend,
      '/up': backend,
    },
  },
  test: {
    environment: 'jsdom',
    // e2e/*.spec.ts belongs to Playwright, not Vitest.
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['src/test/setup.ts'],
    globals: false,
  },
})
