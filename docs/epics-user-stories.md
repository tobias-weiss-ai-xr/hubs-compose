# PSE Room & Hubs Platform — Epics & User Stories

Agile backlog for the chemie-lernen.org PSE-in-VR / Hubs room feature. Grounded in the
2026-08-27 state: **room joins now work end-to-end** (RoomAssigner + PermsToken + dialog
TLS/announced-IP fixes landed), and the original element-room data (171 element rooms,
30 scenes, 24 avatars) was recovered from legion into `tobias-weiss-ai-xr/hubs-compose-state`.

Legend: `[DONE]` shipped · `[IN PROGRESS]` active · `[TODO]` planned · components in `[brackets]`.

---

## Epic 1 — Element rooms work flawlessly end-to-end `[DONE → HARDENING]`

As a **student**, I want to join an element room and immediately be inside a working
multi-user 3D space, so that I can explore chemistry together with my class without IT friction.

### User Stories
- **US-1.1 `[DONE]`** As a student, I want the room link from the PSE site to load the
  correct element room, so that I land in "Wasserstoff-Raum" when I click H.
  > AC: `?element=h` → hub join returns 200 + hub JSON with populated `host`.
  > Regression guard: `e2e/ws-join.spec.ts` (socket → ret → hub → presence → dialog).
- **US-1.2 `[DONE]`** As a student, I want my audio/video to connect, so that I can talk
  to classmates in the room.
  > AC: dialog protoo WS connects with subprotocol `protoo`; `getRouterRtpCapabilities`
  > returns audio/opus; media ports 40000–40050 reachable at `MEDIASOUP_ANNOUNCED_IP`.
- **US-1.3 `[DONE]`** As a first-time user, I want a name-selection and mic-check before
  entry, so that I don't join silently or with a random identity.
- **US-1.4 `[DONE]`** As an unauthenticated visitor, I want to join an open room without
  login, so that classrooms with students without accounts can still use it.
- **US-1.5 `[TODO]`** As a student joining a second time on the same day, I want my name
  remembered, so that I don't redo the avatar setup every visit.
  > AC: profile persists via `localStorage`/account session; no re-prompt.
- **US-1.6 `[TODO]`** As a student with a weak connection, I want graceful degradation
  (video off, audio-only, reduced bitrate), so that the room stays usable over school WiFi.
  > AC: automated bitrate/layer switching; no hard disconnect.

---

## Epic 2 — Every element room has a themed 3D scene `[IN PROGRESS]`

As a **student**, I want each element room to feel like that element (not an empty void),
so that chemistry becomes tangible and memorable.

### Current state (hard blocker for this epic)
- Live rooms have `scene: null`; `scenes` / `scene_listings` are empty on the live DB.
- 5 archetype scenes (ElementRoom, PeriodicPavilion, LabWing, ExperimentalRoom, Lobby)
  + screenshots recovered (v1/v2) → `tools/pse-rooms/scenes/` + `scene_sids{,_v2}.json`.
- Legion DB holds them ready (sids `rLL2FQw` ElementRoom v2 etc.) — restore pending.

### User Stories
- **US-2.1 `[TODO]`** As a student, I want ElementRoom as the default scene of every
  element room, so that I don't join an empty gray space.
  > AC: create/restore 5 archetype scenes in live `ret_dev`; `GET /api/v1/scenes/:sid` 200;
  > `hub.hub.scene` populated; room loads a real GLB (no `Failed to load glTF model`).
- **US-2.2 `[TODO]`** As a student in the Wasserstoff room, I want the scene to show a
  hydrogen-themed layout, so that the space matches the element.
  > AC: `symbol_to_archetype.json` mapping respected; a per-element overlay/atom model present.
- **US-2.3 `[TODO]`** As a teacher, I want the archetype scenes uploaded from the recovered
  artifacts (v2), so that we reuse the already-built designs instead of rebuilding in Spoke.
  > AC: `insert_scenes_route.py`/`assign_hubs.py` run successfully; scenes owned by educator account.
