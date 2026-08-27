import { test, expect } from "@playwright/test";
import type { APIRequestContext } from "@playwright/test";
import { config, delay } from "./config";

/**
 * WebSocket room-join regression tests.
 *
 * These are the regression tests for the "join crashed" bug chain fixed 2026-08-27:
 *   1. RoomAssigner.get_available_host crash (Enumerable not implemented for nil)
 *      because JanusLoadStatus cache was never populated (TURKEY_MODE + K8s DNS).
 *   2. PermsTokenSecretFetcher :jose_jwk.from_pem(nil) — perms_key missing.
 *   3. Dialog serving an expired TLS cert on :4443 + empty MEDIASOUP_ANNOUNCED_IP.
 *
 * Flow covered (mirrors the browser join exactly):
 *   wss://…/socket/websocket?vsn=2.0.0 → join "ret" → join "hub:<sid>" →
 *   hub JSON returned with populated host → dialog protoo WS (subprotocol "protoo")
 *   → getRouterRtpCapabilities ok.
 *
 * Node 22 has a native global WebSocket; these run out-of-process in Playwright.
 */

// Minimal Phoenix socket client to keep the test self-contained (no npm dep).
class PhxSocket {
  private ws?: WebSocket;
  private ref = 0;
  private pending = new Map<string, { resolve: (m: any) => void; reject: (e?: any) => void }>();
  onMessage?: (msg: any[]) => void;

  constructor(private url: string) {}

