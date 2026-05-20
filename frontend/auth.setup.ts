import { test as setup, expect } from '@playwright/test';
import * as path from 'path';

const authFile = path.join(__dirname, '../playwright/.auth/user.json');

setup('authenticate', async ({ page }) => {
  // Navigate to login
  await page.goto('/login');
  
  // Fill out the login form
  // Note: Adjust the selectors if your inputs use specific IDs or test-ids
  await page.fill('input[type="email"]', 'testuser@example.com');
  await page.fill('input[type="password"]', 'password123');
  await page.click('button[type="submit"]');

  // Wait for the redirect to the protected dashboard
  await page.waitForURL('/dashboard');
  
  // Save the localStorage/cookie state to disk
  await page.context().storageState({ path: authFile });
});