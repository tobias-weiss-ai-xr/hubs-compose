import { test, expect } from "@playwright/test";

/**
 * EP-01 Access & Authentication / EP-02 Rooms — live tests.
 * Story IDs reference docs/user-stories.md.
 * Target: https://hubs.chemie-lernen.org (production).
 */

const BASE = "https://hubs.chemie-lernen.org";

test.describe("US-001 open platform", () => {
  test("US-001 GET / returns HTTP 200 with the Hubs app shell", async ({ request }) => {
    const res = await request.get("/");
    expect(res.status()).toBe(200);
    const body = await res.text();
    expect(body).toContain("<title>");
    expect(body).toMatch(/<title>\s*App\s*<\/title>/);
  });

  test("US-001 main page loads in a browser", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveTitle("App");
  });
});

test.describe("US-011 browse rooms", () => {
  test("US-011 GET /rooms returns HTTP 200 HTML app shell", async ({ request }) => {
    const res = await request.get("/rooms");
    expect(res.status()).toBe(200);
    const headers = res.headers();
    expect(headers["content-type"] || "").toContain("text/html");
    const body = await res.text();
    expect(body).toMatch(/<title>\s*App\s*<\/title>/);
  });

  test("US-011 /rooms loads in a browser", async ({ page }) => {
    await page.goto("/rooms");
    await expect(page).toHaveTitle("App");
  });
});

test.describe("US-019 rooms over HTTPS", () => {
  test("US-019 /rooms is served over valid TLS", async ({ request }) => {
    // ignoreHTTPSErrors is false in the live config, so a broken cert would fail here.
    const res = await request.get(`${BASE}/rooms`);
    expect(res.status()).toBe(200);
    expect(res.url().startsWith("https://")).toBe(true);
  });

  test("US-019 root responds with a valid certificate", async ({ request }) => {
    const res = await request.get(`${BASE}/`);
    expect(res.status()).toBe(200);
  });
});
