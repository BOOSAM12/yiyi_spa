import {
  createBrowserRouter,
  createMemoryRouter,
  Navigate,
  type RouteObject,
} from 'react-router'

// One app, three areas, each loaded on demand (spec §10).
const routes: RouteObject[] = [
  { path: '/', element: <Navigate to="/app" replace /> },
  {
    path: '/app/*',
    lazy: async () => ({ Component: (await import('./areas/BackofficeArea')).BackofficeArea }),
  },
  {
    path: '/r/:slug/*',
    lazy: async () => ({ Component: (await import('./areas/PortalArea')).PortalArea }),
  },
  {
    path: '/admin/*',
    lazy: async () => ({ Component: (await import('./areas/PlatformArea')).PlatformArea }),
  },
]

export function createAppRouter(initialEntries?: string[]) {
  return initialEntries
    ? createMemoryRouter(routes, { initialEntries })
    : createBrowserRouter(routes)
}
