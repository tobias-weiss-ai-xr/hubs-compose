import { test, expect } from "@playwright/test";
import { config } from "./config";

/**
 * Infrastructure health regression tests (Epic 2 / Milestone A side-effects).
 *
 * Locks in two recoveries performed during the deployment work:
 *  - reticulum is up and its health endpoint answers. The GLB file-serving fix
 *    lives in reticulum config, so a dead reticulum would regress themed scenes.
 *  - the dialog (WebRTC/mediasoup) signaling endpoint is reachable on :4443.
 *    The dialog runs with `network_mode: host` to dodge the VE's exhausted
 *    netfilter/numiptent quota; if it silently falls back to bridge+NAT port
 *    publishing it fails to start (iptables "Memory allocation problem") and
 *    rooms lose audio/video.
 */

test.describe("Infrastructure health", () => {
  test("reticulum health endpoint answers 200", async ({ request }) => {
    const res = await request.get(config.health, { ignoreHTTPSErrors: true });
    expect(res.status()).toBe(200);
  });

  test("dialog signaling endpoint is reachable on :4443", async ({ request }) => {
    const res = await request.get(
      `${config.dialog}/?roomId=healthcheck&peerId=healthcheck`,
      { ignoreHTTPSErrors: true },
    );
    // Any HTTP response (200/400/404) means the dialog is up and listening.
    // A connection failure (dialog down) makes `request` throw → test fails,
    // which is exactly the regression we want to catch.
    expect([200, 400, 404]).toContain(res.status());
  });
});
