# User Epics & User Stories — hubs-compose

**Created:** 2026-08-26
**Covers:** Full roadmap (Sprints 1–13, codons 00–53)
**Runtime:** `https://hubs.chemie-lernen.org`
**Design doc:** `docs/superpowers/specs/2026-08-26-user-epics-stories-tests-design.md`

This document translates the hubs-compose roadmap into user-centric **epics** and
**user stories**. Every roadmap codon maps to at least one story. Stories whose features
are already built and live on the production endpoint carry automated tests; everything
still on the roadmap is marked **planned** and reported as skipped by the test suites.

---

## Personas

| Persona | Description |
|---|---|
| **Teacher** | Creates and manages rooms, runs the VR classroom, guides and assesses students. |
| **Student** | Joins rooms, explores elements, interacts with the periodic table, takes quizzes, learns in VR or browser. |
| **Admin / Operator** | Deploys, monitors, secures, and backs up the platform. |
| **Developer** | Extends, debugs, and performance-tunes the platform. |

---

## Status Legend

| Status | Meaning | Test handling |
|---|---|---|
| ✅ **tested** | Feature is live on `hubs.chemie-lernen.org` and covered by an automated test that passes. | Test runs and must pass. |
| 🚧 **built** | Feature exists in the codebase/compose stack but is not (yet) covered by an automated test on the live domain. | Reported as skipped with a note; manual check recorded. |
| 🚧 **built\*** | Feature comes from **upstream Mozilla Hubs** (chat, reactions, media, moderation, accounts) or exists as tooling, but **live behavior is unverified** on this deployment. | Reported as skipped with a note until live-verified. |
| 📋 **planned** | Roadmap only — no implementation yet. | Reported as skipped. |

---

## Epic Index & Traceability Matrix

| Epic | Title | Roadmap | Codons | Stories |
|---|---|---|---|---|
| EP-01 | Access & Authentication | Sprints 1–3 | 00–13 | US-001…US-010 |
| EP-02 | Rooms & Classroom Dashboard | Sprints 1–3 (+Spoke) | 00–13 | US-011…US-019 |
| EP-03 | Chemistry Content & Periodic Table | Sprint 4 | 14 | US-020…US-027 |
| EP-04 | 3D Atomic Models & Visualization | Sprint 4 | 15, 17 | US-028…US-035 |
| EP-05 | Chemical Reactions & Simulations | Sprint 4 | 16 | US-036…US-043 |
| EP-06 | Classroom Synchronization | Sprint 5 | 18–21 | US-044…US-051 |
| EP-07 | Assessment & Quizzes | Sprint 6 | 22 | US-052…US-058 |
| EP-08 | Progress Tracking & Teacher Analytics | Sprint 6 | 23–24 | US-059…US-066 |
| EP-09 | Guided Learning & Lab Worksheets | Sprint 6 | 25 | US-067…US-073 |
| EP-10 | VR Performance Optimization | Sprint 7 | 26–27 | US-074…US-080 |
| EP-11 | VR Interaction & Comfort | Sprint 7 | 28–29 | US-081…US-087 |
| EP-12 | Scalability & Performance | Sprint 8 | 30 | US-088…US-094 |
| EP-13 | Security & Privacy | Sprint 8 | 31 | US-095…US-102 |
| EP-14 | Observability & Monitoring | Sprint 8 | 32 | US-103…US-110 |
| EP-15 | Backup & Disaster Recovery | Sprint 8 | 33 | US-111…US-117 |
| EP-16 | Localization & Accessibility | Sprint 9 | 34–35 | US-118…US-125 |
| EP-17 | Onboarding & UX Resilience | Sprint 9 | 36–37 | US-126…US-132 |
| EP-18 | Content Authoring Tools | Sprint 10 | 38–41 | US-133…US-141 |
| EP-19 | LMS Integration | Sprint 11 | 42–45 | US-142…US-149 |
| EP-20 | Mobile & Cross-Platform | Sprint 12 | 46–49 | US-150…US-157 |
| EP-21 | Launch & Operations | Sprint 13 | 50–53 | US-158…US-165 |
| EP-22 | Communication & Social Presence | (upstream Hubs) | — | US-166…US-174 |
| EP-23 | Media & Content Sharing | (upstream Hubs) | — | US-175…US-183 |
| EP-24 | Moderation & Safety | (upstream Hubs) | — | US-184…US-191 |
| EP-25 | Accounts & Profiles | (upstream Hubs) | — | US-192…US-200 |
| EP-26 | In-Room Collaboration & Breakout | (new) | — | US-201…US-208 |
| EP-27 | Notifications & Scheduling | (new) | — | US-209…US-216 |
| EP-28 | Data Protection & Compliance | (new) | — | US-217…US-225 |
| EP-29 | Integration & Developer Ecosystem | (new) | — | US-226…US-233 |
| EP-30 | Quality Engineering | (new) | — | US-234…US-241 |

---

## EP-01 — Access & Authentication

> **Goal:** *As a student or teacher, I can reach the platform securely and enter my
> room without friction, knowing only authorized people can get in.*

### US-001: Open the platform
**As a** student **I want** to open the platform at `hubs.chemie-lernen.org` **so that** I can start a lesson from anywhere.
- **Epic:** EP-01 · **Codons:** 00 · **Status:** ✅ tested
- **Acceptance criteria:**
  - `GET /` returns HTTP 200 with an HTML app shell.
  - Page title is served (currently `App`).
- **Test:** `e2e/epics/ep-01-auth-rooms.spec.ts` → `US-001`

### US-002: Terms/renderer reachable
**As a** student **I want** the client assets to load **so that** the 3D room renders instead of an error page.
- **Epic:** EP-01 · **Codons:** 00 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Referenced JS/CSS assets return 200.
  - No 404s in the boot console.
- **Test:** none yet (manual check recorded)

### US-003: Teacher obtains a signed room access token
**As a** teacher **I want** to request a JWT-signed room `access_token` **so that** I can hand students a controlled entry credential.
- **Epic:** EP-01 · **Codons:** 07–09 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Token endpoint issues a signed JWT containing room + role claims.
  - Token carries an expiry and a role (`student` | `teacher`).
- **Test:** none (endpoint not verified live/public — 404 at `/api/v1/rooms/token` on 2026-08-26)

### US-004: Student enters room with access token
**As a** student **I want** to enter a room using my access token **so that** I land inside the 3D classroom.
- **Epic:** EP-01 · **Codons:** 07–09 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Providing a valid token admits the student to the room.
  - The room honors the token's role claim on entry.
- **Test:** none yet

### US-005: Expired token rejected
**As a** teacher **I want** expired tokens to be refused at the room boundary **so that** old links stop granting access.
- **Epic:** EP-01 · **Codons:** 07–09 · **Status:** 🚧 built (`RoomAccessPlug`)
- **Acceptance criteria:**
  - An expired token is rejected with a clear error and no room access.
- **Test:** none yet

### US-006: Invalid token signature rejected
**As a** teacher **I want** forged or tampered tokens to be rejected **so that** only tokens signed by our service work.
- **Epic:** EP-01 · **Codons:** 07–09 · **Status:** 🚧 built (`RoomAccessPlug`)
- **Acceptance criteria:**
  - A token with an invalid signature is denied.
- **Test:** none yet

### US-007: Dialog verifies RS512 JWTs on room signaling
**As a** teacher **I want** the WebRTC signaling path to verify room JWTs (RS512) **so that** media connections are only authorized for token holders.
- **Epic:** EP-01 · **Codons:** 09–10 · **Status:** 🚧 built (dialog auth middleware)
- **Acceptance criteria:**
  - `GET`/`POST /rooms` traffic is verified against RS512-signed JWTs.
- **Test:** none yet

### US-008: Rate limiting protects auth endpoints
**As an** admin **I want** token/hub creation endpoints rate-limited **so that** attackers cannot spam credentials or exhaust resources.
- **Epic:** EP-01 · **Codons:** 10–13 · **Status:** 🚧 built (`PlugAttack`)
- **Acceptance criteria:**
  - Excess requests are rejected.
  - **Verified live (2026-08-26):** `/api/*` returns **HTTP 403 "Forbidden"** after ~10 requests per window — rate limiting is active (returns 403 rather than 429). Live test suites must stay under this budget.
- **Test:** none yet

### US-009: Role claims enforced at room entry
**As a** teacher **I want** student vs teacher roles to be enforced when someone enters **so that** only teachers get moderation powers.
- **Epic:** EP-01 · **Codons:** 07–09 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Teacher-token entry grants teacher capabilities; student-token entry does not.
- **Test:** none yet

### US-010: Guest without token denied from protected rooms
**As a** teacher **I want** guests without a token to be blocked from protected rooms **so that** my classroom is private.
- **Epic:** EP-01 · **Codons:** 07–09 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Navigating to a protected room without credentials yields a denial/error, not entry.
- **Test:** none yet

---

## EP-02 — Rooms & Classroom Dashboard

> **Goal:** *As a teacher, I can create, find, and manage chemistry rooms from one
> dashboard, and as a student I can browse and join them easily.*

### US-011: Browse rooms
**As a** student **I want** to browse available rooms **so that** I can find the classroom my teacher announced.
- **Epic:** EP-02 · **Codons:** 03 · **Status:** ✅ tested
- **Acceptance criteria:**
  - `GET /rooms` returns HTTP 200 HTML serving the Hubs client shell (room listing renders client-side).
