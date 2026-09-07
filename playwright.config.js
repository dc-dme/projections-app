const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/browser',
  outputDir: './tests/browser/artifacts/results',
  timeout: 180_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'tests/browser/artifacts/report', open: 'never' }],
  ],
  use: {
    baseURL: 'http://127.0.0.1:4173/projections-app/',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 20_000,
    serviceWorkers: 'allow',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] }, testIgnore: /mobile\.spec\.js/ },
    { name: 'mobile', use: { ...devices['Pixel 7'] }, testMatch: /mobile\.spec\.js/ },
  ],
  webServer: {
    command: 'node tests/browser/serve.js',
    url: 'http://127.0.0.1:4173/projections-app/',
    reuseExistingServer: false,
    timeout: 10_000,
  },
});
