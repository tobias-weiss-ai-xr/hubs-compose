# Hubs Compose — Chemistry Education Platform

A Docker Compose setup orchestrating [Mozilla Hubs](https://github.com/mozilla/hubs-compose)
services for an interactive **chemistry education VR platform**.

## What This Fork Adds

This fork extends Mozilla Hubs with chemistry education features:

- **Periodic table integration** — Rooms linked to chemical elements (118 elements
  from H to Og), browsable via `GET /api/v1/hubs/element/:symbol`
- **JWT room access tokens** — Signed `access_token` for student/teacher role-based
  room entry via `POST /api/v1/rooms/token`
- **Room access middleware** — `RoomAccessPlug` validates tokens on room entry,
  enforcing expiry and role claims
- **Spoke classroom dashboard** — Chemistry room browser at `/classroom` in Spoke
- **Dialog auth middleware** — RS512 JWT verification for `GET`/`POST /rooms`
- **Coturn TURN server** — WebRTC relay for restrictive networks (TLS 5349, ports
  50000-50050 TCP+UDP)
- **Rate limiting** — `PlugAttack` on room token and hub creation endpoints
- **Prometheus + Grafana** — Metrics at `/metrics` (reticulum), dashboard at :3000

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                     Docker Host                       │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Reticulum │  │  Dialog   │  │   Hubs Client     │  │
│  │ :4001     │  │ :4443     │  │   :8081           │  │
│  │ (Elixir   │  │ (Node.js  │  │   (React/A-Frame) │  │
│  │  Phoenix) │  │  mediasoup│  └───────────────────┘  │
│  └────┬──────┘  └──────────┘  ┌───────────────────┐  │
│       │                       │   Hubs Admin      │  │
│  ┌────▼──────┐                │   :8989           │  │
│  │  PostgREST│  ┌──────────┐  └───────────────────┘  │
│  │  :3000    │  │  Spoke   │  ┌───────────────────┐  │
│  └───────────┘  │  :9091   │  │   Coturn (TURN)   │  │
│                 └──────────┘  │   :5349            │  │
│  ┌──────────┐  ┌──────────┐  └───────────────────┘  │
│  │PostgreSQL│  │ Prom/Graf│  ┌───────────────────┐  │
│  │ :5432    │  │ :9090/3k  │  │  PSE-VR (Hello    │  │
│  └──────────┘  └──────────┘  │  WebXR) :9090     │  │
│                              └───────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Services

| Service | Port | Tech | Description |
|---|---|---|---|
| **reticulum** | 4001 | Elixir/Phoenix | API server, auth, room management |
| **dialog** | 4443 | Node.js/mediasoup | WebRTC media server (SFU) |
| **hubs-client** | 8081 | React/A-Frame | 3D room client (main entry) |
| **hubs-admin** | 8989 | React | Admin panel |
| **spoke** | 9091 | React | Scene editor + classroom dashboard |
| **postgrest** | — | PostgREST | RESTful Postgres API |
| **db** | 5432 | PostgreSQL 14 | Primary database |
| **coturn** | 5349 | coturn/alpine | TURN/STUN relay server |
| **prometheus** | 9090 | Prometheus | Metrics collection |
| **grafana** | 3000 | Grafana | Metrics dashboards |
| **pse-vr** | 3000 | WebXR | Periodic table viewer |

## Quick Start

### Prerequisites
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Mutagen](https://mutagen.io/documentation/introduction/installation)
- [Mutagen Compose](https://github.com/mutagen-io/mutagen-compose#system-requirements)

### Setup

1. **Hosts entries** — Add to `/etc/hosts`:
   ```
   127.0.0.1   hubs.local hubs-proxy.local
   ```

2. **Environment** — Copy and edit:
   ```bash
   cp .env.example .env
   # Edit .env with your secrets
   ```

3. **Start services**:
   ```bash
   docker compose up --build -d
   ```

4. **Verify health**:
   ```bash
   docker ps
   curl -sk https://hubs.local:4001/health
   ```

5. **Accept self-signed certs** in your browser:
   - https://hubs.local:4001
   - https://hubs.local:4443
   - https://hubs.local:8081
   - https://hubs.local:8989
   - https://hubs.local:9091

> **Note**: The first `hubs-client` startup takes ~3m30s for webpack build.
> All other services start within ~30s.

### Auth Flow

```
┌──────────┐     POST /api/v1/rooms/token     ┌───────────┐
│ Teacher   │ ──────────────────────────────►  │ Reticulum │
│ (Hubs)    │     {room_id, role}              │           │
└──────────┘                                   │ RS512 JWT │
      │                                        │ 5-min TTL │
      │     {access_token, room_id, role}      └─────┬─────┘
      │ ◄─────────────────────────────────────────────┘
      │
      │     POST /api/v1/rooms/:room_id               │
      │     Authorization: Bearer <token>              │
      │ ──────────────────────────────────────────────►│
      │                          RoomAccessPlug verifies│
      │                           - signature           │
      │                           - expiry              │
      │                           - room_id match       │
      │ ◄── 200 OK / 403 error ◄───────────────────────┘
```

## Testing

```bash
# Elixir tests (inside reticulum container)
docker exec hubs-compose-reticulum-1 mix test

# E2E tests (host)
cd e2e && npx playwright test --reporter=list

# Performance tests (if k6 installed)
k6 run e2e/load-test.js
```

### User Stories & Live Tests

User epics and user stories covering the whole roadmap live in
[`docs/user-stories.md`](docs/user-stories.md) (30 epics, `US-001…US-241`). Each story
carries a status: `✅ tested` (live), `🧪 service-tested` (Reticulum `mix test`),
`🚧 built`, or `📋 planned`.

**Tier 1 — live tests** only cover stories whose features are **already live** on
`https://hubs.chemie-lernen.org` (no local stack boot needed):

```bash
cd e2e && npm run test:live
```

**Tier 2 — Reticulum service tests** (`🧪 service-tested`) exercise the fork's auth,
room-access, chemistry, and rate-limit code (`services/reticulum/test/`, e.g.
`room_access_plug_test.exs`, `room_access_controller_test.exs`,
`hub_controller_chemistry_test.exs`, `rate_limit_test.exs`, `chemistry_test.exs`).
Run them inside the dev image against a local Postgres:

```bash
docker run --rm \
  -e MIX_ENV=test -e DB_HOST=172.17.0.1 -e DB_CREDENTIALS=postgres \
  -v "$PWD/services/reticulum:/code" -w /code \
  hubs-compose-reticulum:latest mix test test/ret_web/plugs/room_access_plug_test.exs \
    test/ret_web/controllers/api/room_access_controller_test.exs \
    test/ret_web/controllers/api/hub_controller_chemistry_test.exs \
    test/ret_web/plugs/rate_limit_test.exs test/ret/chemistry_test.exs
```

> `services/` is gitignored by repo policy; service-test edits live in the working tree
> next to the (upstream-managed) service sources.

Suite layout:

```
e2e/
  playwright.live.config.ts              # live-domain config (strict TLS)
  epics/
    ep-01-auth-rooms.spec.ts            # US-001, US-011, US-019
    ep-02-chemistry-content.spec.ts     # US-013, US-014, US-021, US-027, US-097, US-101
    ep-03-element-data.spec.ts          # US-024 (table breadth), US-027 (unknown symbol)
```

Every live test is named with its story id (e.g. `test("US-011 …")`) so failures trace
straight back to the requirement.

**Traceability check** — verifies that `✅`/`🧪` tested stories actually have tests
(live `e2e/epics/*.spec.ts` **or** `services/reticulum/test/**/*.exs`) and that no
stale tests linger on unmarked stories:

```bash
python3 scripts/check-story-tests.py            # informational
python3 scripts/check-story-tests.py --strict   # fail on mismatch (CI)
```

To mark a newly covered feature: flip the story status to `✅ tested`, add the `US-0xx`
test to the relevant `e2e/epics/*.spec.ts`, and re-run both the suite and the check.

## Configuration

Key environment variables (see `.env.example`):

| Variable | Default | Purpose |
|---|---|---|
| `HUBS_HOST` | hubs.tobias-weiss.org | Public hostname |
| `DB_CREDENTIALS` | postgres | Postgres password |
| `PERMS_KEY_PATH` | /etc/perms.pem | JWT signing key |
| `SMTP_SERVER` | mail.tobias-weiss.org | Email server |
| `MEDIASOUP_ANNOUNCED_IP` | hubs.local | WebRTC IP for clients |
| `DIALOG_HOSTNAME` | hubs.local | Dialog service host |
| `DIALOG_PORT` | 4443 | Dialog service port |

## Upstream

This fork tracks [mozilla/hubs-compose](https://github.com/mozilla/hubs-compose).
Custom branches integrated:
- `webrtc-support` — Mediasoup ports for WebRTC
- `coturn-support` — TURN relay server

See `docs/architecture.md` for detailed component descriptions.