- **Test:** `e2e/epics/ep-01-auth-rooms.spec.ts` → `US-011`

### US-012: Create a room
**As a** teacher **I want** to create a new hub/room **so that** each class gets its own space.
- **Epic:** EP-02 · **Codons:** 03–06 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Creating a room succeeds and the room appears in listings.
- **Test:** none yet

### US-013: Look up an element-linked room via API
**As a** student **I want** to fetch the room for a chemical element by symbol **so that** I can jump straight to element-specific content.
- **Epic:** EP-02 · **Codons:** 00–06 · **Status:** ✅ tested
- **Acceptance criteria:**
  - `GET /api/v1/hubs/element/fe` (and other symbols) returns HTTP 200 JSON.
  - Body is valid JSON containing `hubs` and `pagination` keys.
- **Test:** `e2e/epics/ep-02-chemistry-content.spec.ts` → `US-013`

### US-014: Open the Spoke classroom dashboard
**As a** teacher **I want** a dashboard at `/classroom` listing chemistry rooms **so that** I can manage them without touching the terminal.
- **Epic:** EP-02 · **Codons:** 06–13 · **Status:** ✅ tested
- **Acceptance criteria:**
  - `GET /classroom` returns HTTP 200 and serves the Spoke dashboard shell.
- **Test:** `e2e/epics/ep-02-chemistry-content.spec.ts` → `US-014`

### US-015: Shareable room link
**As a** teacher **I want** a shareable link for each room **so that** students can join with one click.
- **Epic:** EP-02 · **Codons:** 03 · **Status:** 🚧 built
- **Acceptance criteria:**
  - The room link resolves to the room entry flow.
- **Test:** none yet

### US-016: Room entry lands in 3D client
**As a** student **I want** clicking a room link to load the Hubs client **so that** I enter the 3D classroom.
- **Epic:** EP-02 · **Codons:** 03–06 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Room URL serves the client shell (HTTP 200, `App` title) rather than an error.
- **Test:** none yet (requires a real room id)

### US-017: Dashboard lists element rooms
**As a** teacher **I want** the dashboard to enumerate rooms linked to the 118 elements **so that** I can spot which elements have ready classrooms.
- **Epic:** EP-02 · **Codons:** 06–13 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Dashboard renders a list of element rooms.
- **Test:** none yet

### US-018: LiveTiles/room state visible
**As a** teacher **I want** each room to show name and presence state **so that** I can see who is where.
- **Epic:** EP-02 · **Codons:** 03–06 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Room cards show name and member counts.
- **Test:** none yet

### US-019: Rooms listing consistent over HTTPS
**As a** student **I want** rooms to enumerate over TLS **so that** I browse safely from any network.
- **Epic:** EP-02 · **Codons:** 03 · **Status:** ✅ tested
- **Acceptance criteria:**
  - `/rooms` responds 200 over `https://` with a valid certificate.
- **Test:** `e2e/epics/ep-01-auth-rooms.spec.ts` → `US-019`

---

## EP-03 — Chemistry Content & Periodic Table

> **Goal:** *As a student, I can explore all 118 elements with rich, correct data so
> that chemistry becomes tangible.*

### US-020: Periodic table shows all 118 elements
**As a** student **I want** a periodic table showing H→Og **so that** I can navigate the whole element set.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** 📋 planned
- **Acceptance criteria:**
  - The table renders 118 element tiles with correct symbols.
- **Test:** skipped (planned)

### US-021: Element lookup by symbol returns data
**As a** student **I want** to query element data by symbol via the API **so that** apps can render correct chemistry.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** ✅ tested
- **Acceptance criteria:**
  - `GET /api/v1/hubs/element/fe` returns 200 JSON with a valid payload (`hubs` + `pagination` keys).
- **Test:** `e2e/epics/ep-02-chemistry-content.spec.ts` → `US-021`

### US-022: Element detail panel
**As a** student **I want** a detail panel per element with atomic mass, electron configuration, discovery year, and uses **so that** I can study each element deeply.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Clicking an element shows full metadata in a 3D panel.
- **Test:** skipped (planned)

### US-023: Hazard information available
**As a** student **I want** hazard info for elements **so that** I learn safety alongside chemistry.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Detail panel includes hazard/safety data where known.
- **Test:** skipped (planned)

### US-024: Data is scientifically correct
**As a** teacher **I want** element data to be accurate **so that** my students learn correct chemistry.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** 🚧 built (backend serves data; correctness audit pending)
- **Acceptance criteria:**
  - Spot-checked facts (atomic number, symbol, group) match reference data.
- **Test:** none yet

### US-025: Search/filter elements
**As a** student **I want** to search the periodic table by name or symbol **so that** I can find elements quickly.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Searching "Fe" or "iron" highlights/matches the element.
- **Test:** skipped (planned)

### US-026: Periodic table loads in browser
**As a** student **I want** the periodic table to load in a normal browser tab **so that** I don't need VR hardware to learn.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** 📋 planned
- **Acceptance criteria:**
  - PSE loads without WebXR and is interactable.
- **Test:** skipped (planned)

### US-027: API returns element for every symbol
**As a** developer **I want** the element endpoint to answer for any of the 118 symbols **so that** clients never hit a gap.
- **Epic:** EP-03 · **Codons:** 14 · **Status:** ✅ tested
- **Acceptance criteria:**
  - Spot-checked symbols (e.g. H, fe, Na, Og) all return 200 JSON.
- **Test:** `e2e/epics/ep-02-chemistry-content.spec.ts` → `US-027`

---

## EP-04 — 3D Atomic Models & Visualization

> **Goal:** *As a student, I can see atoms and periodicity in 3D so that abstract
> chemistry becomes visual and memorable.*

### US-028: 3D Bohr model for every element
**As a** student **I want** an interactive 3D Bohr model per element **so that** I can see nucleus + electron shells.
- **Epic:** EP-04 · **Codons:** 15 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Each element renders a Bohr model with correct shell counts.
- **Test:** skipped (planned)

### US-029: Electrons orbit at correct energy levels
**As a** student **I want** electrons to orbit on correct energy levels **so that** the model teaches electron configuration.
- **Epic:** EP-04 · **Codons:** 15 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Electron count per shell matches the element's configuration.
- **Test:** skipped (planned)

### US-030: Shell filling animation (Aufbau)
**As a** student **I want** a shell-filling animation **so that** I understand the Aufbau principle.
- **Epic:** EP-04 · **Codons:** 15 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Animation fills shells in Aufbau order.
- **Test:** skipped (planned)

### US-031: Bohr ↔ quantum cloud toggle
**As a** student **I want** to toggle between Bohr model and quantum cloud representation **so that** I see both mental models.
- **Epic:** EP-04 · **Codons:** 15 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Toggle switches between the two visualizations.
- **Test:** skipped (planned)

### US-032: Periodic trends heatmap
**As a** student **I want** trend overlays (electronegativity, atomic radius, ionization energy, electron affinity) **so that** I see periodic patterns.
- **Epic:** EP-04 · **Codons:** 17 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Selecting a trend colors the table with a low→high gradient.
- **Test:** skipped (planned)

### US-033: Trend legend and scale
**As a** student **I want** a color legend with scale values **so that** I can read the heatmap correctly.
- **Epic:** EP-04 · **Codons:** 17 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Legend shows min/max and gradient mapping.
- **Test:** skipped (planned)

### US-034: Animated trend transition
**As a** student **I want** smooth animated transitions when switching trends **so that** comparisons are intuitive.
- **Epic:** EP-04 · **Codons:** 17 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Switching modes animates rather than snapping.
- **Test:** skipped (planned)

### US-035: Trends correct per element
**As a** teacher **I want** trend values to be scientifically accurate **so that** visualizations support the curriculum.
- **Epic:** EP-04 · **Codons:** 17 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Spot-checked trend values match reference data (e.g. F highest electronegativity).
- **Test:** skipped (planned)

---

## EP-05 — Chemical Reactions & Simulations

> **Goal:** *As a student, I can combine elements and watch reactions so that
> stoichiometry becomes experiential.*

### US-036: Reaction sandbox
**As a** student **I want** a sandbox where I drag elements together **so that** I can test what reacts.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Dragging Na onto Cl triggers a NaCl reaction.
- **Test:** skipped (planned)

### US-037: Na + Cl₂ → NaCl simulation
**As a** student **I want** the flagship salt reaction to animate **so that** I see electron transfer.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Reaction animation plays with a balanced-equation overlay.
- **Test:** skipped (planned)

### US-038: H₂ + O₂ → H₂O simulation
**As a** student **I want** the water formation reaction **so that** I understand combustion synthesis.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Reaction plays with balanced equations 2H₂ + O₂ → 2H₂O.
- **Test:** skipped (planned)

### US-039: 2Na + 2H₂O → 2NaOH + H₂ simulation
**As a** student **I want** the alkali-metal/water reaction **so that** I see a dramatic real reaction safely.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Reaction plays with correct balanced equation and products.
- **Test:** skipped (planned)

### US-040: Balanced equation overlay
**As a** student **I want** a balanced equation shown during reactions **so that** I connect observation to notation.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Correct balanced equation is displayed for each reaction.
- **Test:** skipped (planned)

