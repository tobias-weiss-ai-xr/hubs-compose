# Design: User Epics, User Stories & Tests for hubs-compose

**Date:** 2026-08-26
**Status:** Proposed
**Author:** pi agent session
**Repo:** hubs-compose (Mozilla Hubs + chemistry education VR platform)

---

## 1. Goal

Add a structured, user-centric requirements layer to the hubs-compose project:

1. **User Epics** covering the **entire roadmap** (Sprints 1–13, codons 00–53) — each
   epic expressed from the perspective of the people who use the platform.
2. **User Stories** decomposed from those epics in the standard
   `As a <persona>, I want <capability>, so that <benefit>` format, one per numbered
   story (`US-001` … `US-0xx`).
3. **Automated tests** for the stories whose features are **already built and live** on
   the production endpoint `https://hubs.chemie-lernen.org`. Planned-but-unbuilt stories
   are documented and reported as *skipped*, never as failures.

### Scope split (user-confirmed)

| Layer | Coverage | Status today |
|---|---|---|
| Epics + User Stories (docs) | **Whole roadmap** (Sprints 1–13, codons 00–53) | new document |
| Automated tests | **Only built & running** features on `hubs.chemie-lernen.org` | extend `e2e/` |

### Runtime target (user-confirmed)

The platform runs under **`https://hubs.chemie-lernen.org`** (DNS → 178.254.2.90, TLS 200).
Tests target this live domain directly. No local stack boot required for the test suite.

---

## 2. Personas

- **Teacher** — creates/manages rooms, runs the VR classroom, grades and tracks students.
- **Student** — joins rooms, explores elements, takes quizzes, learns in VR or browser.
- **Admin / Operator** — deploys, monitors, backs up, secures the platform.
- **Developer** — extends, debugs, and benchmarks the platform.

---

## 3. Epic Map (EP-01 … EP-21) — whole roadmap

Epics are finer-grained per functional concern while keeping full traceability to
roadmap sprints and codons. 21 epics replace the earlier 11-epic sprint-aligned draft
(user request: more epics, more stories).

| Epic | Title | Roadmap | Codons |
|---|---|---|---|
| EP-01 | Access & Authentication | Sprints 1–3 | 00–13 |
| EP-02 | Rooms & Classroom Dashboard | Sprints 1–3 (+Spoke) | 00–13 |
| EP-03 | Chemistry Content & Periodic Table | Sprint 4 | 14 |
| EP-04 | 3D Atomic Models & Visualization | Sprint 4 | 15, 17 |
| EP-05 | Chemical Reactions & Simulations | Sprint 4 | 16 |
| EP-06 | Classroom Synchronization | Sprint 5 | 18–21 |
| EP-07 | Assessment & Quizzes | Sprint 6 | 22 |
| EP-08 | Progress Tracking & Teacher Analytics | Sprint 6 | 23–24 |
| EP-09 | Guided Learning & Lab Worksheets | Sprint 6 | 25 |
| EP-10 | VR Performance Optimization | Sprint 7 | 26–27 |
| EP-11 | VR Interaction & Comfort | Sprint 7 | 28–29 |
| EP-12 | Scalability & Performance | Sprint 8 | 30 |
| EP-13 | Security & Privacy | Sprint 8 | 31 |
| EP-14 | Observability & Monitoring | Sprint 8 | 32 |
| EP-15 | Backup & Disaster Recovery | Sprint 8 | 33 |
| EP-16 | Localization & Accessibility | Sprint 9 | 34–35 |
| EP-17 | Onboarding & UX Resilience | Sprint 9 | 36–37 |
| EP-18 | Content Authoring Tools | Sprint 10 | 38–41 |
| EP-19 | LMS Integration | Sprint 11 | 42–45 |
| EP-20 | Mobile & Cross-Platform | Sprint 12 | 46–49 |
| EP-21 | Launch & Operations | Sprint 13 | 50–53 |

Each epic header states its **persona-driven goal**, e.g.:

> **EP-02 Interactive Chemistry Content** — *As a student, I can explore all 118
> elements with rich, scientifically accurate 3D models so that chemistry concepts
> become tangible and memorable.*

---

## 4. User Stories (US-001 … US-0xx)

Format per story:

