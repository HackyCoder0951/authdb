import { test, expect } from '@playwright/test';

test.describe('Dashboard (Authenticated)', () => {
  test('should load the dashboard successfully', async ({ page }) => {
    // Because of our dependencies in playwright.config.ts, 
    // we start this test with the token already in localStorage.
    await page.goto('/dashboard');
    
    // Verify the URL remains on the protected route (doesn't redirect to /login)
    await expect(page).toHaveURL('/dashboard');
    
    // Verify page content loads
    // Assuming you have a heading or button indicative of the dashboard
    const heading = page.locator('h1', { hasText: /Dashboard/i });
    await expect(heading).toBeVisible();
  });
});