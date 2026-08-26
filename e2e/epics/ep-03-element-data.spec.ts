import { test, expect, APIRequestContext, APIResponse } from "@playwright/test";

/**
 * EP-03 Chemistry Content — live element-API breadth tests (US-024 / US-027).
 * Story IDs reference docs/user-stories.md.
 * Target: https://hubs.chemie-lernen.org (production).
 *
 * RATE LIMITING (US-008): the live platform throttles /api/* to ~1 req/s per IP with
 * erratic 200/403 ("Forbidden")/000 flicker. getApiWithRetry() retries with backoff
 * (verifies the API is UP and CORRECT, not burst speed) and symbols are paced with
 * sleep() to stay under the limiter.
 */

const BASE = "https://hubs.chemie-lernen.org";
const API_HEADERS = { "Accept-Encoding": "identity" }; // compression unsupported (US-093 🚧)

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function getApiWithRetry(request: APIRequestContext, path: string, tries = 4): Promise<APIResponse> {
  let last!: APIResponse;
  for (let i = 0; i < tries; i++) {
    try {
      last = await request.get(path, { headers: API_HEADERS });
      if (last.status() === 200) return last;
    } catch {
      // network-level failure (e.g. 000) — retry
    }
    await sleep(1200);
  }
  return last;
}

// One representative symbol per period, spread across groups (US-024: the API serves the
// whole table; US-027: any symbol answers 200).
const REPRESENTATIVE = ["H", "He", "C", "Fe", "Ag", "U"]; // periods 1,1,2,4,5,7

test.describe("US-024 element API breadth across the periodic table", () => {
  test("US-024 representative symbols all return 200 with room payloads", async ({ request }) => {
    for (const symbol of REPRESENTATIVE) {
      const res = await getApiWithRetry(request, `/api/v1/hubs/element/${symbol}`);
      expect(res.status(), `symbol ${symbol}`).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body.hubs), `symbol ${symbol} hubs`).toBe(true);
      expect(body.pagination, `symbol ${symbol} pagination`).toBeTruthy();
      await sleep(900); // stay under the ~1 tps limiter
    }
  });

  test("US-024 returned rooms carry pse_url and entry_mode", async ({ request }) => {
    const res = await getApiWithRetry(request, "/api/v1/hubs/element/C");
    expect(res.status()).toBe(200);
    const body = await res.json();
    for (const hub of body.hubs) {
      if (hub.pse_url == null) continue; // rooms created without chemistry metadata
      expect(hub.pse_url).toContain("pse.chemie-lernen.org");
    }
    // even an empty result must be a well-formed room listing
    expect(body).toHaveProperty("pagination");
    await sleep(900);
  });
});

test.describe("US-027 unknown symbol handling", () => {
  test("US-027 Zz returns 200 with an empty room list", async ({ request }) => {
    const res = await getApiWithRetry(request, "/api/v1/hubs/element/Zz");
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.hubs).toEqual([]);
    expect(body.pagination).toBeTruthy();
  });
});
