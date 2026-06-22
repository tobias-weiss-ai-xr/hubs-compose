# Architecture Overview

## System Architecture

Hubs Compose orchestrates 11+ Docker containers to deliver a VR chemistry education
platform. Each service runs in an isolated container with Mutagen file sync for
live development.

## Service Breakdown

### Reticulum (Elixir/Phoenix — Port 4001)

The central API server. Built with Phoenix 1.5 + Ecto + Absinthe (GraphQL).

**Key modules:**

| Module | Purpose |
|---|---|
| `Ret.Hub` | Room/hub schema and CRUD |
| `Ret.PermsToken` | RS512 JWT generation (5-min TTL) |
| `Ret.Chemistry` | 118 element definitions, validation |
| `Ret.Room.Token` | HS512 JWT for room access |
| `RetWeb.Plugs.RoomAccess` | Token validation on room entry |
| `RetWeb.Api.V1.RoomAccessController` | Token issue endpoint |
| `RetWeb.Api.V1.HubController` | Hub CRUD + chemistry validation |
| `RetWeb.HealthController` | System health check |

**Auth pipeline:**
1. `POST /api/v1/rooms/token` — issues RS512 JWT (room_id, role, 5-min TTL)
2. Client sends token as `Authorization: Bearer <token>` to room API
3. `RoomAccessPlug` validates: signature → expiry → room_id
4. `Ret.PermsToken` verifies via Guardian with perms_key (RS512)

### Dialog (Node.js/mediasoup — Port 4443)

WebRTC Selective Forwarding Unit (SFU). Handles audio/video relay between room
participants. Custom auth middleware (`lib/authMiddleware.js`) validates RS512
room tokens on `GET /rooms` and `POST /rooms`.

**Mediasoup ports:** 40000-40050 (TCP+UDP) for WebRTC media transport.

### Hubs Client (React/A-Frame — Port 8081)

The 3D room client. Renders immersive VR/3D environments where users interact.
Uses A-Frame (WebXR) for 3D rendering with React for UI overlays.

**Key subsystems:**
- `hub.js` — Room entry and scene management
- `react-components/room/` — Room UI components
- `bit-systems/` — ECS-style component systems for 3D interactions

### Hubs Admin (React — Port 8989)

Administrative panel for managing accounts, rooms, and settings.

### Spoke (React — Port 9091)

Scene editor for creating 3D environments. Extended with:
- **Classroom dashboard** at `/classroom` — chemistry room browser
- Element-based room filtering and management

### Coturn (coturn/alpine — Ports 5349/TLS, 50000-50050)

TURN/STUN relay server for WebRTC fallback in restrictive networks.
- PostgreSQL-backed user database (coturn schema in ret_dev)
- TLS on 5349 with dev self-signed certs
- Auth secret-based temporary credentials

### PostgREST (Port 3000)

RESTful PostgreSQL API for direct database access from frontend services.

## Data Flow

### Room Creation
```
Teacher → Hubs Client → POST /api/v1/hubs → Reticulum → PostgreSQL
                 ↑ (chemistry metadata in user_data)
```

### Room Access
```
Student → GET /api/v1/rooms/:room_id → RoomAccessPlug
  ↑                                        ↓
  ├── Token valid?                   Parses JWT, checks:
  │   ├── Yes → 200 + room data       - RS512 signature (perms_key)
  │   └── No → 403 error              - expiry (5 min TTL)
  │                                   - room_id match
  │
  └── Dialog WebRTC ←───────────────── Media token relay
```

### Metrics Pipeline (Prometheus)
```
reticulum → /metrics (Prometheus text format) → Prometheus :9090 → Grafana :3000
```

## Network Topology

All services connect via a shared Docker network (`mozilla-hubs`). Internal
communication uses service names as hostnames:
- `db:5432` — PostgreSQL
- `postgrest:3000` — PostgREST
- `dialog:4443` — Dialog
- `hubs-client:8080` — Hubs client (internal)
- `reticulum:4000` — Reticulum (internal)

## Mutagen Sync

Live file synchronization between host and containers:

| Volume | Host Path | Container Path |
|---|---|---|
| `reticulum` | `./services/reticulum/` | `/code` |
| `hubs` | `./services/hubs/` | `/code` |
| `dialog` | `./services/dialog/` | `/code` |
| `spoke` | `./services/spoke/` | `/code` |

Sync mode: `two-way-resolved` with VCS and `node_modules/` ignored.
