import { render, screen } from '@testing-library/react'
import { RouterProvider } from 'react-router'
import { describe, it } from 'vitest'

import { AppProviders } from '@/app/providers'
import { createAppRouter } from '@/app/router'

function renderAt(path: string) {
  render(
    <AppProviders>
      <RouterProvider router={createAppRouter([path])} />
    </AppProviders>,
  )
}

describe('app router', () => {
  it('renders the backoffice area under /app', async () => {
    renderAt('/app')
    await screen.findByRole('heading', { name: 'Panel del negocio' })
  })

  it('renders the public portal for a business slug', async () => {
    renderAt('/r/yiyi-centro')
    await screen.findByRole('heading', { name: 'Reserva en yiyi-centro' })
  })

  it('renders the platform area under /admin', async () => {
    renderAt('/admin')
    await screen.findByRole('heading', { name: 'Plataforma' })
  })

  it('redirects the root to the backoffice', async () => {
    renderAt('/')
    await screen.findByRole('heading', { name: 'Panel del negocio' })
  })
})
