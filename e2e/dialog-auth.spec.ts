import { test, expect } from "@playwright/test";
import { config } from "./config";

/**
 * Dialog (mediasoup / protoo) auth & handshake tests.
 *
 * Migrated 2026-08-27: the original suite assumed a REST API on the dialog
 * (GET/POST /rooms returning JSON errors). The deployed dialog exposes the
 * protoo WebSocket server only:
 *   wss://host:4443/?roomId=<id>&peerId=<id>  (subprotocol "protoo")
 * - it rejects handshakes that omit the protoo subprotocol (403)
 * - it rejects handshakes without roomId/peerId
 * - a proper protoo connect + getRouterRtpCapabilities round-trip is covered
 *   in ws-join.spec.ts (TLS/announced-IP fix).
 */

const dialogConnect = (path: string, subprotocol?: string | string[]) =>
  new Promise<{ status: string; reason?: string }>((resolve, reject) => {
    try {
      const ws = new WebSocket(`${config.dialog}${path}`, subprotocol as any);
      const t = setTimeout(() => {
        try {
          ws.close();
        } catch {}
        resolve({ status: "timeout" });
      }, 10000);
      ws.onopen = () => {
        clearTimeout(t);
        resolve({ status: "opened" });
      };
      ws.onerror = () => {
        clearTimeout(t);
        resolve({ status: "error" });
      };
    } catch (e: any) {
      resolve({ status: "error", reason: e?.message });
    }
  });

test.describe("Dialog protoo handshake requirements", () => {
  test("rejects connection without protoo subprotocol", async () => {
    const r = await dialogConnect("/?roomId=ap&peerId=pe", undefined);
    // Server rejects with 403 'invalid/missing Sec-WebSocket-Protocol'.
    expect(r.status).toBe("error");
  });

  test("rejects connection with wrong subprotocol", async () => {
    const r = await dialogConnect("/?roomId=ap&peerId=pe", "not-protoo");
    expect(r.status).toBe("error");
  });

  test("opens with protoo subprotocol and valid roomId/peerId", async () => {
    const r = await dialogConnect(
      `/?roomId=dialogauth${Date.now()}&peerId=peer-${Date.now()}`,
      "protoo",
    );
    expect(r.status).toBe("opened");
  });
});