### US-041: Energy diagram
**As a** student **I want** an energy diagram for each reaction **so that** I learn exo/endothermic concepts.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Energy diagram shows reactants/products and ΔH direction.
- **Test:** skipped (planned)

### US-042: 3D molecular product view
**As a** student **I want** the product shown as a 3D molecule **so that** I can inspect geometry.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Product renders as interactive 3D molecule.
- **Test:** skipped (planned)

### US-043: Reaction library covers curriculum
**As a** teacher **I want** the included reactions to cover common educational cases **so that** I can plan lessons around them.
- **Epic:** EP-05 · **Codons:** 16 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Documented reaction list matches curriculum scope.
- **Test:** skipped (planned)

---

## EP-06 — Classroom Synchronization

> **Goal:** *As a teacher, I can steer the whole class through one shared experience,
> and as a student I am always in sync with the lesson.*

### US-044: Teacher navigation broadcast
**As a** teacher **I want** my element navigation to broadcast to all students **so that** everyone follows the lesson.
- **Epic:** EP-06 · **Codons:** 18 · **Status:** 🚧 built (client in hello-webxr; channel backend in reticulum)
- **Acceptance criteria:**
  - Teacher navigates to an element → all students see it.
- **Test:** none yet

### US-045: Self-broadcast filtered
**As a** teacher **I want** my own navigation not to echo back to me **so that** there is no feedback loop.
- **Epic:** EP-06 · **Codons:** 18 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Broadcast is filtered by session/connection id.
- **Test:** none yet

### US-046: Late joiners get current state
**As a** student **I want** to see the current element when I join late **so that** I'm never lost.
- **Epic:** EP-06 · **Codons:** 18 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Late-joining student receives the current element from state.
- **Test:** none yet

### US-047: Teacher creates shared annotation
**As a** teacher **I want** to annotate elements and have students see annotations instantly **so that** I can point out details.
- **Epic:** EP-06 · **Codons:** 19 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Annotation on Fe → all students see immediately.
- **Test:** none yet

### US-048: Annotations removed/shared sync
**As a** teacher **I want** to remove annotations and see the removal everywhere **so that** stale notes don't linger.
- **Epic:** EP-06 · **Codons:** 19 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Removed annotation disappears for all participants.
- **Test:** none yet

### US-049: Student hand-raise queue
**As a** student **I want** to raise my hand from browser or VR **so that** I can ask questions.
- **Epic:** EP-06 · **Codons:** 20 · **Status:** 🚧 built (backend `events:raise_hand` exists)
- **Acceptance criteria:**
  - PSE browser student raising hand appears in teacher's queue.
- **Test:** none yet

### US-050: Smooth element transitions
**As a** student **I want** smooth camera transitions between elements **so that** the lesson flows.
- **Epic:** EP-06 · **Codons:** 21 · **Status:** 🚧 built (~80%)
- **Acceptance criteria:**
  - Teacher navigates H→Fe→Na: students see smooth transitions.
- **Test:** none yet

### US-051: Debounced/rapid navigation
**As a** student **I want** rapid teacher jumps (debounced) **so that** the client doesn't stutter.
- **Epic:** EP-06 · **Codons:** 21 · **Status:** 🚧 built (~80%)
- **Acceptance criteria:**
  - Rapid transitions are throttled without losing the final state.
- **Test:** none yet

---

## EP-07 — Assessment & Quizzes

> **Goal:** *As a student, I can test my knowledge in-VR and get feedback, and as a
> teacher I can see results.*

### US-052: Symbol↔name quiz
**As a** student **I want** "match this symbol to its name" questions **so that** I memorize symbols.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Quiz presents symbol↔name questions with feedback.
- **Test:** skipped (planned)

### US-053: Atomic-number quiz
**As a** student **I want** "which element has atomic number 11?" questions **so that** I learn ordering.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Questions generated from correct element data.
- **Test:** skipped (planned)

### US-054: Group quiz
**As a** student **I want** "what group does Neon belong to?" questions **so that** I learn the groups.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Group questions are answerable and scored.
- **Test:** skipped (planned)

### US-055: Quiz results persisted
**As a** student **I want** my quiz score saved **so that** I can track improvement.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Completed quiz posts results to the backend.
- **Test:** skipped (planned)

### US-056: 10-question quiz runs
**As a** teacher **I want** standard 10-question quiz runs **so that** a full session is meaningful.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Student completes 10-question quiz; score saved to profile.
- **Test:** skipped (planned)

### US-057: Quiz feedback
**As a** student **I want** immediate right/wrong feedback **so that** I learn during the quiz.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Each answer gets immediate feedback and correct answer shown.
- **Test:** skipped (planned)

### US-058: Quiz available in browser and VR
**As a** student **I want** quizzes in both VR and browser **so that** I can learn on any device.
- **Epic:** EP-07 · **Codons:** 22 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Quiz works in flat browser and VR.
- **Test:** skipped (planned)

---

## EP-08 — Progress Tracking & Teacher Analytics

> **Goal:** *As a teacher, I can see exactly how my class is doing so that I can adapt
> my teaching.*

### US-059: Per-student element exploration tracked
**As a** teacher **I want** to know which elements each student explored **so that** I can see engagement.
- **Epic:** EP-08 · **Codons:** 23 · **Status:** 📋 planned
- **Acceptance criteria:**
  - API returns explored elements per student.
- **Test:** skipped (planned)

### US-060: Time-per-element tracked
**As a** teacher **I want** time spent per element **so that** I can spot where students linger or quit.
- **Epic:** EP-08 · **Codons:** 23 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Per-element session times are recorded and queryable.
- **Test:** skipped (planned)

### US-061: Quiz history per student
**As a** teacher **I want** quiz completions and scores per student **so that** I can assess mastery.
- **Epic:** EP-08 · **Codons:** 23 · **Status:** 📋 planned
- **Acceptance criteria:**
  - API returns quiz history with scores.
- **Test:** skipped (planned)

### US-062: Summary view "45/118 elements, 78%"
**As a** teacher **I want** a compact per-student summary **so that** I can report quickly.
- **Epic:** EP-08 · **Codons:** 23 · **Status:** 📋 planned
- **Acceptance criteria:**
  - API returns "explored 45/118, average quiz score 78%".
- **Test:** skipped (planned)

### US-063: Class engagement heatmap
**As a** teacher **I want** a live heatmap of element exploration across the class **so that** I see what engages everyone.
- **Epic:** EP-08 · **Codons:** 24 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Dashboard shows which elements the class explored most.
- **Test:** skipped (planned)

### US-064: Quiz score distribution
**As a** teacher **I want** a bar chart of quiz scores for the class **so that** I see performance spread.
- **Epic:** EP-08 · **Codons:** 24 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Dashboard renders score distribution and updates live.
- **Test:** skipped (planned)

### US-065: Attendance timeline
**As a** teacher **I want** an attendance timeline **so that** I know who was present.
- **Epic:** EP-08 · **Codons:** 24 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Timeline shows presence by student over the session.
- **Test:** skipped (planned)

### US-066: Analytics load fast
**As a** teacher **I want** the analytics dashboard to render promptly **so that** I can use it live during class.
- **Epic:** EP-08 · **Codons:** 24 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Dashboard data loads under a defined budget.
- **Test:** skipped (planned)

---

## EP-09 — Guided Learning & Lab Worksheets

> **Goal:** *As a teacher, I can structure a lesson as guided checkpoints, and as a
> student I work through them with visible progress.*

### US-067: Create a worksheet
**As a** teacher **I want** to create structured lab worksheets **so that** lessons are repeatable.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Worksheet with checkpoints can be created.
- **Test:** skipped (planned)

### US-068: Define checkpoints
**As a** teacher **I want** to define checkpoints ("explore alkali metals", "complete reaction quiz", "write observations") **so that** learning is sequenced.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - A worksheet supports ordered checkpoints.
- **Test:** skipped (planned)

### US-069: Student progresses through checkpoints
**As a** student **I want** to work through checkpoints step by step **so that** I stay on track.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Student completes checkpoint 2 of 5 → state updates.
- **Test:** skipped (planned)

### US-070: Teacher sees completion status
**As a** teacher **I want** per-student checkpoint completion **so that** I can intervene early.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Teacher sees 40% progress for a student at 2/5 checkpoints.
- **Test:** skipped (planned)

### US-071: Worksheet attachments
**As a** teacher **I want** to attach observations/links to checkpoints **so that** students have resources.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Checkpoint can carry text or media.
- **Test:** skipped (planned)

### US-072: Student observations recorded
**As a** student **I want** to enter my observations into the worksheet **so that** my work is saved.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Observation text persists and is visible to teacher.
- **Test:** skipped (planned)

### US-073: Worksheet sharing across classes
**As a** teacher **I want** to reuse a worksheet across classes **so that** I don't rebuild lessons.
- **Epic:** EP-09 · **Codons:** 25 · **Status:** 📋 planned
- **Acceptance criteria:**
  - A worksheet can be assigned to multiple classes with independent progress.
- **Test:** skipped (planned)

---

## EP-10 — VR Performance Optimization

> **Goal:** *As a student on Quest 3, I get smooth 72fps VR so that lessons don't cause
> nausea or lag.*

