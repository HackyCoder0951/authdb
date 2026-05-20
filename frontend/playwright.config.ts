import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: 1,
  use: {
    // Point this to your Vite dev server URL
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
  },
  projects: [
    // Setup project runs first to grab the auth token
    { 
      name: 'setup', 
      testMatch: /.*\.setup\.ts/ 
    },
    // Main testing project re-uses the auth state
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'], 
        storageState: 'playwright/.auth/user.json' 
      },
      dependencies: ['setup'],
    },
  ],
});