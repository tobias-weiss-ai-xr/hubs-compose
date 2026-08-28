import { test, expect } from "@playwright/test";
import type { APIRequestContext } from "@playwright/test";
import { config, delay } from "./config";

/**
 * Scene-coverage tests for the "themed-element-scenes" capability (Epic 2 / Milestone A).
 *
 * Live state (2026-08-28, Milestone A DONE): all ~68 element rooms have a
 * `scene_id` assigned to one of the 5 restored archetype scenes, and reticulum's
 * `HubView` serializes `scene` into the `hub:<sid>` join response (with a
 * `model_url` pointing at the served glTF). These tests guard that contract
 * and verify the referenced GLB is actually reachable (no "Failed to load glTF").
 */

// Minimal Phoenix socket client (mirrors ws-join.spec.ts, kept self-contained).
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
        reject(new Error("socket error"));
      };
      ws.onmessage = (e) => {
        const msg = JSON.parse(String(e.data));
        if (msg[3] === "phx_reply") {
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
        reject(new Error(`phx_join ${topic} timed out`));
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
  close() {
    try {
      this.ws?.close();
    } catch {}
  }
}

async function createHub(request: APIRequestContext, hub: any): Promise<string> {
  for (let attempt = 0; attempt < 3; attempt++) {
    await delay(config.rateLimitDelayMs);
    const res = await request.post(`${config.api}/hubs`, {
      data: { hub },
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

test.describe("Scene coverage (themed-element-scenes)", () => {
  test("hub join response shape is stable (HubView regression)", async ({ request }) => {
    const hubId = await createHub(request, { name: `E2E Scene Shape ${Date.now()}` });
    const sock = new PhxSocket(config.socket);
    await sock.connect();
    await sock.join("ret", { hub_id: hubId });
    const reply = await sock.join(`hub:${hubId}`, {
      profile: { displayName: "e2e-scene" },
      context: { mobile: false, hmd: false, embed: false },
      perms_token: null,
    });
    expect(reply.status).toBe("ok");
    const hub = reply.response.hubs?.[0];
    expect(hub).toBeDefined();
    // Regression: the documented HubView fields must remain present.
    for (const k of ["hub_id", "host", "entry_mode", "name", "member_count"]) {
      expect(hub).toHaveProperty(k);
    }
    expect(hub.host).toBeTruthy();
    sock.close();
  });

  test("scenes show endpoint honors the spec (200 when restored, 404 otherwise)", async ({ request }) => {
    // Recovered archetype sid (ElementRoom v2, from legion). Not live yet.
    const sid = "rLL2FQw";
    const res = await request.get(`${config.api}/scenes/${sid}`, { ignoreHTTPSErrors: true });
    // Per spec: 200 once the scene is restored, 404 before. Both are contract-valid
    // (the endpoint must not 500 / 403), which is what we guard here.
    expect([200, 404]).toContain(res.status());
    if (res.status() === 200) {
      const body = await res.json();
      expect(body).toHaveProperty("base");
    }
  });

  test("element-query hub carries scene metadata when present", async ({ request }) => {
    await delay(config.rateLimitDelayMs);
    const q = await request.get(`${config.api}/hubs/element/${config.testSymbol}`, {
      ignoreHTTPSErrors: true,
    });
    expect([200, 403]).toContain(q.status());
    if (q.status() === 200) {
      const body = await q.json();
      const hub = body.hubs.find((h: any) => h.hub_id);
      // Surface the contract: if a scene is attached, it must have id + a loadable GLB.
      if (hub?.scene) {
        expect(hub.scene).toHaveProperty("scene_id");
        expect(hub.scene.model_url).toContain("/files/");
        const glb = await request.get(hub.scene.model_url, { ignoreHTTPSErrors: true });
        expect(glb.status()).toBe(200);
      }
    }
  });

  // Milestone A acceptance: an element room joins with a non-null, loadable scene.
  // We query /hubs/element/<sym> (the curated chemistry rooms, all carrying a
  // scene_id) and join rooms until we find one that surfaces a `scene` (this
  // tolerates ordering when other tests create fresh sceneless rooms).
  test("element room joins with a non-null, loadable scene", async ({ request }) => {
    await delay(config.rateLimitDelayMs);
    const q = await request.get(`${config.api}/hubs/element/${config.testSymbol}`, {
      ignoreHTTPSErrors: true,
    });
    expect(q.status()).toBe(200);
    const rooms = (await q.json()).hubs ?? [];
    expect(rooms.length).toBeGreaterThan(0);

    let tested: any = null;
    for (const r of rooms.slice(0, 5)) {
      const hubId = r.hub_id;
      if (!hubId) continue;
      const sock = new PhxSocket(config.socket);
      await sock.connect();
      await sock.join("ret", { hub_id: hubId });
      const reply = await sock.join(`hub:${hubId}`, {
        profile: { displayName: "e2e-scene-target" },
        context: { mobile: false, hmd: false, embed: false },
        perms_token: null,
      });
      const hub = reply.response.hubs?.[0];
      sock.close();
      if (hub?.scene) {
        tested = hub;
        break;
      }
    }
    expect(tested, "no element room surfaced a scene on join").toBeTruthy();
    expect(tested.scene.model_url).toContain("/files/");

    // The referenced GLB must be reachable (no "Failed to load glTF model").
    const glb = await request.get(tested.scene.model_url, { ignoreHTTPSErrors: true });
    expect(glb.status()).toBe(200);
    expect(glb.headers()["content-type"]).toContain("model/gltf-binary");
  });
});