### US-074: Baseline performance profiling
**As a** developer **I want** a Quest 3 baseline profile (fps, GPU/CPU, memory) **so that** I can measure improvements.
- **Epic:** EP-10 · **Codons:** 26 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Report documents current fps and top 3 bottlenecks.
- **Test:** skipped (planned)

### US-075: Establish performance budget
**As a** developer **I want** a documented performance budget **so that** regressions are caught.
- **Epic:** EP-10 · **Codons:** 26 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Budget defines draw calls, triangles, textures per frame.
- **Test:** skipped (planned)

### US-076: LOD for element models
**As a** student **I want** models to use level-of-detail **so that** distant elements stay cheap.
- **Epic:** EP-10 · **Codons:** 27 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Distant models render simplified geometry.
- **Test:** skipped (planned)

### US-077: Texture compression (Basis Universal)
**As a** student **I want** compressed textures **so that** memory stays within Quest limits.
- **Epic:** EP-10 · **Codons:** 27 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Textures use compressed formats on supported devices.
- **Test:** skipped (planned)

### US-078: Instanced periodic table grid
**As a** student **I want** the 118-element grid rendered with instancing **so that** it stays fast with all elements visible.
- **Epic:** EP-10 · **Codons:** 27 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Grid uses instanced rendering; no per-tile overhead.
- **Test:** skipped (planned)

### US-079: Frustum culling
**As a** student **I want** off-screen elements culled **so that** only visible content is drawn.
- **Epic:** EP-10 · **Codons:** 27 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Invisible elements are not rendered.
- **Test:** skipped (planned)

### US-080: Stable 72fps on Quest 3
**As a** student **I want** stable 72fps during PSE use **so that** VR is comfortable.
- **Epic:** EP-10 · **Codons:** 27 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Measured fps holds 72 with all 118 elements visible.
- **Test:** skipped (planned; hardware-dependent, manual verification)

---

## EP-11 — VR Interaction & Comfort

> **Goal:** *As a student in VR, I can control the experience naturally and comfortably
> with or without controllers.*

### US-081: Hand-tracking selection
**As a** student **I want** to select elements with hand tracking (pinch) **so that** controllers aren't required.
- **Epic:** EP-11 · **Codons:** 28 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Pinch gesture selects an element.
- **Test:** skipped (planned; hardware-dependent)

### US-082: Point-to-navigate
**As a** student **I want** to navigate by pointing **so that** interaction feels natural.
- **Epic:** EP-11 · **Codons:** 28 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Point gesture triggers navigation.
- **Test:** skipped (planned; hardware-dependent)

### US-083: Palm menu
**As a** student **I want** a menu to open with my palm **so that** tools are accessible hands-free.
- **Epic:** EP-11 · **Codons:** 28 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Presenting palm opens the menu.
- **Test:** skipped (planned; hardware-dependent)

### US-084: Raycasting from hands
**As a** student **I want** hand-optimized raycasting **so that** hitting small element tiles is reliable.
- **Epic:** EP-11 · **Codons:** 28 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Raycast accuracy with hand poses meets a usability threshold.
- **Test:** skipped (planned; hardware-dependent)

### US-085: Teleport between element groups
**As a** student **I want** to teleport e.g. alkali metals → noble gases **so that** I move across the table quickly.
- **Epic:** EP-11 · **Codons:** 29 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Teleport destination is reachable and stable.
- **Test:** skipped (planned)

### US-086: Comfort mode (snap turn + vignette)
**As a** student **I want** snap turn and vignette options **so that** I don't get motion sick.
- **Epic:** EP-11 · **Codons:** 29 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Comfort toggles change turning behavior.
- **Test:** skipped (planned)

### US-087: Wrist-mounted quick menu
**As a** student **I want** a wrist-mounted quick-access menu **so that** frequent actions are one gesture away.
- **Epic:** EP-11 · **Codons:** 29 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Wrist menu opens and actions work.
- **Test:** skipped (planned)

---

## EP-12 — Scalability & Performance

> **Goal:** *As an admin, the platform stays fast as classrooms grow so that a full
> school can use it simultaneously.*

### US-088: 50 concurrent users under 200ms
**As an** admin **I want** 50 concurrent users in a room at <200ms average latency **so that** classes run smoothly.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Load test with 50 users passes latency budget.
- **Test:** skipped (planned; load test = `e2e/load-test.js` exists as a basis)

### US-089: Connection pooling
**As an** admin **I want** Reticulum to pool DB connections **so that** many users don't exhaust Postgres.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Connection count stays bounded under load.
- **Test:** skipped (planned)

### US-090: Optimized DB queries
**As an** admin **I want** slow queries eliminated **so that** room APIs respond fast.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Query plan review shows no missing-index scans.
- **Test:** skipped (planned)

### US-091: Dialog horizontal scaling
**As an** admin **I want** Dialog (SFU) to scale horizontally **so that** media capacity grows with users.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Multiple Dialog instances share load.
- **Test:** skipped (planned)

### US-092: CDN for static assets
**As a** student **I want** static assets served from a CDN **so that** rooms load fast.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Hubs-client and PSE assets served from cache layer.
- **Test:** skipped (planned)

### US-093: gzip/brotli compression
**As a** student **I want** compressed transfers **so that** page loads are small.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Text responses are gzip/brotli compressed.
  - **Note (2026-08-26):** compression not active on live domain — element API returns `content-length: 85` uncompressed; explicit `Accept-Encoding: gzip, br` yields HTTP 403.
- **Test:** none (fails until compression lands)

### US-094: Load-test reporting
**As an** admin **I want** load-test results reported **so that** capacity decisions are evidence-based.
- **Epic:** EP-12 · **Codons:** 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - `e2e/load-test.js` results are captured and archived.
- **Test:** skipped (planned)

---

## EP-13 — Security & Privacy

> **Goal:** *As an admin, the platform is hardened so that student data and classroom
> access stay safe.*

### US-095: JWT expiry enforced
**As an** admin **I want** expired JWTs rejected everywhere **so that** stale credentials die.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** 🚧 built
- **Acceptance criteria:**
  - No endpoint accepts an expired token.
- **Test:** none yet

### US-096: Refresh token rotation
**As a** teacher **I want** refresh tokens rotated **so that** theft of an old token is useless.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Refresh consumes and replaces the token.
- **Test:** skipped (planned)

### US-097: CSP headers present
**As an** admin **I want** Content-Security-Policy headers **so that** XSS blast radius is limited.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** ✅ tested (API responses)
- **Acceptance criteria:**
  - API responses carry a `content-security-policy` header.
  - **Note:** present on `/api/*` responses; the static app shell (root `/`) lacks it (Python static server).
- **Test:** `e2e/epics/ep-02-chemistry-content.spec.ts` → `US-097`

### US-098: SQL injection audit clean
**As an** admin **I want** the API audited for SQL injection **so that** data can't be exfiltrated.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Audit report shows no injectable queries.
- **Test:** skipped (planned)

### US-099: CORS policy reviewed
**As an** admin **I want** a reviewed/restrictive CORS policy **so that** only our origins can call APIs.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** 🚧 built
- **Acceptance criteria:**
  - CORS headers present on API responses; `access-control-allow-origin` currently `*` (permissive) — **restriction review pending, not yet restrictive**.
- **Test:** none (open restriction noted; revisit after review)

### US-100: OWASP Top 10 checklist
**As an** admin **I want** an OWASP Top 10 verification **so that** common risks are covered.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Checklist scanned against checklist with findings remediated.
- **Test:** skipped (planned)

### US-101: TLS everywhere
**As a** student **I want** all traffic over TLS **so that** my session isn't sniffable.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** ✅ tested
- **Acceptance criteria:**
  - Platform serves valid TLS with no mixed-content failures.
- **Test:** `e2e/epics/ep-02-chemistry-content.spec.ts` → `US-101`

### US-102: Privacy of student data
**As a** teacher **I want** student progress data to be private **so that** only authorized people see it.
- **Epic:** EP-13 · **Codons:** 31 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Progress APIs require authorization.
- **Test:** skipped (planned)

---

## EP-14 — Observability & Monitoring

> **Goal:** *As an operator, I can see health, metrics, and alerts so that issues are
> caught before users notice.*

### US-103: Structured JSON logging
**As an** operator **I want** JSON logs across services **so that** I can search and correlate.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Logs are parseable JSON with consistent fields.
- **Test:** none yet

### US-104: Prometheus metrics endpoint
**As an** operator **I want** `/metrics` on Reticulum **so that** Prometheus can scrape.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Scrape returns request latency, room count, active users.
- **Test:** none yet (not on public domain)

### US-105: Health check endpoints
**As an** operator **I want** health endpoints per service **so that** orchestrators can restart dead ones.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 🚧 built (compose healthchecks)
- **Acceptance criteria:**
  - Each service reports healthy/unhealthy.
- **Test:** none yet

### US-106: Grafana dashboards
**As an** operator **I want** Grafana dashboards with real-time service metrics **so that** I can watch the platform at a glance.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Dashboard shows metrics for all services.
- **Test:** none yet (dashboard behind :3000, local)

### US-107: Alerting rules
**As an** operator **I want** alerts on high latency, service down, DB connections **so that** I get paged automatically.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Threshold breach fires an alert.
- **Test:** none yet

### US-108: Metrics for room count & active users
**As an** operator **I want** room and active-user gauges **so that** capacity planning is grounded.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 🚧 built
- **Acceptance criteria:**
  - Gauges change with real usage.
