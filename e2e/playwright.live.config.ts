import { defineConfig, devices } from "@playwright/test";

/**
 * Live-domain Playwright config.
 * Targets the production endpoint https://hubs.chemie-lernen.org
 * (see docs/user-stories.md for the story IDs asserted by these suites).
 *
 * Run: npx playwright test --config playwright.live.config.ts
 */
export default defineConfig({
  testDir: "./epics",
  timeout: 60000,
  retries: 0,
  // The live platform rate-limits /api/* (~10 req/window → 403).
  // Run sequentially and keep total API calls under that budget.
  fullyParallel: false,
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: "https://hubs.chemie-lernen.org",
    headless: true,
    screenshot: "only-on-failure",
    // The cert is a real Let's Encrypt cert for this hostname — do NOT relax TLS.
    ignoreHTTPSErrors: false,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