- **US-2.4 `[TODO]`** As a student with a mid-range laptop, I want scenes to load in < 5 s,
  so that the room is usable in a 45-minute lesson.
  > AC: GLB ≤ ~1 MB or streamed; measured load logged in e2e.
- **US-2.5 `[TODO]`** As a first-time visitor, I want a meaningful spawning point and
  camera, so that I start facing the interesting content, not a wall.

---

## Epic 3 — Element rooms are discoverable from the PSE site `[DONE → POLISH]`

As a **student**, I want to jump from the PSE element page straight into that element's
live room, so that exploration and the 3D space are one connected experience.

### User Stories
- **US-3.1 `[DONE]`** As a student, I want a `pse_url` on every element room, so that the
  room links back to the element page.
  > AC: `HubView` returns `pse_url: https://pse.chemie-lernen.org?element=<symbol>` for
  > hubs with `user_data.chemistry`.
- **US-3.2 `[DONE]`** As a developer, I want `GET /api/v1/hubs/element/:symbol` to list
  rooms for that element with pagination, so that the PSE app can deep-link reliably.
- **US-3.3 `[TODO]`** As a student, I want the current room occupancy shown on the PSE
  element page, so that I can see if my classmates are already inside.
  > AC: PSE page polls member_count; badge appears when >0.
- **US-3.4 `[TODO]`** As a teacher, I want to be able to create a fresh room per class
  session (not share one permanent room), so that groups don't collide.
  > AC: `POST /api/v1/hubs` with `user_data.chemistry` from the PSE/kiosk UI; room gets
  > its own sid + scene.

---

## Epic 4 — Classrooms & moderation for educators `[TODO]`

As a **teacher**, I want control over who is in my VR room and what happens there, so that
lesson time stays focused and safe.

### User Stories
- **US-4.1 `[TODO]`** As a teacher, I want to set rooms to "join requires approval", so
  that strangers can't drop in mid-lesson.
  > AC: entry_mode toggle via API/admin; pending-join queue with approve/deny.
- **US-4.2 `[TODO]`** As a teacher, I want to mute a disruptive student, so that the rest
  of the class isn't disturbed.
  > AC: moderator can mute audio/video; student sees "muted by moderator".
- **US-4.3 `[TODO]`** As a teacher, I want to kick a user from the room, so that I can
  remove unwanted participants.
  > AC: dialog `kick` protoo request with valid RS512 perms token (`kick_users` claim); e2e guard.
- **US-4.4 `[TODO]`** As a teacher, I want to close a room after the lesson, so that
  students don't reconvene unsupervised.
  > AC: close/delete hub via API; subsequent joins refused (404/no-such-hub).
- **US-4.5 `[TODO]`** As a teacher, I want a safety briefing overlay on first join, so that
  students know the classroom rules inside VR.
  > AC: configurable text injected into scene/lobby UI.

---

## Epic 5 — Avatars make the room feel like "us" `[TODO]`

As a **student**, I want to look like a recognizable character (and ideally my own), so that
I can identify my friends in the 3D space.

### Current state
- 24 avatars recovered in legion DB (0 in live). Live storage volume empty (76 blob files
  preserved in backup repo `hubs-compose-state/storage/`).

### User Stories
- **US-5.1 `[TODO]`** As a student, I want a set of curated default avatars to choose from,
  so that I'm not the grey default robot.
  > AC: restores avatar_listings (24) from legion DB; avatar picker shows them.
- **US-5.2 `[TODO]`** As a student, I want to preview an avatar before committing, so that
  I don't pick one I dislike.
- **US-5.3 `[TODO]`** As a school, (optional) I want to upload our mascot/logo avatar, so
  that the space feels like our school.
  > AC: `POST /api/v1/avatars` works with owner token; gltf served from `/api/v1/avatars/:id/avatar.gltf`.

---

## Epic 6 — Platform reliability & operations `[IN PROGRESS]`

