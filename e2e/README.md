# E2E test suite

Playwright end-to-end tests for the **live** Hubs deployment (hubs.chemie-lernen.org)
and its PSE (Periodensystem) room feature.

## Run

```bash
npm install
npm run test:live        # against https://hubs.chemie-lernen.org (default)
# or local stack:
HUBS_BASE_URL=http://localhost:9090 DIALOG_URL=https://localhost:4443 npx playwright test
```

Caveat: the suite creates throwaway hubs via `POST /api/v1/hubs`, which the live
Reticulum throttles (~1 burst → 403). Tests serialize (`workers: 1`) and retry on
transient 403. Do not run against prod in parallel with other hub-creating load.

## What's covered

| Spec | Covers |
|---|---|
| `ws-join.spec.ts` | **Room-join regression** for the 2026-08-27 "join crashed" fix chain: Phoenix WS connect → `ret` channel join → `hub:<sid>` join returns full hub JSON with populated `host` (RoomAssigner) → presence → dialog protoo WS + `getRouterRtpCapabilities` (TLS/announced-IP) |
| `pse-rooms.spec.ts` | Element room create → element query round-trip, `pse_url` injection, pagination, `/api/v1/meta` host |
| `scene-room.spec.ts` | Scene capability coverage (Epic 2 / Milestone A): HubView join-response shape regression, `GET /api/v1/scenes/:sid` contract; real post-restore assertion is `test.fixme` (blocked on scene restore + HubView scene surfacing) |
| `pse-integration.spec.ts` | Hub-create embed contract (`hub_id`/`url`/`embed_token`/`creator_assignment_token`) |
| `auth-flow.spec.ts` | Hub create auth_optional, invalid element 400, element query, classroom flow, hub.html `APP.hub` host embed, frontend smoke |
| `dialog-auth.spec.ts` | Dialog protoo subprotocol requirement (no REST `/rooms` on this dialog) |

## Config

Endpoints are derived from env (`HUBS_BASE_URL`, `DIALOG_URL`, `TEST_ELEMENT_SYMBOL`) in
`config.ts` — see defaults there. Requires Node ≥ 22 (native `WebSocket`).
