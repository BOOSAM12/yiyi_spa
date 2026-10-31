// @vitest-environment node
import { describe, expect, it } from 'vitest'

import config, { backendOrigin } from './vite.config.ts'

describe('dev server', () => {
  it('proxies the API to a non-standard local port by default', () => {
    expect(backendOrigin({})).toBe('http://127.0.0.1:8018')
  })

  it('lets YIYI_API_PORT override the API port', () => {
    expect(backendOrigin({ YIYI_API_PORT: '9001' })).toBe('http://127.0.0.1:9001')
  })

  it('sends /api, /sanctum and /up to the configured backend', () => {
    const origin = backendOrigin(process.env)

    expect(config.server?.proxy).toEqual({ '/api': origin, '/sanctum': origin, '/up': origin })
  })

  it('fails instead of silently moving to another port', () => {
    expect(config.server?.port).toBe(5173)
    expect(config.server?.strictPort).toBe(true)
  })
})