- **Test:** none yet

### US-109: Metrics endpoint reachable
**As an** operator **I want** the metrics endpoint reachable on the live domain **so that** external monitoring works.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 📋 planned (not exposed publicly yet)
- **Acceptance criteria:**
  - `/metrics` reachable over HTTPS (authenticated).
- **Test:** skipped (planned)

### US-110: Log retention policy
**As an** operator **I want** a defined log retention policy **so that** storage stays bounded.
- **Epic:** EP-14 · **Codons:** 32 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Logs are retained/rotated per policy.
- **Test:** skipped (planned)

---

## EP-15 — Backup & Disaster Recovery

> **Goal:** *As an operator, I can restore the platform quickly so that a data loss
> event doesn't cost a school term.*

### US-111: Automated daily DB backup
**As an** operator **I want** automated daily Postgres backups **so that** at most one day of data is at risk.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - A daily backup artifact is produced and verified.
- **Test:** skipped (planned)

### US-112: WAL archiving
**As an** operator **I want** WAL archiving **so that** point-in-time recovery is possible.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - WAL segments are archived continuously.
- **Test:** skipped (planned)

### US-113: Reticulum state export
**As an** operator **I want** Reticulum state exportable **so that** room metadata survives.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - State export produces a restorable artifact.
- **Test:** skipped (planned)

### US-114: Classroom data export
**As a** teacher **I want** classroom data exportable **so that** my lessons aren't lost with the server.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Progress/annotation data exports.
- **Test:** skipped (planned)

### US-115: Documented restore procedure
**As an** operator **I want** a documented, step-by-step restore procedure **so that** recovery isn't improvised.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Runbook exists and is reviewed.
- **Test:** skipped (planned)

### US-116: Recovery under 1 hour
**As an** operator **I want** full recovery in under an hour **so that** outages are short.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Simulated DB failure → recovery completes < 60 min.
- **Test:** skipped (planned; drill)

### US-117: DR test performed
**As an** operator **I want** periodic DR tests **so that** the runbook actually works.
- **Epic:** EP-15 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - DR drill executed and documented.
- **Test:** skipped (planned; drill)

---

## EP-16 — Localization & Accessibility

> **Goal:** *As a German-speaking student, and as a student with accessibility needs,
> the platform works fully for me.*

### US-118: German UI localization
**As a** German-speaking student **I want** the interface in German **so that** I learn in my language.
- **Epic:** EP-16 · **Codons:** 34 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Core UI strings are localized to German.
- **Test:** skipped (planned)

### US-119: German element/content localization
**As a** German-speaking student **I want** element and content text in German **so that** chemistry terms are native.
- **Epic:** EP-16 · **Codons:** 34 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Element names/descriptions localized.
- **Test:** skipped (planned)

### US-120: Localization extensible
**As a** developer **I want** a localization framework **so that** further languages are easy.
- **Epic:** EP-16 · **Codons:** 34 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Adding a locale is a data change only.
- **Test:** skipped (planned)

### US-121: Keyboard navigation
**As a** student **I want** full keyboard navigation **so that** I can use the platform without a mouse.
- **Epic:** EP-16 · **Codons:** 35 · **Status:** 📋 planned
- **Acceptance criteria:**
  - All interactive elements are reachable and operable by keyboard.
- **Test:** skipped (planned)

### US-122: Screen-reader support
**As a** student **I want** screen-reader-friendly landmarks and labels **so that** I can navigate blind.
- **Epic:** EP-16 · **Codons:** 35 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Key controls have accessible names; ARIA landmarks present.
- **Test:** skipped (planned)

### US-123: Sufficient color contrast
**As a** student **I want** readable contrast **so that** I can distinguish elements with low vision.
- **Epic:** EP-16 · **Codons:** 35 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Contrast ratios meet WCAG AA.
- **Test:** skipped (planned)

### US-124: Accessible periodic table
**As a** student **I want** the periodic table usable via keyboard/screen reader **so that** I can study the full table.
- **Epic:** EP-16 · **Codons:** 35 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Each tile focusable with announced name/element.
- **Test:** skipped (planned)

### US-125: WCAG AA baseline
**As an** admin **I want** a WCAG AA audit **so that** I know the accessibility status.
- **Epic:** EP-16 · **Codons:** 35 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Audit report produced with fixes for failures.
- **Test:** skipped (planned)

---

## EP-17 — Onboarding & UX Resilience

> **Goal:** *As a student, I can get started without help, and as a teacher, sessions
> survive network hiccups.*

### US-126: First-run onboarding tutorial
**As a** student **I want** a first-run tutorial **so that** I know how to move and interact.
- **Epic:** EP-17 · **Codons:** 36 · **Status:** 📋 planned
- **Acceptance criteria:**
  - New users get a guided first-run flow.
- **Test:** skipped (planned)

### US-127: Room-join guidance
**As a** student **I want** guidance when joining a room (mic, permission, enter-VR) **so that** onboarding is smooth.
- **Epic:** EP-17 · **Codons:** 36 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Join flow explains permissions and VR entry.
- **Test:** skipped (planned)

### US-128: Reconnection on network drop
**As a** student **I want** automatic reconnection when my network drops **so that** I rejoin without losing context.
- **Epic:** EP-17 · **Codons:** 37 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Client reconnects to room/channel after drop.
- **Test:** skipped (planned)

### US-129: Graceful degradation
**As a** student **I want** degraded mode when WebRTC fails **so that** I can still watch/listen.
- **Epic:** EP-17 · **Codons:** 37 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Media failure degrades gracefully without hard crash.
- **Test:** skipped (planned)

### US-130: Friendly error states
**As a** student **I want** friendly error messages **so that** failures aren't scary.
- **Epic:** EP-17 · **Codons:** 37 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Errors are human-readable with a recovery path.
- **Test:** skipped (planned)

### US-131: Recovery after server restart
**As a** teacher **I want** sessions to survive a server restart **so that** a deploy doesn't kill a lesson.
- **Epic:** EP-17 · **Codons:** 37 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Room data persists across restarts.
- **Test:** skipped (planned)

### US-132: WebGL/GPU failure fallback
**As a** student **I want** a fallback when GPU/WebGL is unavailable **so that** I can still access content.
- **Epic:** EP-17 · **Codons:** 37 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Non-3D fallback is offered.
- **Test:** skipped (planned)

---

## EP-18 — Content Authoring Tools

> **Goal:** *As a teacher, I can build and reuse my own chemistry content so that my
> platform reflects my teaching.*

### US-133: Chemistry scene templates in Spoke
**As a** teacher **I want** ready-made chemistry scene templates **so that** I don't start from blank.
- **Epic:** EP-18 · **Codons:** 38 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Template scenes render correctly in Spoke.
- **Test:** skipped (planned)

### US-134: Template per topic
**As a** teacher **I want** templates for periodic table, reactions, molecule display **so that** common setups are one click.
- **Epic:** EP-18 · **Codons:** 38 · **Status:** 📋 planned
- **Acceptance criteria:**
  - At least one template per planned topic.
- **Test:** skipped (planned)

### US-135: Experiment builder
**As a** teacher **I want** a builder to assemble experiments from elements/reactions **so that** I can craft lessons.
- **Epic:** EP-18 · **Codons:** 39 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Builder produces a publishable experiment.
- **Test:** skipped (planned)

### US-136: Save and publish experiments
**As a** teacher **I want** to save and publish experiments **so that** students reach them by link.
- **Epic:** EP-18 · **Codons:** 39 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Published experiment has a shareable URL.
- **Test:** skipped (planned)

### US-137: Custom element data import
**As a** teacher **I want** to import custom element data (CSV/JSON) **so that** I can extend beyond the 118.
- **Epic:** EP-18 · **Codons:** 40 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Import validates and stores custom elements.
- **Test:** skipped (planned)

### US-138: Import validation
**As a** teacher **I want** invalid imports rejected with clear errors **so that** bad data doesn't slip in.
- **Epic:** EP-18 · **Codons:** 40 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Malformed rows are reported, not silently ingested.
- **Test:** skipped (planned)

### US-139: Lesson plan management
**As a** teacher **I want** to create and manage lesson plans **so that** lessons are organized.
- **Epic:** EP-18 · **Codons:** 41 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Lesson plans are created/edited/deleted.
- **Test:** skipped (planned)

### US-140: Lesson plan → classroom
**As a** teacher **I want** to launch a lesson plan into a classroom **so that** plan becomes practice.
- **Epic:** EP-18 · **Codons:** 41 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Launching a plan creates/populates a room.
- **Test:** skipped (planned)

### US-141: Content versioning
**As a** teacher **I want** version history of authored content **so that** I can undo or compare.
- **Epic:** EP-18 · **Codons:** 41 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Edits create revisable versions.
- **Test:** skipped (planned)

---

## EP-19 — LMS Integration

> **Goal:** *As a school admin and teacher, the platform plugs into our LMS so that
> grades and rosters flow automatically.*

### US-142: SSO via LMS
**As a** student **I want** to sign in with my school SSO **so that** I don't juggle passwords.
- **Epic:** EP-19 · **Codons:** 42 · **Status:** 📋 planned
- **Acceptance criteria:**
  - SSO/LTI launch grants platform session.
- **Test:** skipped (planned)

