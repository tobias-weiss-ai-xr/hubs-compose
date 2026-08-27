import { defineConfig, devices } from "@playwright/test";

const base = process.env.HUBS_BASE_URL || "https://hubs.chemie-lernen.org";

export default defineConfig({
  testDir: ".",
  timeout: 120000,
  retries: 2,
  fullyParallel: false,
  workers: 1,
  use: {
    // Client/API base — defaults to the live PSE deployment. The original
    // localhost:9090 dev topology is not present on the deployed host; use
    // HUBS_BASE_URL=http://localhost:9090 to run against a local stack.
    baseURL: base,
    headless: true,
    screenshot: "only-on-failure",
    ignoreHTTPSErrors: true,
  },
  projects: [
    {
      name: "all",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
