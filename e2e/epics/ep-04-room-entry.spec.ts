import { test, expect, APIRequestContext, APIResponse, Page } from "@playwright/test";

/**
 * EP-01/EP-02 room entry — live browser harness for the KNOWN room-entry & image defects.
 * Story IDs reference docs/user-stories.md.
 * Target: https://hubs.chemie-lernen.org (production).
 *
 * ⚠️ STATUS 2026-08-26: these tests are INTENTIONALLY RED until the defects are fixed:
 *   1. US-016 / US-012 — the Hubs client renders `HomePage` for EVERY path. The URL
 *      changes (room created: /<hub_id>/<slug>) but the view never switches to the room.
 *      Reproduced even for direct navigation to an existing room URL.
 *   2. US-018 — landing-page images render with `src=""` (logo + hero screenshot), so
 *      nothing is displayed.
 * Once the client/router/config defect is fixed, these must go GREEN. Do not "fix" the
 * tests by weakening the assertions — fix the platform.
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

/** True when the SPA is stuck on the landing page instead of the room client. */
async function isStuckOnHomePage(page: Page): Promise<boolean> {
  return page.evaluate(() => {
    const main = document.querySelector("main");
    return !main || main.className.includes("HomePage");
  });
}

test.describe("US-016 room entry lands in 3D client", () => {
  test("US-016 direct navigation to an existing room URL enters the room", async ({ request, page }) => {
    test.setTimeout(90_000);

    // Fetch a real room id + slug from the element API (US-013) and navigate directly.
    test.step("look up a live room", async () => {
      const res = await getApiWithRetry(request, "/api/v1/hubs/element/H");
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body.hubs) && body.hubs.length > 0).toBe(true);
      const hub = body.hubs[0];
      const url = `${BASE}/${hub.hub_id}/${hub.slug}`;

      await page.goto(url, { waitUntil: "networkidle", timeout: 60_000 }).catch(() => {});
      await page.waitForTimeout(4000);

      expect(page.url()).toContain(`/${hub.hub_id}/`);
      expect(await isStuckOnHomePage(page), `room client should render for ${url}`).toBe(false);
      // a real room loads the A-Frame scene (canvas) or a lobby iframe
      const hasRoomUi = await page.evaluate(() => {
        return (
          document.querySelectorAll("canvas").length > 0 ||
          document.querySelectorAll("iframe").length > 0 ||
          (document.body.innerText || "").match(/VERSION=|enter room|back to start/i) !== null
        );
      });
      expect(hasRoomUi, "room UI (canvas/iframe/room text) should be present").toBe(true);
    });
  });

  test("US-012 US-016 Create Room leads into the created room", async ({ page }) => {
    test.setTimeout(90_000);

    await page.goto(`${BASE}/`, { waitUntil: "networkidle", timeout: 60_000 }).catch(() => {});
    await page.waitForTimeout(1500);

    test.step("click Create Room", async () => {
      const clicked = await page.evaluate(() => {
        const el = Array.from(document.querySelectorAll("a,button")).find((e) =>
          (e.innerText || "").includes("Create Room"),
        );
        if (el) {
          (el as HTMLElement).click();
          return true;
        }
        return false;
      });
      expect(clicked, "Create Room button should exist on the landing page").toBe(true);
    });

    // The room gets created (URL becomes /<hub_id>/<slug>)…
    await page.waitForURL(/\/[A-Za-z0-9]{7}\/[a-z0-9-]+$/, { timeout: 30_000 });
    // …but the client must ENTER it, not stay on the landing page.
    await page.waitForTimeout(4000);
    expect(await isStuckOnHomePage(page), "room client should render after create").toBe(false);
  });
});

test.describe("US-018 landing images render", () => {
  test("US-018 all <img> on the start page have a real source and decode", async ({ page }) => {
    await page.goto(`${BASE}/`, { waitUntil: "networkidle", timeout: 60_000 }).catch(() => {});
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

    // Known defect: logo + hero screenshot come back with src="".
    expect(broken.emptySrc, `images with empty src: ${broken.emptySrc.join(", ")}`).toEqual([]);
    expect(broken.undecoded, `decoded-with-zero-size images: ${broken.undecoded.join(", ")}`).toEqual([]);
  });
});