### US-143: Teacher SSO with role mapping
**As a** teacher **I want** my LMS role to map to platform role **so that** I get teacher powers automatically.
- **Epic:** EP-19 · **Codons:** 42 · **Status:** 📋 planned
- **Acceptance criteria:**
  - LMS teacher role → platform teacher.
- **Test:** skipped (planned)

### US-144: Grade passback to LMS
**As a** teacher **I want** quiz scores to pass back to the LMS gradebook **so that** I don't copy grades manually.
- **Epic:** EP-19 · **Codons:** 43 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Finished quiz posts a grade to the LMS.
- **Test:** skipped (planned)

### US-145: Passback retry on failure
**As a** teacher **I want** failed passbacks retried **so that** grades aren't silently lost.
- **Epic:** EP-19 · **Codons:** 43 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Transient failures retry and eventually succeed.
- **Test:** skipped (planned)

### US-146: Roster sync
**As a** teacher **I want** class rosters synced from the LMS **so that** students are pre-enrolled.
- **Epic:** EP-19 · **Codons:** 44 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Enrolled students appear in the classroom.
- **Test:** skipped (planned)

### US-147: Roster de-provisioning
**As a** teacher **I want** removed students de-provisioned **so that** access matches enrollment.
- **Epic:** EP-19 · **Codons:** 44 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Unenrolled students lose access.
- **Test:** skipped (planned)

### US-148: SCORM/xAPI activity export
**As an** admin **I want** learning activity exported as SCORM/xAPI **so that** external analytics work.
- **Epic:** EP-19 · **Codons:** 45 · **Status:** 📋 planned
- **Acceptance criteria:**
  - xAPI statements emitted for key actions.
- **Test:** skipped (planned)

### US-149: LTI 1.3 launch
**As a** teacher **I want** standards-based LTI 1.3 launches **so that** integration is secure and interoperable.
- **Epic:** EP-19 · **Codons:** 42–45 · **Status:** 📋 planned
- **Acceptance criteria:**
  - LTI 1.3 launch validated with JWT/keyset.
- **Test:** skipped (planned)

---

## EP-20 — Mobile & Cross-Platform

> **Goal:** *As a student or teacher, I can use the platform on whatever device I have.*

### US-150: Responsive web client
**As a** student **I want** the client to work responsively on phones/tablets **so that** I can join from mobile.
- **Epic:** EP-20 · **Codons:** 46 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Core flows usable at mobile viewport widths.
- **Test:** skipped (planned)

### US-151: Mobile join flow
**As a** student **I want** to join rooms from a phone browser **so that** I don't need a PC.
- **Epic:** EP-20 · **Codons:** 46 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Room link opens and connects on mobile.
- **Test:** skipped (planned)

### US-152: Teacher tablet interface
**As a** teacher **I want** a tablet-optimized dashboard **so that** I can run class from a tablet.
- **Epic:** EP-20 · **Codons:** 47 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Dashboard layouts adapt for tablet touch.
- **Test:** skipped (planned)

### US-153: Touch controls
**As a** student **I want** touch-friendly controls **so that** I can interact without a mouse.
- **Epic:** EP-20 · **Codons:** 47 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Selection/navigation works by touch.
- **Test:** skipped (planned)

### US-154: Mobile VR support
**As a** student **I want** mobile VR (e.g. via a phone headset) **so that** I can have VR without a dedicated headset.
- **Epic:** EP-20 · **Codons:** 48 · **Status:** 📋 planned
- **Acceptance criteria:**
  - WebXR mobile path works.
- **Test:** skipped (planned)

### US-155: Mobile performance budget
**As a** student **I want** usable framerate on mobile devices **so that** it doesn't stutter.
- **Epic:** EP-20 · **Codons:** 48 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Defined fps maintained on reference mobile devices.
- **Test:** skipped (planned)

### US-156: Offline content mode
**As a** student **I want** essential content available offline **so that** I can study without connectivity.
- **Epic:** EP-20 · **Codons:** 49 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Cached element content usable offline.
- **Test:** skipped (planned)

### US-157: Offline sync on reconnect
**As a** student **I want** progress made offline to sync later **so that** nothing is lost.
- **Epic:** EP-20 · **Codons:** 49 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Offline actions sync on reconnect with conflict handling.
- **Test:** skipped (planned)

---

## EP-21 — Launch & Operations

> **Goal:** *As an operator, the platform can be deployed, operated, and handed over
> professionally.*

### US-158: Automated production deployment
**As an** operator **I want** one-command reproducible deploys **so that** releases are safe and fast.
- **Epic:** EP-21 · **Codons:** 50 · **Status:** 🚧 built (deploy.sh + CI pipeline exist)
- **Acceptance criteria:**
  - Deploy script runs idempotently to the production host.
- **Test:** none yet (requires deploy to run; `deploy.sh` exists)

### US-159: Rollback capability
**As an** operator **I want** to roll back a bad release **so that** incidents are short.
- **Epic:** EP-21 · **Codons:** 50 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Previous known-good version restores in a bounded time.
- **Test:** skipped (planned)

### US-160: Operator documentation
**As an** operator **I want** run/maintain documentation **so that** on-call doesn't depend on one person.
- **Epic:** EP-21 · **Codons:** 51 · **Status:** 🚧 built (README, guides, verify script)
- **Acceptance criteria:**
  - Setup/quick-start/architecture docs exist and are current.
- **Test:** none yet

### US-161: Teacher/student training material
**As a** teacher **I want** training material for running classes **so that** I can adopt the platform quickly.
- **Epic:** EP-21 · **Codons:** 51 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Classroom workflow guide exists and is correct.
- **Test:** skipped (planned)

### US-162: Load & capacity planning
**As an** operator **I want** a capacity plan backed by load tests **so that** I size infrastructure right.
- **Epic:** EP-21 · **Codons:** 52 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Capacity doc predicts growth with configured resources.
- **Test:** skipped (planned)

### US-163: Headroom under expected load
**As an** operator **I want** the platform to run with headroom at expected peak **so that** spikes don't break it.
- **Epic:** EP-21 · **Codons:** 52 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Peak-load test leaves margin below saturation.
- **Test:** skipped (planned)

### US-164: Launch hardening
**As an** operator **I want** a pre-launch hardening checklist executed **so that** go-live is uneventful.
- **Epic:** EP-21 · **Codons:** 53 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Checklist items all verified before go-live.
- **Test:** skipped (planned)

### US-165: Go-live runbook
**As an** operator **I want** a go-live runbook with rollback and contact points **so that** launch day is scripted.
- **Epic:** EP-21 · **Codons:** 53 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Runbook reviewed and rehearsed.
- **Test:** skipped (planned)

---

---

## EP-22 — Communication & Social Presence

> **Goal:** *As a student, I can talk, chat, and react with my class so that the VR
> classroom feels like a real classroom.*

### US-166: In-room text chat
**As a** student **I want** a text chat in the room **so that** I can ask/share without voice.
- **Epic:** EP-22 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Chat panel opens, messages send, and appear for participants.
- **Test:** none yet

### US-167: Emoji reactions
**As a** student **I want** quick emoji reactions **so that** I can respond without typing.
- **Epic:** EP-22 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Selecting an emoji broadcasts it to the room.
- **Test:** none yet

### US-168: Presence indicator
**As a** student **I want** to see who is in the room **so that** I know my classmates are present.
- **Epic:** EP-22 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Member list/presence updates as people join and leave.
- **Test:** none yet

### US-169: Display name near avatar
**As a** student **I want** my name shown near my avatar **so that** people know who I am.
- **Epic:** EP-22 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Name label renders and updates when renamed.
- **Test:** none yet

### US-170: Teacher↔student private messaging
**As a** teacher **I want** to message a single student privately **so that** I can help discreetly.
- **Epic:** EP-22 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Private DM visible only to the two participants.
- **Test:** skipped (planned)

### US-171: Chat history persisted
**As a** student **I want** chat available after refresh **so that** I don't lose class Q&A.
- **Epic:** EP-22 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Chat history persists across sessions.
- **Test:** skipped (planned)

### US-172: Teacher can disable/clear chat
**As a** teacher **I want** to clear or disable chat **so that** I keep focus.
- **Epic:** EP-22 · **Codons:** — (upstream Hubs moderation) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Chat pause/clear applies room-wide.
- **Test:** none yet

### US-173: Spatial voice via Dialog (SFU)
**As a** student **I want** voice communication through the WebRTC media server **so that** I can talk live in the room.
- **Epic:** EP-22 · **Codons:** 02 (Dialog) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Audio connects via Dialog and participants hear each other.
- **Test:** none yet (requires multi-user media session)

### US-174: Microphone/audio controls
**As a** student **I want** to mute/unmute and adjust audio **so that** I control what is heard.
- **Epic:** EP-22 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Mute state works and is reflected for others.
- **Test:** none yet

---

## EP-23 — Media & Content Sharing

> **Goal:** *As a teacher or student, I can share media in the room so that lessons are
> vivid and collaborative.*

### US-175: Share screen in room
**As a** teacher **I want** to share my screen **so that** students see exactly what I show.
- **Epic:** EP-23 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Screen sharing appears to room participants (with permission).
- **Test:** none yet (needs media session)

