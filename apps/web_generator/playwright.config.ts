import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  webServer: {
    command: `"${process.execPath}" node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4175 --strictPort`,
    port: 4175,
    reuseExistingServer: false,
  },
  use: {
    baseURL: 'http://127.0.0.1:4175',
    serviceWorkers: 'block',
  },
  projects: [
    { name: 'chromium-desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'chromium-390', use: { ...devices['Pixel 5'] } },
    { name: 'webkit-smoke', use: { ...devices['Desktop Safari'] } },
  ],
});