```markdown
### US-0xx: <short capability>
**As a** <persona> **I want** <capability> **so that** <benefit>.
- **Epic:** EP-0x
- **Codons:** 14, 15
- **Acceptance criteria:**
  - <concrete, testable criterion 1>
  - <concrete, testable criterion 2>
- **Status:** ✅ built & tested · 🚧 built · 📋 planned
- **Test:** `e2e/epics/<epic-file>.spec.ts` → `test("US-0xx …")`
```

### Status conventions

- **✅ built & tested** — feature is live on `hubs.chemie-lernen.org` and covered by an
  automated test that passes.
- **🚧 built** — feature exists on the live platform but no automated test covers it yet
  (manual check recorded in the story).
- **📋 planned** — roadmap only; no implementation yet. Reported as *skipped* by tests.

### Draft story breakdown — expanded to ~180+ stories (finalized in `docs/user-stories.md`)

- **EP-01** (US-001–US-010): open platform, token issuance, token-based room entry,
  expired/invalid token rejection, dialog RS512 verification, rate limiting, role
  claim enforcement, guest denial.
- **EP-02** (US-011–US-019): browse rooms, create room, element-linked room lookup via API,
  Spoke classroom dashboard, shareable room links, room content loading.
- **EP-03** (US-020–US-027): periodic table with 118 elements, element lookup by symbol,
  detail panels (mass, electron config, discovery, uses, hazards), chemically correct data.
- **EP-04** (US-028–US-035): 3D Bohr models, electron shells, shell filling animation,
  Bohr vs quantum-cloud toggle, periodic trends heatmaps, trend legends.
- **EP-05** (US-036–US-043): reaction sandbox, drag-to-react interactions, balanced
  equations, energy diagrams, 3D molecular products, reaction coverage.
- **EP-06** (US-044–US-051): teacher broadcast, self-broadcast filtering, late-joiner
  state, shared annotations, hand-raise queue, smooth transitions, debouncing.
- **EP-07** (US-052–US-058): symbol↔name quiz, atomic-number quiz, group quiz, score
  saving, 10-question quiz runs.
- **EP-08** (US-059–US-066): per-student exploration tracking, time-per-element, quiz
  history, teacher dashboard, heatmap, score distribution, attendance timeline.
- **EP-09** (US-067–US-073): worksheet creation, checkpoints, student progression,
  completion status for teacher.
- **EP-10** (US-074–US-080): Quest baseline/fps budget, LOD, texture compression,
  instancing, culling, 72fps target.
- **EP-11** (US-081–US-087): hand tracking, pinch select, palm menu, teleport,
  comfort modes, wrist menu.
- **EP-12** (US-088–US-094): 50 concurrent users <200ms, pooling, DB optimization,
  dialog scaling, CDN, compression.
- **EP-13** (US-095–US-102): JWT expiry/rotation, CSP, SQLi audit, CORS, OWASP checklist.
- **EP-14** (US-103–US-110): JSON logging, Prometheus metrics, health endpoints,
  Grafana dashboards, alerting.
- **EP-15** (US-111–US-117): daily backups, WAL archiving, restore docs, RTO <1h, DR test.
- **EP-16** (US-118–US-125): German localization, keyboard navigation, screen readers,
  contrast, accessible periodic table.
- **EP-17** (US-126–US-132): first-run onboarding, join guidance, reconnect/resilience,
  graceful degradation.
- **EP-18** (US-133–US-141): scene templates, experiment builder, custom data import,
  lesson plan management.
- **EP-19** (US-142–US-149): SSO, grade passback, roster sync, SCORM/xAPI export.
- **EP-20** (US-150–US-157): responsive web, tablet interface, mobile VR, offline mode.
- **EP-21** (US-158–US-165): deploy automation, docs/training, load testing, go-live runbook.

Exact counts finalized while writing `docs/user-stories.md`.

---

## 5. Tests — built & running features only

### Target

- Base URL: `https://hubs.chemie-lernen.org` (live, TLS).
- Playwright infra already exists in `e2e/` (`@playwright/test`, chromium project).
- Existing specs (`auth-flow.spec.ts`, `dialog-auth.spec.ts`, `pse-integration.spec.ts`)
  are pointed at `localhost:9090`; they are **left untouched** (they target a local
  stack), new suites target the live domain.