### US-176: Share images
**As a** student **I want** to share an image into the room **so that** I can show visuals.
- **Epic:** EP-23 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Image upload renders in the shared space.
- **Test:** none yet

### US-177: Share video (YouTube/Vimeo)
**As a** teacher **I want** to share a video link **so that** I can play instructional video.
- **Epic:** EP-23 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Supported video URLs play in-room.
- **Test:** none yet

### US-178: Embed 3D models (GLB)
**As a** teacher **I want** to embed 3D models **so that** chemistry objects can be inspected in VR.
- **Epic:** EP-23 · **Codons:** 30 (media pipeline) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - GLB model loads and is grabbable in the room.
- **Test:** none yet

### US-179: Share web links as media
**As a** student **I want** to drop a URL into the room **so that** web content can be shared.
- **Epic:** EP-23 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - URL media tiles appear and open on click.
- **Test:** none yet

### US-180: Teacher controls what's sharable
**As a** teacher **I want** to restrict media sharing in my room **so that** content stays appropriate.
- **Epic:** EP-23 · **Codons:** — (upstream Hubs moderation) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Sharing permissions apply room-wide.
- **Test:** none yet

### US-181: Media within room permission scope
**As a** student **I want** shared media to respect room access rules **so that** protected rooms stay private.
- **Epic:** EP-23 · **Codons:** 07–09 · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Only authorized room members can access room media.
- **Test:** none yet

### US-182: Media persists between sessions
**As a** teacher **I want** room media to remain after the session **so that** the room is ready next time.
- **Epic:** EP-23 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Placed media survives room restart (or is clearly ephemeral by config).
- **Test:** skipped (planned)

### US-183: Content safety guidance
**As a** student **I want** safe sharing defaults (no autoplay surprises) **so that** I'm not startled.
- **Epic:** EP-23 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Media requires explicit consent for playback where needed.
- **Test:** skipped (planned)

---

## EP-24 — Moderation & Safety

> **Goal:** *As a teacher, I can keep the classroom safe and respectful so that all
> students feel secure.*

### US-184: Mute a student
**As a** teacher **I want** to mute an individual student **so that** disruptions stop.
- **Epic:** EP-24 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Muted student can no longer transmit audio until unmuted.
- **Test:** none yet (needs media session)

### US-185: Eject a student from the room
**As a** teacher **I want** to kick a student out of the room **so that** I can remove troublemakers.
- **Epic:** EP-24 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Ejected student leaves and cannot instantly rejoin.
- **Test:** none yet

### US-186: Ban a user from a room
**As a** teacher **I want** to ban a user **so that** they can't return.
- **Epic:** EP-24 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Banned user is refused entry.
- **Test:** none yet

### US-187: Rename/remove inappropriate name or avatar
**As a** teacher **I want** to rename or hide an inappropriate name/avatar **so that** the room stays decent.
- **Epic:** EP-24 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Renamed user's name updates everywhere.
- **Test:** none yet

### US-188: Report an abusive user
**As a** student **I want** to report someone to the teacher **so that** abuse is actionable.
- **Epic:** EP-24 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Report reaches the teacher with context.
- **Test:** skipped (planned)

### US-189: Anonymous reporting
**As a** student **I want** reports not to expose me **so that** I feel safe reporting.
- **Epic:** EP-24 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Reporter identity is hidden from the reported user.
- **Test:** skipped (planned)

### US-190: Room permission presets
**As a** teacher **I want** permission presets (collaborative/lecture/demo) **so that** setting up a room is one click.
- **Epic:** EP-24 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Preset applies a sensible permission bundle.
- **Test:** skipped (planned)

### US-191: Moderation audit log
**As a** teacher **I want** a log of moderation actions **so that** I can review what happened.
- **Epic:** EP-24 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Mute/kick/ban actions are timestamped and visible to the teacher.
- **Test:** skipped (planned)

---

## EP-25 — Accounts & Profiles

> **Goal:** *As a user, I can make the platform mine — name, avatar, and settings — and
> control my data.*

### US-192: Set display name
**As a** student **I want** to set my display name **so that** classmates recognize me.
- **Epic:** EP-25 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Name persists and is shown in rooms.
- **Test:** none yet

### US-193: Choose avatar
**As a** student **I want** to pick my avatar **so that** I express myself safely.
- **Epic:** EP-25 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Selected avatar persists across sessions.
- **Test:** none yet

### US-194: Account settings (language, accessibility, privacy)
**As a** student **I want** settings for language, accessibility, and privacy **so that** the platform fits me.
- **Epic:** EP-25 · **Codons:** 34–35 · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Settings persist and take effect.
- **Test:** none yet

### US-195: Session persistence
**As a** student **I want** to stay signed in across visits **so that** I don't log in every lesson.
- **Epic:** EP-25 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Session survives reload/fresh visit.
- **Test:** none yet

### US-196: Profile picture
**As a** teacher **I want** a profile picture **so that** students recognize me.
- **Epic:** EP-25 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Uploaded picture displays in presence/avatar contexts.
- **Test:** skipped (planned)

### US-197: Student progress on profile
**As a** student **I want** a profile view of my explored elements and scores **so that** I can track myself.
- **Epic:** EP-25 · **Codons:** 23 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Profile shows progress summary from progress API.
- **Test:** skipped (planned)

### US-198: Teacher profile with class overview
**As a** teacher **I want** a profile overview of my classes **so that** everything is one click away.
- **Epic:** EP-25 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Profile links to classes/dashboards.
- **Test:** skipped (planned)

### US-199: Sign out
**As a** user **I want** to sign out **so that** I can switch accounts or protect privacy.
- **Epic:** EP-25 · **Codons:** — (upstream Hubs) · **Status:** 🚧 built*
- **Acceptance criteria:**
  - Sign-out ends the session and returns to the entry screen.
- **Test:** none yet

### US-200: Delete own account
**As a** student **I want** to delete my account and data **so that** I control my footprint.
- **Epic:** EP-25 · **Codons:** 33 (data lifecycle) · **Status:** 📋 planned
- **Acceptance criteria:**
  - Deletion removes personal data per policy.
- **Test:** skipped (planned)

---

## EP-26 — In-Room Collaboration & Breakout

> **Goal:** *As a teacher, I can organize collaborative work so that students learn
> together and from each other.*

### US-201: Split class into groups
**As a** teacher **I want** to split the class into groups **so that** small-group work is possible.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Group assignment UI works.
- **Test:** skipped (planned)

### US-202: Assign students to groups
**As a** teacher **I want** to assign or shuffle students into groups **so that** grouping is fair.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Assignment persists and can be edited.
- **Test:** skipped (planned)

### US-203: Breakout rooms
**As a** student **I want** to be moved to my group's breakout space **so that** groups don't disturb each other.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Each group gets an isolated space.
- **Test:** skipped (planned)

### US-204: Teacher visits groups
**As a** teacher **I want** to visit any group's breakout **so that** I can support everyone.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Teacher can hop between breakouts.
- **Test:** skipped (planned)

### US-205: Recombine groups
**As a** teacher **I want** to bring the class back together **so that** we can debrief.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Recombine returns all students to the main space.
- **Test:** skipped (planned)

### US-206: Shared whiteboard
**As a** student **I want** a shared whiteboard **so that** we can brainstorm visually.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Drawings sync live across the group.
- **Test:** skipped (planned)

### US-207: Collaborative marker on an element
**As a** student **I want** to place a shared pin/marker on an element **so that** we can point at things together.
- **Epic:** EP-26 · **Codons:** 19 (annotations) · **Status:** 🚧 built* (extended from annotation story)
- **Acceptance criteria:**
  - Multiple students see each other's markers.
- **Test:** none yet

### US-208: Group timer/task
**As a** teacher **I want** a per-group timer or task prompt **so that** groups stay on pace.
- **Epic:** EP-26 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Timer/task shows in each breakout.
- **Test:** skipped (planned)

---

## EP-27 — Notifications & Scheduling

> **Goal:** *As a teacher, I can schedule and remind, and as a student I never miss a
> class.*

### US-209: Create a scheduled class event
**As a** teacher **I want** to schedule a class event **so that** it happens at a set time.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Event saved with time and room link.
- **Test:** skipped (planned)

### US-210: Calendar/email invite
**As a** teacher **I want** an ICS/calendar invite **so that** students get it in their calendars.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Invite downloads/embeds in email.
- **Test:** skipped (planned)

### US-211: Email reminder
**As a** student **I want** a reminder before class **so that** I don't forget.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Reminder fires at configured lead time.
- **Test:** skipped (planned)

### US-212: Room link in invite
**As a** student **I want** the room link inside the invite **so that** joining is one click.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Link resolves to the room.
- **Test:** skipped (planned)

### US-213: Student sees upcoming classes
**As a** student **I want** an upcoming-classes list **so that** I can plan.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Upcoming events visible after login.
- **Test:** skipped (planned)

### US-214: Notification preferences
**As a** student **I want** to choose which notifications I get **so that** I'm not spammed.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Preferences persist and gate delivery.
- **Test:** skipped (planned)

### US-215: RSVP / attendance confirmations
**As a** teacher **I want** RSVPs or attendance confirmations **so that** I know who's coming.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - RSVP state tracked and visible.
- **Test:** skipped (planned)

### US-216: Reschedule/cancel notifies
**As a** teacher **I want** reschedule/cancel to notify students **so that** they aren't left waiting.
- **Epic:** EP-27 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Change notification reaches attendees.
- **Test:** skipped (planned)

