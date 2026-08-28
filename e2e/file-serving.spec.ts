import { test, expect } from "@playwright/test";
import { config, delay } from "./config";

/**
 * Static asset / GLB file-serving regression tests (Epic 2 / Milestone A).
 *
 * These lock in the deployment fix that makes reticulum serve /files/* with 200
 * instead of 403/500:
 *  - Ret.Storage `host` must include a scheme (so URI.parse yields a host, not
 *    nil — otherwise `is_storage_host` is always false → 403).
 *  - traefik must passHostHeader=true (so the public Host reaches reticulum;
 *    otherwise conn.host never matches storage_host → 403).
 * If either regresses, these tests fail loudly (a themed scene would then fail
 * to load its GLB with "Failed to load glTF model").
 */

// Restored ElementRoom archetype scene (stable sid).
const ELEMENT_ROOM_SID = "mhezdAw";

async function getScene(request: any, sid: string) {
  await delay(config.rateLimitDelayMs);
  const res = await request.get(`${config.api}/scenes/${sid}`, { ignoreHTTPSErrors: true });
  expect(res.status()).toBe(200);
  const body = await res.json();
  return body.scenes[0];
}

test.describe("Static file serving (GLB / screenshots)", () => {
  test("archetype scene metadata is retrievable with file URLs", async ({ request }) => {
    const scene = await getScene(request, ELEMENT_ROOM_SID);
    expect(scene.model_url).toContain("/files/");
    expect(scene.screenshot_url).toContain("/files/");
    expect(scene.model_url).toMatch(/\.glb$/);
  });

  test("scene GLB serves 200 model/gltf-binary (was 403/500)", async ({ request }) => {
    const scene = await getScene(request, ELEMENT_ROOM_SID);
    const glb = await request.get(scene.model_url, { ignoreHTTPSErrors: true });
    expect(glb.status()).toBe(200);
    expect(glb.headers()["content-type"]).toContain("model/gltf-binary");
  });

  test("scene screenshot serves 200 image/png", async ({ request }) => {
    const scene = await getScene(request, ELEMENT_ROOM_SID);
    const png = await request.get(scene.screenshot_url, { ignoreHTTPSErrors: true });
    expect(png.status()).toBe(200);
    expect(png.headers()["content-type"]).toContain("image/png");
  });

  test("missing/forbidden file is not 403 (host mismatch) or 500 (crash)", async ({ request }) => {
    // A missing file with no token is rejected (401 not-allowed). The regression
    // guard is that it is NOT 403 (is_storage_host Host mismatch — the bug we
    // fixed) and NOT 500 (the URI.parse(nil) crash from a schemeless
    // Ret.Storage host). 401/404 are both acceptable outcomes here.
    const res = await request.get(
      `${config.base}/files/00000000-0000-0000-0000-000000000000.glb`,
      { ignoreHTTPSErrors: true },
    );
    expect([403, 500]).not.toContain(res.status());
  });
});