### New suites (one file per tested epic)

```
e2e/epics/
  ep-01-auth-rooms.spec.ts
  ep-02-chemistry-content.spec.ts
```

- Each test is named with its story id: `test("US-011 element lookup by symbol")`.
- A shared fixture maps `US-0xx` → `{ epic, status }` so untested/planned stories are
  reported as **skipped** (with annotation), never failing.
- Web-first assertions on real HTTP responses and page content (title `App`,
  `/rooms`, `/classroom` reachable, element endpoint JSON shape, etc.).

### Livelihood verification (already done)

| Check | Result |
|---|---|
| `GET /` | 200, `<title>App</title>` |
| `GET /api/v1/hubs/element/fe` | 200 |
| `GET /rooms` | 200 |
| `GET /classroom` | 200 |

Additional live checks will confirm exact element payload schema and room-list content
during implementation; any "built" feature not reachable publicly is marked 🚧 and its
test recorded as skipped with a note.

### Running

```bash
cd e2e && npx playwright test --config playwright.live.config.ts
```

A dedicated `playwright.live.config.ts` (baseURL = live domain) keeps the existing local
config untouched. No `docker compose` boot is required — platform is already live.

---

## 6. Deliverables

1. `docs/user-stories.md` — epics + all stories + traceability matrix
   (epic ↔ story ↔ codon ↔ status ↔ test).
2. `e2e/playwright.live.config.ts` — live-domain Playwright config.
3. `e2e/epics/ep-01-auth-rooms.spec.ts` — tests for built EP-01 features.
4. `e2e/epics/ep-02-chemistry-content.spec.ts` — tests for built EP-02 features.
5. README section: how to read, run, and extend stories + tests; status legend.
6. Optionally: `docs/user-stories.md` traceability matrix auto-checked by a tiny
   script (`scripts/check-story-tests.py`) that greps spec files for `US-0xx`
   references and flags stories marked `✅` without a test (and vice versa).

---

## 7. Error Handling & CI behaviour

- Planned stories (`📋`) → **skip**, never fail the suite.
- Built-but-unreachable (`🚧`) → **skip** + warning line; documented in traceability
  matrix as "manual/not covered".
- Live endpoint down entirely → fail fast with a clear "platform unreachable" message
  (not a scary stack trace) so operators know the *platform*, not the tests, is the issue.

---

## 8. Out of Scope (now)

- Writing tests for unbuilt roadmap features (EP-03+ codons).
- Booting/deriving the compose stack on this host for tests (platform is already live
  under the domain; a local-stack config already exists if needed later).
- Modifying existing `auth-flow.spec.ts` / `dialog-auth.spec.ts` / `pse-integration.spec.ts`.
- Any product code changes.

---

## 9. Open Questions for User — RESOLVED (2026-08-26)

1. Story numbering: **flat `US-0xx` numbering** used (US-001…US-165).
2. EP-01 auth endpoints: verified live — element endpoint returns JSON at
   `GET /api/v1/hubs/element/:symbol`; `POST /api/v1/rooms/token` returns 404 on the
   public domain, so EP-01 token stories stay 🚧 built (not ✅). Future work: expose
   auth endpoints publicly to enable tests.
3. Spec file layout: **two files per epic group** used (`e2e/epics/ep-01-auth-rooms.spec.ts`,
   `e2e/epics/ep-02-chemistry-content.spec.ts`), cleaner than one giant file while
   remaining per-epic. New epics add one file each under `e2e/epics/`.

### Live findings during implementation (recorded in docs/user-stories.md)

- **US-008 / rate limiting:** live and aggressive — `/api/*` bursts flicker
  200/403("Forbidden")/000, threshold varies (~2–10 req), recovers within seconds.
  Tests use bounded retry with backoff.
- **US-093 / compression:** NOT active — API returns `content-length: 85`
  uncompressed; explicit `Accept-Encoding: gzip, br` → HTTP 403.
- **US-097 / CSP:** present on `/api/*` responses; missing on the static root shell.
- **US-099 / CORS:** `access-control-allow-origin: *` (permissive) — review pending.
- **Health:** root `/`, `/rooms`, `/classroom` served by Python `SimpleHTTP/0.6` static
  server (title `App`); Let's Encrypt TLS valid until 2026-11-16.