As an **operator**, I want the platform to stay up and recover automatically, so that
lessons aren't cancelled by infrastructure issues.

### User Stories
- **US-6.1 `[DONE]`** As an operator, I want room joins to no longer crash the server, so
  that the PSE rooms stay usable.
  > Root causes fixed: RoomAssigner (janus_service_name), PermsToken (perms_key in config.toml),
  > dialog TLS, MEDIASOUP_ANNOUNCED_IP. Guards in `e2e/ws-join.spec.ts`.
- **US-6.2 `[IN PROGRESS]`** As an operator, I want valid TLS on all endpoints including
  :4443, so that browsers don't block WebRTC.
  > AC: `openssl s_client -connect :4443` → Verify OK, notAfter ≥ 90 days; add renewal monitor.
- **US-6.3 `[TODO]`** As an operator, I want automatic cleanup of orphaned veths, so that
  container starts don't fail with "Cannot allocate memory" exhausting `ve::netif_max_nr`.
  > AC: cron/systemd timer runs the orphan-veth GC; alert on threshold.
- **US-6.4 `[TODO]`** As an operator, I want the `page_controller.ex:480` nil-user-agent
  crash fixed (kube-probe), so that health checks don't generate 500s.
  > AC: guard `String.contains?(user_agent || "", "kube-probe")`; add test.
- **US-6.5 `[TODO]`** As an operator, I want a cheap liveness probe per service (reticulum,
  dialog, client, spoke, postgrest), so that regressions are caught early.
> AC: run `npx playwright test` in CI/cron against live; alert on failure.
- **US-6.6 `[TODO]`** As an operator, I want secrets (perms key, DB dumps, owner tokens)
  kept out of public repos, so that the platform isn't compromised via GitHub.
  > Done so far: secrets only in private `hubs-compose-state`. Follow-up: rotate/remove
  > `certs/*` + `files/coturn/certs/*` from public history.

---

## Epic 7 — Observability & analytics `[TODO]`

As an **operator/teacher**, I want to know how the rooms are used, so that we can improve
uptime and teaching value.

### User Stories
- **US-7.1 `[TODO]`** As an operator, I want dashboards for CCU/join success/error rates,
  so that I see the next problem before users do.
  > AC: reticulum `Statix` metrics → prometheus; join-crash counter > 0 triggers alert.
- **US-7.2 `[TODO]`** As a teacher, I want (privacy-safe) stats on room visits per element,
  so that I can see which topics engage students.
  > AC: aggregate only counts/time, no PII; documented privacy note.
- **US-7.3 `[TODO]`** As an operator, I want dialog capacity/load in a dashboard (admin
  endpoint `/meta`, `/report`), so that I can plan workers.

---

## Epic 8 — Content & pedagogical assets `[TODO]`

As a **student**, I want more than an empty room: interactive element models, tasks, and
safe "virtual experiments" inside the room.

### User Stories
- **US-8.1 `[TODO]`** As a student, I want to grab/rotate a 3D model of my element, so
  that I can inspect electron shells up close.
  > AC: glTF per element (or per archetype) spawnable in-room; pointer interaction.
- **US-8.2 `[TODO]`** As a student, I want a small quiz board per room (e.g. "Symbol of
  Wasserstoff?"), so that play adds learning.
- **US-8.3 `[TODO]`** As a teacher, I want an in-room whiteboard / shared notes, so that
  groups can work together without leaving VR.
- **US-8.4 `[TODO]`** As a student, I want to NOT be able to run "experiments" that are
  actually dangerous, so that the space remains safe (sandbox-only content).

---

## Backlog hygiene notes
- Stories map to concrete files/commits where possible (see per-US AC).
- Testing: every story above that touches the join/create/query path must add/extend an
  e2e case in `e2e/` (regression suite currently 25/25 passing).
- Secrets & recovered assets: never push to public `hubs-compose`; use private
  `tobias-weiss-ai-xr/hubs-compose-state` (bundle chunks + DB dump verify SHA256
  `c9ebff03…`).
