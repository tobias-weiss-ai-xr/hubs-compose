import { test, expect, APIRequestContext, APIResponse, Page } from "@playwright/test";

/**
 * EP-01/EP-02 room entry + landing images — live browser/HTTP harness.
 * Story IDs reference docs/user-stories.md. Target: https://hubs.chemie-lernen.org.
 *
 * STATUS 2026-08-27: previously an INTENTIONALLY-RED harness for two known defects.
 * Both are now FIXED on the live host:
 *   1. US-016 / US-012 — room entry. The production frontend was served by
 *      `static-server.py`, whose SPA rewrite only mapped `/<7-char>` (room id without
 *      slug) to `hub.html`; real room URLs include the slug (`/<id>/<slug>`) and fell
 *      through to `index.html` (landing HomePage). FIXED by adding the slug pattern so
 *      room URLs serve `hub.html` and the room client loads. Verified live: room URL and
 *      the post-"Create Room" URL both render the room client (title "Room | …", canvas).
 *   2. US-018 — landing images rendered with `src=""`. FIXED via injected
 *      `window.APP_CONFIG.images` in dist/index.html + manifest icon sizes (24x24).
 *
 * Room-entry is asserted at the HTTP level (the room URL serves hub.html, not the
 * landing index.html) because headless WebGL (A-Frame) is unstable in this CI browser;
 * the browser is only used for the landing-image check (US-018).
 */

const BASE = "https://hubs.chemie-lernen.org";
const API_HEADERS = { "Accept-Encoding": "identity" }; // compression unsupported (US-093 🚧)

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function getApiWithRetry(request: APIRequestContext, path: string, tries = 5): Promise<APIResponse> {
  let last: APIResponse | undefined;
  for (let i = 0; i < tries; i++) {
    try {
      last = await request.get(path, { headers: API_HEADERS });
      if (last.status() === 200) return last;
    } catch {
      // network-level failure (e.g. 000) — retry
    }
    await sleep(1200);
  }
  // Safe stub so callers can assert status() without crashing on all-fail.
  return (last ?? ({ status: () => 0, json: async () => ({}) } as unknown as APIResponse));
}

/** Returns true when the served HTML is the landing page (HomePage), not a room. */
function isLandingHtml(html: string): boolean {
  return /HomePage__home-page__x0clY/.test(html) || /<title>\s*App\s*<\/title>/i.test(html);
}

test.describe("US-016 room entry serves the room client", () => {
  test("US-016 direct navigation to an existing room URL serves the room page (hub.html)", async ({ request }) => {
    const res = await getApiWithRetry(request, "/api/v1/hubs/element/H");
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.hubs) && body.hubs.length > 0).toBe(true);
    const hub = body.hubs[0];
    const url = `${BASE}/${hub.hub_id}/${hub.slug}`;

    const room = await request.get(url, { headers: API_HEADERS });
    expect(room.status()).toBe(200);
    const html = await room.text();
    expect(isLandingHtml(html), `room URL ${url} must serve hub.html, not the landing page`).toBe(false);
    expect((html.match(/<title>[^<]*<\/title>/i) || [])[0] || "", `room URL should carry a Room title`).toMatch(/Room\s*\|/i);
  });

  test("US-012 US-016 Create Room leads into the created room", async ({ page, request }) => {
    test.setTimeout(90_000);
    await page.goto(`${BASE}/`, { waitUntil: "domcontentloaded", timeout: 60_000 });
    // The landing SPA needs time to fetch config + render the React UI.
    await page.waitForTimeout(4000);

    const clicked = await page.evaluate(() => {
      const el = Array.from(document.querySelectorAll("a,button")).find((e) =>
        (e.innerText || "").match(/Create Room|Raum erstellen/i) !== null,
      );
      if (el) {
        (el as HTMLElement).click();
        return true;
      }
      return false;
    });
    expect(clicked, "Create Room button should exist on the landing page").toBe(true);

    await page.waitForURL(/\/[A-Za-z0-9]{7}\/[a-z0-9-]+$/, { timeout: 30_000 });
    const newUrl = page.url();
    expect(newUrl).toMatch(/\/[A-Za-z0-9]{7}\/[a-z0-9-]+$/);

    // Verify the new room URL serves the room client (hub.html), not the landing.
    const room = await request.get(newUrl, { headers: API_HEADERS });
    expect(room.status()).toBe(200);
    const html = await room.text();
    expect(isLandingHtml(html), `created room ${newUrl} must serve hub.html, not the landing page`).toBe(false);
    expect((html.match(/<title>[^<]*<\/title>/i) || [])[0] || "", `created room should carry a Room title`).toMatch(/Room\s*\|/i);
  });
});

test.describe("US-018 landing images render", () => {
  test("US-018 all <img> on the start page have a real source and decode", async ({ page }) => {
    await page.goto(`${BASE}/`, { waitUntil: "domcontentloaded", timeout: 60_000 });
    await page.waitForTimeout(1500);

    const broken = await page.evaluate(() => {
      const imgs = Array.from(document.images);
      return {
        total: imgs.length,
        emptySrc: imgs.filter((i) => !i.src).map((i) => i.alt || i.className || "(unnamed)"),
        undecoded: imgs
          .filter((i) => i.src && i.complete && i.naturalWidth === 0)
          .map((i) => (i.alt || i.src).slice(0, 80)),
      };
    });

    expect(broken.emptySrc, `images with empty src: ${broken.emptySrc.join(", ")}`).toEqual([]);
    expect(broken.undecoded, `decoded-with-zero-size images: ${broken.undecoded.join(", ")}`).toEqual([]);
  });
});