---

## EP-28 — Data Protection & Compliance

> **Goal:** *As an admin, the platform meets legal and ethical data rules so that schools
> can use it safely.*

### US-217: GDPR-compliant processing
**As an** admin **I want** GDPR-compliant data processing **so that** we're lawful for EU schools.
- **Epic:** EP-28 · **Codons:** 31, 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Processing documented with lawful basis.
- **Test:** skipped (planned)

### US-218: Consent for minors
**As a** teacher **I want** consent handling for underage students **so that** we comply with child-data rules.
- **Epic:** EP-28 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Guardian/teacher consent captured and stored.
- **Test:** skipped (planned)

### US-219: Student data export
**As a** student **I want** to export my data **so that** I have a copy of what's stored.
- **Epic:** EP-28 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Export returns a machine-readable bundle.
- **Test:** skipped (planned)

### US-220: Account deletion removes data
**As a** student **I want** deletion to remove my data **so that** exercising my rights works.
- **Epic:** EP-28 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Deletion cascades through all stores.
- **Test:** skipped (planned)

### US-221: Privacy policy accessible
**As a** student **I want** a readable privacy policy **so that** I know what happens with my data.
- **Epic:** EP-28 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Policy linked from sign-in/footer.
- **Test:** skipped (planned)

### US-222: Secure PII storage
**As an** admin **I want** PII encrypted at rest/in transit **so that** breaches are less harmful.
- **Epic:** EP-28 · **Codons:** 31 · **Status:** 🚧 built (TLS ✅; encryption-at-rest pending)
- **Acceptance criteria:**
  - PII fields protected by controls.
- **Test:** none yet

### US-223: Data retention policy
**As an** admin **I want** a retention policy with enforcement **so that** old data is purged.
- **Epic:** EP-28 · **Codons:** 33 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Retention rules delete/purge automatically.
- **Test:** skipped (planned)

### US-224: No unnecessary tracking
**As a** student **I want** tracking limited to what's needed **so that** my behavior isn't sold.
- **Epic:** EP-28 · **Codons:** 31, 32 · **Status:** 🚧 built* (analytics limited; audit pending)
- **Acceptance criteria:**
  - No third-party ad/tracking on the live domain.
- **Test:** none yet

### US-225: Data-processing records
**As an** admin **I want** a record of processing activities **so that** compliance is auditable.
- **Epic:** EP-28 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - ROPA document maintained.
- **Test:** skipped (planned)

---

## EP-29 — Integration & Developer Ecosystem

> **Goal:** *As a developer, I can build on the platform so that schools can connect and
> extend it.*

### US-226: Public read API for element data
**As a** developer **I want** a stable public API for element data **so that** I can build tools on it.
- **Epic:** EP-29 · **Codons:** 00–06 · **Status:** 🚧 built* (`GET /api/v1/hubs/element/:symbol` live)
- **Acceptance criteria:**
  - Read endpoints documented and versioned.
- **Test:** covered by US-013/021/027

### US-227: Webhooks for room events
**As a** developer **I want** webhooks on room events **so that** external systems react.
- **Epic:** EP-29 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Event delivery with retries.
- **Test:** skipped (planned)

### US-228: API tokens for integrations
**As a** developer **I want** scoped API tokens **so that** integrations authenticate safely.
- **Epic:** EP-29 · **Codons:** 07–09 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Tokens scoped and revocable.
- **Test:** skipped (planned)

### US-229: Embed room in another page
**As a** teacher **I want** to embed a room in an LMS page **so that** students don't navigate away.
- **Epic:** EP-29 · **Codons:** 42–45 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Embeddable iframe works within allowed origins.
- **Test:** skipped (planned)

### US-230: Developer playground/docs
**As a** developer **I want** API docs and a playground **so that** I can integrate faster.
- **Epic:** EP-29 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Docs exist with runnable examples.
- **Test:** skipped (planned)

### US-231: Versioned API
**As a** developer **I want** versioned APIs **so that** my integrations don't break.
- **Epic:** EP-29 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Breaking changes ship under a new version.
- **Test:** skipped (planned)

### US-232: Usage metrics for integrators
**As a** developer **I want** usage metrics **so that** I can monitor my integration.
- **Epic:** EP-29 · **Codons:** 32 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Key metrics available per integration.
- **Test:** skipped (planned)

### US-233: Sandbox/test mode for integrations
**As a** developer **I want** a sandbox environment **so that** I don't break production.
- **Epic:** EP-29 · **Codons:** 50 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Sandbox isolated from production data.
- **Test:** skipped (planned)

---

## EP-30 — Quality Engineering

> **Goal:** *As a developer and admin, quality is enforced automatically so that
> regressions never reach students.*

### US-234: Automated E2E regression for core journeys
**As a** developer **I want** automated regression tests for core journeys **so that** the platform stays reliable.
- **Epic:** EP-30 · **Codons:** 30, 52 · **Status:** 🚧 built* (initial live suites exist)
- **Acceptance criteria:**
  - Core journey suites run and gate releases.
- **Test:** covered by `e2e/epics/*.spec.ts`

### US-235: Contract/schema tests for APIs
**As a** developer **I want** schema/contract tests for APIs **so that** payload changes are intentional.
- **Epic:** EP-30 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Schema violations fail CI.
- **Test:** skipped (planned)

### US-236: Visual regression checks
**As a** developer **I want** visual regression checks **so that** styling regressions are caught.
- **Epic:** EP-30 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Screenshot diffs reviewed in CI.
- **Test:** skipped (planned)

### US-237: Accessibility checks in CI
**As a** developer **I want** automated a11y checks **so that** WCAG regressions are caught.
- **Epic:** EP-30 · **Codons:** 35 · **Status:** 📋 planned
- **Acceptance criteria:**
  - a11y test results in CI.
- **Test:** skipped (planned)

### US-238: Performance budgets in CI
**As a** developer **I want** performance budgets checked in CI **so that** slowness is blocked.
- **Epic:** EP-30 · **Codons:** 26, 30 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Budget violations fail CI.
- **Test:** skipped (planned)

### US-239: Story↔test traceability enforced
**As a** developer **I want** every ✅ tested story to have a test **so that** docs and code never drift.
- **Epic:** EP-30 · **Codons:** — · **Status:** 🚧 built (`scripts/check-story-tests.py`; CI wiring pending)
- **Acceptance criteria:**
  - `check-story-tests.py --strict` passes in CI.
- **Test:** script exists; run manually / CI pending

### US-240: Flake-free suites
**As a** developer **I want** stable test suites (quarantine + retry policy) **so that** red runs mean real problems.
- **Epic:** EP-30 · **Codons:** — · **Status:** 📋 planned
- **Acceptance criteria:**
  - Flake rate below defined threshold.
- **Test:** skipped (planned)

### US-241: Release quality gates
**As a** developer **I want** quality gates before release (tests, a11y, perf, traceability) **so that** deploys are safe.
- **Epic:** EP-30 · **Codons:** 50, 53 · **Status:** 📋 planned
- **Acceptance criteria:**
  - Ship blocked unless gates pass.
- **Test:** skipped (planned)

---

## Test Traceability Summary

| Story | Status | Test location |
|---|---|---|
| US-001 open platform | ✅ tested | `e2e/epics/ep-01-auth-rooms.spec.ts` |
| US-011 browse rooms | ✅ tested | `e2e/epics/ep-01-auth-rooms.spec.ts` |
| US-013 element-linked room via API | ✅ tested | `e2e/epics/ep-02-chemistry-content.spec.ts` |
| US-014 classroom dashboard | ✅ tested | `e2e/epics/ep-02-chemistry-content.spec.ts` |
| US-019 rooms over HTTPS | ✅ tested | `e2e/epics/ep-01-auth-rooms.spec.ts` |
| US-021 element lookup returns data | ✅ tested | `e2e/epics/ep-02-chemistry-content.spec.ts` |
| US-027 API answers for any symbol | ✅ tested | `e2e/epics/ep-02-chemistry-content.spec.ts` |
| US-097 CSP header (API) | ✅ tested | `e2e/epics/ep-02-chemistry-content.spec.ts` |
| US-101 TLS everywhere | ✅ tested | `e2e/epics/ep-02-chemistry-content.spec.ts` |
| US-226 element data read API | ✅ tested (via 013/021/027) | as above |
| US-234 E2E core journeys | 🚧 built* | `e2e/epics/*.spec.ts` |
| US-239 story↔test traceability | 🚧 built | `scripts/check-story-tests.py` |
| US-008, US-093, US-099 + EP-22/23/24/25 upstream features (`🚧 built*`) | 🚧 built (gap documented) | manual / none yet |
| US-003…US-010, US-012, US-015…US-018, US-024, EP-06 stories | 🚧 built | manual / none yet |
| Remaining EP-03/04…21 and EP-26…30 (except noted) | 📋 planned | skipped reporting |

---

## How to Extend

1. **Add a story** → number it next in sequence under its epic, give it persona/AC/status.
2. **Add a test** → create/extend a spec in `e2e/epics/`, name the test `US-0xx …`, and
   flip the story status to ✅ tested.
3. **Verify traceability** → run `scripts/check-story-tests.py` (see design doc) to catch
   status/test mismatches.
