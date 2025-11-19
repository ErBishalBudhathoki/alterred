import { test, expect } from '@playwright/test';

test.describe('NeuroPilot web smoke', () => {
  test('home loads and title is correct', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/NeuroPilot/);
    await page.waitForLoadState('networkidle');
    const hasCanvas = await page.evaluate(() => !!document.querySelector('canvas, flt-glass-pane'));
    expect(hasCanvas).toBeTruthy();
  });

  test('route navigation by URL', async ({ page }) => {
    await page.goto('/taskflow');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/taskflow');

    await page.goto('/decision');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/decision');

    await page.goto('/time');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('/time');
  });
});