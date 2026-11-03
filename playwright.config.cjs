const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: './e2e', fullyParallel: false, workers: 1, timeout: 120000,
  expect: { timeout: 30000 }, retries: 0,
  outputDir: 'artifacts/playwright', reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:5174', viewport: { width:360, height:800 },
    screenshot:'only-on-failure', trace:'retain-on-failure' },
  webServer: {
    command:'node scripts/serve-web.cjs', url:'http://127.0.0.1:5174',
    reuseExistingServer: !process.env.CI, timeout:30000
  }
});
