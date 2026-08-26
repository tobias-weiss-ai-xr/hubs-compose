import { test, expect, APIRequestContext, APIResponse } from "@playwright/test";

/**
 * EP-02 Rooms (element-linked rooms) / EP-03 Chemistry Content / EP-13 Security — live tests.
 * Story IDs reference docs/user-stories.md.
 * Target: https://hubs.chemie-lernen.org (production).
 *
 * RATE LIMITING (US-008): the live platform throttles /api/* aggressively and
 * non-deterministically — bursts of 200/403 ("Forbidden")/000 flicker, threshold varies
 * (2–10 req/burst), recovering within a second. getApiWithRetry() therefore retries a few
 * times with backoff so the suite verifies the API is UP and CORRECT, not that we can
 * burst faster than the limiter. Kept intentionally light on total requests.
 */

const BASE = "https://hubs.chemie-lernen.org";

// The live server 403s compressed requests (gzip/br unsupported — US-093 🚧).
const API_HEADERS = { "Accept-Encoding": "identity" };

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** GET with bounded retry for rate-limiting (403/5xx) and transient network failures. */
async function getApiWithRetry(request: APIRequestContext, path: string, tries = 4): Promise<APIResponse> {
  let last!: APIResponse;
  for (let i = 0; i < tries; i++) {
    try {
      last = await request.get(path, { headers: API_HEADERS });
      if (last.status() === 200) return last;
    } catch (e) {
      // network-level failure (e.g. 000) — keep last undefined semantics via throw below
      if (i === tries - 1) throw e;
    }
    await sleep(1200);
  }
  return last;
}

test.describe("US-013 / US-021 / US-097 element API payload + CSP", () => {
  test("US-013 US-021 US-097 fe returns JSON payload with pagination and CSP header", async ({ request }) => {
    const res = await getApiWithRetry(request, "/api/v1/hubs/element/fe");
    expect(res.status()).toBe(200);
    const body = await res.json();
    // US-013: valid room-payload shape
    expect(body).toHaveProperty("hubs");
    expect(Array.isArray(body.hubs)).toBe(true);
    // US-021: pagination details
    expect(body.pagination).toBeDefined();
    expect(body.pagination.page).toBe(1);
    // US-097: CSP present on the API response
    const csp = res.headers()["content-security-policy"];
    expect(csp).toBeTruthy();
    expect(csp).toContain("default-src");
  });
});

test.describe("US-014 classroom dashboard", () => {
  test("US-014 GET /classroom returns HTTP 200 app shell", async ({ request }) => {
    const res = await request.get("/classroom");
    expect(res.status()).toBe(200);
    const headers = res.headers();
    expect(headers["content-type"] || "").toContain("text/html");
  });

  test("US-014 /classroom loads in a browser", async ({ page }) => {
    await page.goto("/classroom");
    await expect(page).toHaveTitle("App");
  });
});

test.describe("US-027 API answers for any symbol", () => {
  test("US-027 H and Og both return HTTP 200 JSON", async ({ request }) => {
    for (const symbol of ["H", "Og"]) {
      const res = await getApiWithRetry(request, `/api/v1/hubs/element/${symbol}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toHaveProperty("hubs");
      expect(body).toHaveProperty("pagination");
      await sleep(700);
    }
  });
});

test.describe("US-101 TLS everywhere", () => {
  test("US-101 primary endpoints served strictly over TLS", async ({ request }) => {
    for (const path of ["/", "/rooms", "/classroom"]) {
      const res = await request.get(`${BASE}${path}`);
      expect(res.status()).toBe(200);
      expect(res.url().startsWith("https://")).toBe(true);
    }
  });

  test("US-101 no certificate errors (ignoreHTTPSErrors is disabled)", async ({ page }) => {
    await page.goto(`${BASE}/rooms`);
    await expect(page).toHaveTitle("App");
  });
});
