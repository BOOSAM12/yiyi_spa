import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

/**
 * Where the Laravel API listens in development. 8018 instead of the usual 8000, which other
 * local projects already use; override with YIYI_API_PORT.
 */
export function backendOrigin(env: Record<string, string | undefined>): string {
  return `http://127.0.0.1:${env.YIYI_API_PORT ?? '8018'}`
}

const backend = backendOrigin(process.env)

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
    strictPort: true,
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
    include: ['src/**/*.test.{ts,tsx}', 'vite.config.test.ts'],
    setupFiles: ['src/test/setup.ts'],
    globals: false,
  },
})
