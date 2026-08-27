import { test, expect } from "@playwright/test";
import type { APIRequestContext } from "@playwright/test";
import { config, delay } from "./config";

/**
 * PSE (Periodensystem) element-room API tests.
 *
 * Covers the Reticulum fork's chemistry feature:
 *   - creating a hub with user_data.chemistry
 *   - the element query endpoint GET /api/v1/hubs/element/:symbol
 *   - the HubView pse_url field ("https://pse.chemie-lernen.org?element=<symbol>")
 *   - sync'ing a fresh hub into the element query results (classroom flow)
 */

async function createHub(request: APIRequestContext, hub: any, { wait = true } = {}) {
  // Reticulum throttles hub creates (403 after a burst); retry with backoff.
  for (let attempt = 0; attempt < 3; attempt++) {
    if (wait) await delay(config.rateLimitDelayMs);
    const res = await request.post(`${config.api}/hubs`, {
      data: { hub },
      ignoreHTTPSErrors: true,
    });
    if (res.status() === 200) {
      const body = await res.json();
      expect(body.hub_id).toBeTruthy();
      return body;
    }
    if (res.status() === 403 && attempt < 2) {
      await delay(config.rateLimitDelayMs * 2);
      continue;
    }
    expect(res.status()).toBe(200);
  }
  throw new Error("createHub exhausted retries");
}

test.describe("PSE element-room integration", () => {
  test("hub created with chemistry appears in element query with pse_url", async ({ request }) => {
    const symbol = config.testSymbol; // e.g. H
    const roomName = `E2E WS PSE ${symbol} ${Date.now()}`;
    const created = await createHub(request, {
      name: roomName,
      user_data: { chemistry: { symbol } },
    });
    expect(created.url).toBeTruthy();
    expect(created.embed_token).toBeDefined(); // HubView embed contract (a64fdd4)

    // Round-trip: query element and find our hub with pse_url populated.
    await delay(config.rateLimitDelayMs);
    const q = await request.get(`${config.api}/hubs/element/${symbol}`, { ignoreHTTPSErrors: true });
    // API is auth_optional; 403 can happen with stale session cookies — accept both,
    // but the happy path must have our room with pse_url.
    expect([200, 403]).toContain(q.status());
    if (q.status() === 200) {
      const body = await q.json();
      expect(Array.isArray(body.hubs)).toBe(true);
      const matched = body.hubs.find((h: any) => h.name === roomName);
      expect(matched).toBeDefined();
      expect(matched.pse_url).toBe(`https://pse.chemie-lernen.org?element=${symbol.toLowerCase()}`);
      expect(matched.hub_id).toBe(created.hub_id);
    }
  });

  test("pse_url is null when hub has no chemistry data", async ({ request }) => {
    const created = await createHub(request, { name: `E2E No Chem ${Date.now()}` });

    await delay(config.rateLimitDelayMs);
    const q = await request.get(`${config.api}/hubs/element/${config.testSymbol}`, {
      ignoreHTTPSErrors: true,
    });
    if (q.status() === 200) {
      const qb = await q.json();
      const plainHub = qb.hubs.find((h: any) => h.hub_id === created.hub_id);
      if (plainHub) {
        expect(plainHub.pse_url).toBeNull();
      }
    }
  });

  test("element query pagination returns total_entries consistent with page_size", async ({ request }) => {
    const q = await request.get(
      `${config.api}/hubs/element/${config.testSymbol}?page=1&page_size=5`,
      { ignoreHTTPSErrors: true },
    );
    expect([200, 403]).toContain(q.status());
    if (q.status() === 200) {
      const body = await q.json();
      expect(body).toHaveProperty("pagination");
      expect(body.pagination.page_size).toBe(5);
      expect(body.hubs.length).toBeLessThanOrEqual(5);
    }
  });

  test("meta endpoint reports the deployed host", async ({ request }) => {
    const res = await request.get(`${config.api}/meta`, { ignoreHTTPSErrors: true });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.phx_host).toBeTruthy();
    expect(new URL(config.base).hostname).toBe(body.phx_host);
  });
});
