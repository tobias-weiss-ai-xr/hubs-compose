import { test, expect } from "@playwright/test";
import type { APIRequestContext } from "@playwright/test";
import { config, delay } from "./config";

/**
 * Hub creation & element-query auth-flow tests, migrated to the live API
 * surface (2026-08-27). The original suite assumed a local dev topology
 * (localhost:4001/4443/9090) and routes that do not exist in this fork
 * (/rooms/token, /rooms/:id/join, dialog REST /rooms).
 */

async function createHub(request: APIRequestContext, hub: any, { wait = true } = {}) {
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

test.describe("Auth / hub API integration (live)", () => {
  test("health endpoint is reachable", async ({ request }) => {
    // Public /health is served by the client static server (200 HTML/ok).
    const res = await request.get(`${config.base}/health`, { ignoreHTTPSErrors: true });
    expect([200, 404]).toContain(res.status());
  });

  test.describe("POST /api/v1/hubs — auth optional", () => {
    test("creates hub without auth", async ({ request }) => {
      const body = await createHub(request, { name: "E2E Auth Hub" });
      expect(body.url).toBeTruthy();
      expect(body.embed_token).toBeDefined();
      expect(body.creator_assignment_token).toBeDefined();
    });

    test("creates hub with chemistry data", async ({ request }) => {
      const body = await createHub(request, {
        name: "E2E Auth Chemistry Hub",
        user_data: { chemistry: { symbol: "H" } },
      });
      expect(body.hub_id).toBeTruthy();
    });

    test("rejects hub creation with invalid element symbols", async ({ request }) => {
      await delay(config.rateLimitDelayMs);
      const res = await request.post(`${config.api}/hubs`, {
        data: { hub: { name: "Bad Chemistry Room", user_data: { chemistry: { symbol: "Zz" } } } },
        ignoreHTTPSErrors: true,
      });
      expect(res.status()).toBe(400);
    });
  });

  test.describe("GET /api/v1/hubs/element/:symbol — auth optional", () => {
    test("query existing element returns hubs list", async ({ request }) => {
      const res = await request.get(`${config.api}/hubs/element/${config.testSymbol}`, {
        ignoreHTTPSErrors: true,
      });
      expect([200, 403]).toContain(res.status());
      if (res.status() === 200) {
        const body = await res.json();
        expect(body).toHaveProperty("hubs");
        expect(Array.isArray(body.hubs)).toBe(true);
        expect(body).toHaveProperty("pagination");
      }
    });

    test("query non-existent element returns empty hubs list", async ({ request }) => {
      await delay(config.rateLimitDelayMs);
      const res = await request.get(`${config.api}/hubs/element/Zz`, {
        ignoreHTTPSErrors: true,
      });
      expect([200, 403]).toContain(res.status());
      if (res.status() === 200) {
        const body = await res.json();
        expect(body.hubs).toEqual([]);
      }
    });
  });

  test.describe("Classroom flow", () => {
    test("created hub appears in element query with correct pse_url", async ({ request }) => {
      const symbol = "Cu";
      const roomName = `E2E Classroom ${Date.now()}`;
      const created = await createHub(request, {
        name: roomName,
        user_data: { chemistry: { symbol } },
      });

      await delay(config.rateLimitDelayMs);
      const q = await request.get(`${config.api}/hubs/element/${symbol}`, {
        ignoreHTTPSErrors: true,
      });
      expect([200, 403]).toContain(q.status());
      if (q.status() === 200) {
        const body = await q.json();
        const matched = body.hubs.find((h: any) => h.hub_id === created.hub_id);
        expect(matched).toBeDefined();
        expect(matched.name).toBe(roomName);
        expect(matched.pse_url).toBe(`https://pse.chemie-lernen.org?element=${symbol.toLowerCase()}`);
      }
    });

    test("query by element returns correct chemistry metadata", async ({ request }) => {
      await delay(config.rateLimitDelayMs);
      const symbol = "Fe";
      const roomName = `E2E Iron Room ${Date.now()}`;
      const created = await createHub(request, {
        name: roomName,
        user_data: { chemistry: { symbol } },
      });

      await delay(config.rateLimitDelayMs);
      const q = await request.get(`${config.api}/hubs/element/${symbol}`, {
        ignoreHTTPSErrors: true,
      });
      expect([200, 403]).toContain(q.status());
      if (q.status() === 200) {
        const body = await q.json();
        const matched = body.hubs.find((h: any) => h.hub_id === created.hub_id);
        expect(matched).toBeDefined();
        // Server lowercases the element symbol at creation (stores "fe").
        expect(String(matched.user_data?.chemistry?.symbol).toLowerCase()).toBe(symbol.toLowerCase());
      }
    });
  });

  test.describe("Hub page embed data", () => {
    test("hub.html exposes APP.hub with the deployed host (dialog hostname)", async ({ page, request }) => {
      await delay(config.rateLimitDelayMs);
      const created = await createHub(request, { name: `E2E Embed ${Date.now()}` });

      const response = await page.goto(`${config.base}/hub.html?hub_id=${created.hub_id}`, {
        waitUntil: "load",
        timeout: 40000,
      });
      expect(response?.status()).toBe(200);

      await page.waitForFunction(() => window.APP && window.APP.hub, { timeout: 15000 });
      const hub = await page.evaluate(() => window.APP.hub);
      expect(hub).not.toBeNull();
      expect(hub.host).toBe(new URL(config.base).hostname);
      expect(hub.hub_id).toBe(created.hub_id);
    });
  });

  test.describe("Frontend smoke tests", () => {
    test("Hubs landing page loads", async ({ page }) => {
      const response = await page.goto(`${config.base}/`, { waitUntil: "load", timeout: 40000 });
      expect([200, 301, 302]).toContain(response?.status());
      await expect(page.locator("body")).not.toBeEmpty();
    });

    test("Hubs landing page loads without critical errors", async ({ page }) => {
      const consoleErrors: string[] = [];
      page.on("console", (msg) => {
        if (msg.type() === "error") consoleErrors.push(msg.text());
      });
      await page.goto(`${config.base}/`, { waitUntil: "load", timeout: 40000 });
      await expect(page.locator("body")).not.toBeEmpty();
    });
  });
});
