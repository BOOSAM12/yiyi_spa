import { expect, test } from '@playwright/test'

test('loads the backoffice from the root URL', async ({ page }) => {
  await page.goto('/')

  await expect(page).toHaveURL(/\/app$/)
  await expect(page).toHaveTitle('YiYi Spa')
  await expect(page.getByRole('heading', { name: 'Panel del negocio' })).toBeVisible()
})

test('loads a public business page', async ({ page }) => {
  await page.goto('/r/yiyi-centro')

  await expect(page.getByRole('heading', { name: 'Reserva en yiyi-centro' })).toBeVisible()
})
