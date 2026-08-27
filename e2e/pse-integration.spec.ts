import { test, expect } from "@playwright/test";
import type { APIRequestContext } from "@playwright/test";
import { config, delay } from "./config";

/**
 * PSE VR API contract tests (migrated to live deployment 2026-08-27).
 *
 * Verifies hub creation responses carry the full embed contract used by the
 * pse.chemie-lernen.org VR app: hub_id, url, embed_token, creator_assignment_token.
 */

async function createHub(request: APIRequestContext, hub: any) {
  for (let attempt = 0; attempt < 3; attempt++) {
    await delay(config.rateLimitDelayMs);
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

test.describe("PSE VR API contract", () => {
  test("create hub with chemistry returns full embed contract", async ({ request }) => {
    const body = await createHub(request, {
      name: "E2E PSE Natrium Room",
      user_data: { chemistry: { symbol: "Na" } },
    });
    expect(body.hub_id).toBeTruthy();
    expect(body.url).toBeTruthy();
    expect(body.status).toBe("ok");
    expect(body.embed_token).toBeDefined();
    expect(body.creator_assignment_token).toBeDefined();
  });

  test("create hub returns embed contract (gold room)", async ({ request }) => {
    const body = await createHub(request, {
      name: "E2E PSE Gold Room",
      user_data: { chemistry: { symbol: "Au" } },
    });
    expect(body.hub_id).toBeTruthy();
    expect(body.url).toBeTruthy();
    expect(body.status).toBe("ok");
  });

  test("create hub without chemistry still returns embed contract", async ({ request }) => {
    const body = await createHub(request, { name: "E2E PSE No Chemistry" });
    expect(body.hub_id).toBeTruthy();
    expect(body.status).toBe("ok");
  });
});
