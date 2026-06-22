# Classroom Workflow

This document describes how teachers and students use the chemistry education VR platform.

## Overview

The platform enables chemistry education in virtual reality. Teachers create rooms
linked to periodic table elements, assign experiments, and manage student access
via time-limited JWT tokens.

## Roles

| Role | Capabilities |
|---|---|
| **Teacher** | Create rooms, assign element/experiments, generate access tokens, manage schedules |
| **Student** | Join rooms with access token, participate in experiments, view chemistry content |

## Workflow Steps

### 1. Teacher Creates a Room

```
Teacher → Hubs Client → POST /api/v1/hubs
                         { name, user_data: { chemistry: { symbol: "H", theme: "cosmic" } } }
```

Room is created with a chemical element. The element determines:
- Visual theme (cosmic, forge, biological, etc.)
- Available experiments
- PSE (Periodic Table of Elements) reference URL

### 2. Teacher Issues Access Tokens

```
POST /api/v1/rooms/token
{ room_id: "<hub_sid>", role: "teacher" }
→ { access_token: "<JWT>", room_id: "<hub_sid>", role: "teacher" }
```

Tokens are RS512-signed, valid for 5 minutes by default. Students receive
`role: "student"` tokens.

### 3. Students Join via Token

The student's client sends the token:
```
Authorization: Bearer <access_token>
GET /api/v1/rooms/<room_id>
```

`RoomAccessPlug` validates:
- JWT signature (RS512 via perms_key)
- Token expiry (5 min TTL)
- Room ID match
- Role assignment

### 4. Participate in Chemistry Experiments

Each element has associated experiments defined in `Ret.Chemistry`:

| Element | Experiments |
|---|---|
| H (Wasserstoff) | knallgas, fusion, fuelcell |
| He (Helium) | balloon, superfluid, laser |
| C (Kohlenstoff) | diamond, graphite, dna |
| Fe (Eisen) | magnet, rust, steel |
| Au (Gold) | ductilität, legierungen, elektroplattierung |
| ... | ... |

Experiments are rendered inside the 3D room via the Hubs client scene system.

### 5. Monitor Room Activity

Teachers can view room status via:
- **Spoke dashboard** at `/classroom` — Shows rooms grouped by element
- **Admin panel** at `:8989` — Account management
- **Health endpoint** at `GET /api/v1/health` — System status

## API Reference

### Room Token
```
POST /api/v1/rooms/token
Authorization: Bearer <session_token>
Content-Type: application/json

{ "room_id": "abc123", "role": "teacher" }

Response 201:
{ "access_token": "<JWT>", "room_id": "abc123", "role": "teacher" }

Response 422:
{ "error": "room_id is required" }
{ "error": "role must be 'student' or 'teacher'" }
```

### Room Access
```
GET /api/v1/rooms/<room_sid>
Authorization: Bearer <access_token>

Response 200: Room data (JSON)
Response 403:
  { "error": "missing_room_access_token" }
  { "error": "room_access_token_expired" }
  { "error": "token_missing_room_id" }
  { "error": "invalid_room_access_token" }
```

### Element Rooms
```
GET /api/v1/hubs/element/:symbol
→ { hubs: [...] }  // Rooms for this element, with pse_url
```

## Security

- All tokens are signed with RS512 (4096-bit RSA keys for dev)
- Room access tokens have 5-minute TTL
- Role-based access (student/teacher) enforced at plug level
- Rate limiting on token and hub creation endpoints
- Dialog WebRTC tokens also validated
- Coturn TURN relay uses auth-secret based credentials