  connect(timeoutMs = 10000): Promise<void> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(this.url);
      this.ws = ws;
      const t = setTimeout(() => reject(new Error("socket connect timeout")), timeoutMs);
      ws.onopen = () => {
        clearTimeout(t);
        resolve();
      };
      ws.onerror = () => {
        clearTimeout(t);
        reject(new Error("socket error (check /socket/websocket reachability)"));
      };
      ws.onmessage = (e) => {
        const msg = JSON.parse(String(e.data));
        if (msg[3] === "phx_reply") {
          // msg[0] is the join_ref echoed back by the server (matches what we sent).
          const joinRef = String(msg[0]);
          const p = this.pending.get(joinRef);
          if (p) {
            this.pending.delete(joinRef);
            msg[4]?.status === "ok" ? p.resolve(msg[4]) : p.reject(new Error(JSON.stringify(msg[4])));
          }
        }
        this.onMessage?.(msg);
      };
    });
  }

  join(topic: string, payload: any, timeoutMs = 15000): Promise<any> {
    const ref = String(++this.ref);
    const joinRef = `jr-${ref}`;
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => {
        this.pending.delete(joinRef);
        reject(new Error(`phx_join ${topic} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(joinRef, {
        resolve: (m) => {
          clearTimeout(t);
          resolve(m);
        },
        reject: (e) => {
          clearTimeout(t);
          reject(e);
        },
      });
      this.ws?.send(JSON.stringify([joinRef, ref, topic, "phx_join", payload]));
    });
  }

  /**
   * Join the "ret" channel. The server REQUIRES a hub_id (both join clauses
   * match on it) — sending an empty payload returns reason:"join crashed".
   */
  joinRet(hubId: string): Promise<any> {
    return this.join("ret", { hub_id: hubId });
  }

  close() {
    try {
      this.ws?.close();
    } catch {}
  }
}

test.describe("WebSocket room join (join-crashed regression)", () => {
  // Create a throwaway hub so tests exercise the join path for a freshly
  // created room rather than depending on a fixed sid persisting.
  async function createHub(request: APIRequestContext): Promise<string> {
    for (let attempt = 0; attempt < 3; attempt++) {
      await delay(config.rateLimitDelayMs);
      const res = await request.post(`${config.api}/hubs`, {
        data: { hub: { name: `E2E WS Join ${Date.now()}-${attempt}` } },
        ignoreHTTPSErrors: true,
      });
      if (res.status() === 200) {
        const body = await res.json();
        expect(body.hub_id).toBeTruthy();
        return body.hub_id as string;
      }
      if (res.status() === 403 && attempt < 2) {
        await delay(config.rateLimitDelayMs * 2);
        continue;
      }
      expect(res.status()).toBe(200);
    }
    throw new Error("createHub exhausted retries");
  }

  test("socket connects and ret channel joins", async ({ request }) => {
    const hubId = await createHub(request);
    const sock = new PhxSocket(config.socket);
    await sock.connect();
    const reply = await sock.joinRet(hubId);
    expect(reply.status).toBe("ok");
    expect(reply.response).toHaveProperty("session_id");
    sock.close();
  });

  test("hub channel join returns full hub JSON with populated host (RoomAssigner fix)", async ({ request }) => {
    const hubId = await createHub(request);
    const sock = new PhxSocket(config.socket);
    await sock.connect();
    await sock.joinRet(hubId);

    const reply = await sock.join(`hub:${hubId}`, {
      profile: { displayName: "e2e-ws-test" },
      context: { mobile: false, hmd: false, embed: false },
      perms_token: null,
    });

    expect(reply.status).toBe("ok");
    const hub = reply.response.hubs?.[0];
    expect(hub).toBeDefined();
    expect(hub.hub_id || reply.response.hub_id).toBeTruthy();
    // Regression: host must NOT fall back to nil/empty (was "join crashed" before).
    expect(hub.host).toBeTruthy();
    expect(config.base).toContain(new URL(hub.host.startsWith("http") ? hub.host : `https://${hub.host}`).hostname);
    sock.close();
  });

  test("presence_state is emitted to joined hub channel", async ({ request }) => {
    const hubId = await createHub(request);
    const sock = new PhxSocket(config.socket);
    await sock.connect();
    await sock.joinRet(hubId);

    const presencePromise = new Promise<any[]>((resolve) => {
      sock.onMessage = (msg) => {
        if (msg[3] === "presence_state") resolve(msg);
      };
    });

    await sock.join(`hub:${hubId}`, {
      profile: { displayName: "e2e-ws-presence" },
      context: { mobile: false, hmd: false, embed: false },
      perms_token: null,
    });

    const presence = await Promise.race([
      presencePromise,
      new Promise((_, rej) => setTimeout(() => rej(new Error("no presence_state")), 10000)),
    ]);
    expect((presence as any[])[3]).toBe("presence_state");
    sock.close();
  });

  test("dialog protoo WS connects and answers getRouterRtpCapabilities (TLS/announced-IP fix)", async ({ request }) => {
    const hubId = await createHub(request);
    const url = `${config.dialog}/?roomId=${hubId}&peerId=e2e-dialog-peer-${Date.now()}`;
    const ws = new WebSocket(url, "protoo"); // protoo subprotocol required
    await new Promise<void>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error("dialog connect timeout")), 15000);
      ws.onopen = () => {
        clearTimeout(t);
        resolve();
      };
      ws.onerror = () => {
        clearTimeout(t);
        reject(new Error("dialog WS error (cert / protocol / announced-ip issue)"));
      };
    });

    const caps = await new Promise<any>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error("no rtp caps response")), 15000);
      ws.onmessage = (e) => {
        const m = JSON.parse(String(e.data));
        if (m.response && m.id === 1) {
          clearTimeout(t);
          resolve(m);
        }
      };
      ws.send(JSON.stringify({ request: true, id: 1, method: "getRouterRtpCapabilities", data: {} }));
    });

    expect(caps.ok).toBe(true);
    expect(Array.isArray(caps.data.codecs)).toBe(true);
    const audio = caps.data.codecs.find((c: any) => c.kind === "audio");
    expect(audio).toBeDefined();
    expect(audio.mimeType).toBe("audio/opus");
    try {
      ws.close();
    } catch {}
  });
});
