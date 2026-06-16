# Prometheus Sprint Plan: VREd Sprint 1 — Chemistry VR Platform Integration

**Generated**: 2026-06-16
**Source**: Metis Pre-Planning Analysis (ses_13a4cfb66ffeZEvYbAhng3uW4R)
**Status**: Ready for execution
**Execution Mode**: Ultrawork (`.sisyphus/codons/` numbered tasks, sequential)

---

## Table of Contents

1. [Strategic Landscape](#strategic-landscape)
2. [Priority Recommendation](#priority-recommendation)
3. [Architecture Decisions](#architecture-decisions)
4. [Sprint Boundaries](#sprint-boundaries)
5. [Execution Plan (Codons)](#execution-plan-codons)
6. [Commit Strategy](#commit-strategy)
7. [QA/Acceptance Criteria](#qaacceptance-criteria)
8. [Risks & Mitigations](#risks--mitigations)
9. [Ambiguities to Resolve](#ambiguities-to-resolve)

---

## Strategic Landscape

### Three Opportunities Identified

| # | Opportunity | Value | Effort | Risk |
|---|-------------|-------|--------|------|
| **A** | **PSE-in-VR ↔ Hubs Integration Bridge** | Create a chemistry classroom where students explore all 118 elements socially in VR. No competitor has a live chemistry VR deployment. | **3–6 weeks** | Medium (CORS, iframe, auth) |
| **B** | **CI/CD & Production Hardening** | Move from dev docker-compose with mutagen to CI/CD (Forgejo runner). Deployment confidence, rollback, fast iteration. | **2–3 weeks** | Low (config only) |
| **C** | **Authorization & Room Access Control** | Per-classroom JWT-based room auth via Reticulum + Dialog. Teacher-controlled classrooms. | **2–3 months** | High (Elixir deep, security) |

### Recommendation: Option A First (Integration Bridge)

**Rationale**: The integration delivers immediate differentiated value — it's the feature that makes the platform unique. CI/CD (Option B) should run in parallel as it enables safe iteration through Options A and C. Option C is deferred to Sprint 2 because:
- It requires deep Elixir customization of Reticulum
- Security auditing takes time
- The integration work (A) establishes the architecture patterns that auth will build on

---

## Architecture Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| **AD-001** | Use iframe media-frame embedding (not custom Hubs client fork) for PSE integration | Prevents divergence from upstream Hubs. Zero Hubs client code changes needed. |
| **AD-002** | Pass element symbol via URL parameter (`?element=Na`) in iframe src | Simple, stateless, cacheable. No server-side session needed for room→element mapping. |
| **AD-003** | CORS proxy in Reticulum (not separate service) | Minimizes operational surface. Reuses existing Phoenix endpoint infrastructure. |
| **AD-004** | Auth via Dialog JWT (Hubs' existing WebRTC auth flow) | Leverages existing infra. No custom Elixir auth module needed. |
| **AD-005** | PSE room type as Reticulum Ecto schema, not hardcoded route | Data-driven. Adding elements doesn't require code changes — just DB records. |

---

## Sprint Boundaries

### IN SCOPE
- PSE-in-VR ↔ Hubs integration (iframe embedding, CORS proxy, room type)
- Spoke measurement tool (first Spoke extensibility feature)
- Dialog cert configuration consolidation
- CI/CD pipeline for hubs-compose
- E2E integration tests

### NOT IN SCOPE (Explicitly Excluded)
- Custom Hubs client modifications (fork prevention — AD-001)
- Room access control / authorization (Sprint 2)
- Custom avatars or chemistry-themed inventory
- PostgREST API extensions
- Mobile app or native VR (Quest standalone)
- Multi-language support beyond existing German UI
- Spoke scene templates (separate project)

---

## Execution Plan (Codons)

### Execution Order

```
Codon-02 (certs) → Codon-01 (spoke tool) → Codon-06 (CI/CD) → Codon-03 (room type) → Codon-04 (embed) → Codon-05 (deploy) → Codon-07 (e2e test)
```

Each codon is **one atomic commit**. Every commit must pass verification before proceeding.

---

### Codon 01: Spoke Measurement Tool

| Field | Value |
|-------|-------|
| **Repository** | hubs-compose (`services/spoke/`) |
| **Files** | `src/ui/`, `src/editor/` (Spoke source tree) |
| **Commit msg** | `feat(spoke): add measurement tool showing position, rotation, scale of selected objects` |
| **Effort** | 2–3 days |
| **Dependencies** | None |

**What**: Build a React component in Spoke's toolbar that shows position (x,y,z in meters), rotation (x,y,z in degrees), and scale of selected 3D objects in a floating panel.

**TDD Steps**:
1. Test: mount component, verify it renders without selection
2. Test: select an object, verify panel shows numeric values
3. Test: deselect, verify panel shows "no selection" state
4. Test: verify values update when object is moved via transform controls

**QA Scenarios**:
```
Playwright: new Spoke project → add box → click 📐 → panel visible
→ select box → Position/Rotation/Scale shown
→ deselect → "No object selected"
```

---

### Codon 02: Dialog Certs Consolidation

| Field | Value |
|-------|-------|
| **Repository** | hubs-compose (root) |
| **Files** | `docker-compose.yml`, `docker-compose.override.yml`, `services/reticulum/config/config.exs` |
| **Commit msg** | `chore(reticulum): consolidate Dialog certificate config` |
| **Effort** | 1–2 days |
| **Dependencies** | None |

**What**: Move `AUTH_KEY`, `HTTPS_CERT_FULLCHAIN`, and `HTTPS_CERT_PRIVKEY` environment variables from docker-compose.yml into Reticulum's `config.exs`. Single source of truth for service auth.

**QA**:
```
docker-compose config -q → exit 0
docker-compose up -d dialog reticulum
curl -fk https://localhost:4443/health → 200
curl -fk https://localhost:4001/healthz → 200
```

---

### Codon 03: CI/CD Pipeline

| Field | Value |
|-------|-------|
| **Repository** | hubs-compose (root) |
| **Files** | `.forgejo/workflows/ci.yml`, `.forgejo/workflows/deploy.yml` |
| **Commit msg** | `ci(hubs-compose): add full CI pipeline with build, test, lint stages` |
| **Effort** | 3–5 days |
| **Dependencies** | None |

**What**: Forgejo Actions pipeline that:
1. Validates docker-compose syntax
2. Builds all service Docker images
3. Runs Reticulum Elixir compilation (`mix compile --warnings-as-errors`)
4. Runs hubs-client lint + build
5. Runs Spoke build
6. Runs E2E integration tests (from Codon 07)

---

### Codon 04: PSE VR Room Type + CORS Proxy

| Field | Value |
|-------|-------|
| **Repository** | hubs-compose (`services/reticulum/`) |
| **Files** | `lib/ret/room.ex`, `lib/ret_web/controllers/api/v1/room_controller.ex`, `lib/ret_web/plugs/cors_proxy.ex`, `config/config.exs`, `priv/repo/migrations/` |
| **Commit msg** | `feat(reticulum): add PSE VR room type with CORS proxy` |
| **Effort** | 1–2 weeks |
| **Dependencies** | Codon 02 (certs consolidation) |

**What**: 
- Ecto schema migration: add `pse_vr` to room type enum
- Room schema: add `element_symbol` field (string, nullable)
- API: POST `/api/v1/rooms` accepts `type: "pse_vr"` + `element: "Na"`
- API: GET `/api/v1/rooms/:id` returns `pse_url: "https://pse.chemie-lernen.org?element=Na"`
- CORS proxy plug at `/api/v1/pse-proxy` whitelists `pse.chemie-lernen.org`
- Hubs client config: new room type creates media frame with iframe

**TDD Steps**:
1. Write Ecto migration test: `add_pse_vr_room_type` rolls forward and back
2. Write API test: `POST /api/v1/rooms` with `type: "pse_vr"` returns 201
3. Write API test: response includes `pse_url` with URL-encoded element
4. Write CORS test: proxy returns `Access-Control-Allow-Origin: https://pse.chemie-lernen.org`
5. Write CORS test: proxy returns 403 for unauthorized origin

---

### Codon 05: PSE Embed Mode + Element Room Linking

| Field | Value |
|-------|-------|
| **Repository** | hello-webxr (`pse-in-vr` branch → merge to `master`) |
| **Files** | `src/index.ts`, `src/embed/mount.ts`, `src/rooms/RoomManager.ts`, `src/types/index.ts` |
| **Commit msg** | `feat(pse-vr): add embed mode with element room URL param navigation` |
| **Effort** | 1 week |
| **Dependencies** | None |

**What**: 
- Parse `element` URL param on app load
- Navigate directly to that element's room (bypass Lobby)
- Hide navigation UI elements in embed mode (nav hints, toolbar, controls)
- Support `postMessage` API for parent frame communication
- Graceful fallback: invalid element symbol → Lobby

**TDD Steps**:
1. Test: `mount()` with `element="Na"` navigates to Natrium room
2. Test: `mount()` with invalid symbol falls back to Lobby  
3. Test: embed mode hides navigation UI
4. Test: parent frame receives `roomChanged` postMessage events

---

### Codon 06: Production PSE Deployment via Traefik

| Field | Value |
|-------|-------|
| **Repository** | hello-webxr (root) |
| **Files** | `docker-compose.yml`, `Dockerfile`, `nginx.conf` |
| **Commit msg** | `deploy(pse-vr): production Docker deployment with Traefik reverse proxy` |
| **Effort** | 2–3 days |
| **Dependencies** | Codon 05 (embed mode) |

**What**: Verify and productionize PSE Docker deployment:
- Dockerfile already exists (node:20 build → nginx:alpine serve)
- docker-compose.yml already has Traefik labels pointing to `pse.chemie-lernen.org`
- Must connect to `traefik-public` Docker network
- nginx config already optimized for SPA (gzip, caching, security headers)

**QA**:
```
docker-compose up -d --build
curl -sI https://pse.chemie-lernen.org → HTTP/2 200
curl -sI "https://pse.chemie-lernen.org?element=Fe" → HTTP/2 200
Traefik dashboard shows pse.chemie-lernen.org router
```

---

### Codon 07: End-to-End Integration Tests

| Field | Value |
|-------|-------|
| **Repository** | hubs-compose (root) |
| **Files** | `e2e/pse-integration.spec.ts`, `playwright.config.ts` |
| **Commit msg** | `test(e2e): add PSE VR integration test covering end-to-end flow` |
| **Effort** | 3–5 days |
| **Dependencies** | Codon 03 (CI/CD), Codon 04 (room type), Codon 05 (embed) |

**What**: Playwright E2E tests that validate the entire chain:
1. Create PSE VR room via Reticulum API
2. Navigate to Hubs room URL
3. Verify iframe loads PSE app with correct element
4. Verify element room content matches expected element

---

## Commit Strategy

### Rules
1. **One commit per codon** — always. If a codon is too big, split it.
2. **Every commit must pass**: `docker-compose config -q` + relevant service tests
3. **Commit message format**: `type(scope): description`
   - Types: `feat`, `fix`, `chore`, `test`, `ci`, `refactor`, `docs`, `deploy`
4. **Each commit must be independently revertible**
5. **No mega-commits** — if you're touching 3 unrelated services, that's 3 commits

### Squash Policy
No squashing during sprint. Squash only on merge to `main`.

### Execution Cycle (per codon)
```
1. Write failing test(s)
2. Implement feature
3. Pass tests → commit
4. Push to Codeberg
5. CI validates → green
6. 👉 NEXT CODON
```

---

## QA/Acceptance Criteria

> **ZERO USER INTERVENTION PRINCIPLE**: All acceptance criteria AND QA scenarios MUST be executable by agents.

| Codon | QA Tool | Key Verification |
|-------|---------|------------------|
| 01 (Spoke tool) | Playwright | Panel shows coords, toggles on/off, updates in real-time |
| 02 (Certs) | bash + curl | `docker-compose config -q` passes, services healthcheck OK |
| 03 (CI/CD) | Forgejo Actions | Pipeline green: lint → build → test → deploy |
| 04 (Room type) | curl | POST/GET room API returns 201/200 with pse_url |
| 05 (Embed) | Playwright | Element param navigates to correct room, embed mode hides UI |
| 06 (Deploy) | bash + curl | `https://pse.chemie-lernen.org` returns 200 with valid SSL |
| 07 (E2E) | Playwright | Full chain: API → room → iframe → element content |

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CORS blocks iframe communication | Medium | High | AD-003: CORS proxy in Reticulum handles whitelist |
| Upstream Hubs changes conflict with customizations | Low | Low | AD-001: iframe embedding = zero client fork = zero conflict |
| Babylon.js PSE build size too large for iframe loading | Low | Medium | Code splitting in vite.config.ts; lazy load element rooms |
| Dialog WebRTC breaks after cert path change | Medium | Medium | Codon 02: rollback plan is `git revert HEAD`, tested QA |
| Element data format mismatch (Hubs ↔ PSE) | Medium | Medium | Codon 04: element_symbol stored as free string, mapped by PSE |
| CI runner resource exhaustion | Low | Medium | Forgejo runner runs on same host; add resource limits in CI config |

---

## Ambiguities to Resolve

These should be answered **before** starting the relevant codon:

1. **Element data source**: Does PSE-in-VR already have all 118 elements with German names? (Yes — verified from `ELEMENTS` array in `elements.ts` with fields: symbol, name, atomicNumber, mass, group, period, block, color, description, theme, experiments)

2. **Hubs room ↔ PSE room mapping**: Should one Hubs room = one element, or one Hubs room = one theme (multiple elements)? **Decision needed**: Room-per-element gives focused social exploration. Room-per-theme gives group tour feel. Recommend per-element (most educational value).

3. **Deployment domain for PSE**: Already `pse.chemie-lernen.org` — confirmed in existing docker-compose.yml labels. No action needed.

4. **PSE branch strategy**: `pse-in-vr` branch currently diverged from `master`. Should we merge to `master` or deploy from the branch? **Recommendation**: Deploy from `pse-in-vr` until Sprint 1 validated, then merge to `master`.

5. **Spoke measurement tool scope**: Should it ONLY show measurements, or also allow editing values numerically? **Recommendation**: Read-only for Sprint 1. Numeric edit is a separate feature.

---

## Summary

```
Sprint 1: VREd Integration
├── Codon 02: Certs consolidation (1-2d) ◀── START HERE
├── Codon 01: Spoke measurement tool (2-3d)
├── Codon 06: CI/CD pipeline (3-5d)
├── Codon 03: PSE room type + CORS proxy (1-2w)
├── Codon 04: PSE embed mode (1w)
├── Codon 05: Production deployment (2-3d)
└── Codon 07: E2E integration tests (3-5d)

Total: ~4-6 weeks sequential, ~3-4 weeks with parallelization
```

The key insight: **Codons 01+02+06 can run in parallel with Codons 04+05** (different repos). Only Codons 03→04→07 must be sequential within their chain.
