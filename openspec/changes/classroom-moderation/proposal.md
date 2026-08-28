# Change: Classroom & moderator controls for element rooms

**Epic:** 4 — Classrooms & moderation for educators (Milestone B "Safe classrooms")
**Status:** proposed
**Owner:** tobias-weiss
**Date:** 2026-08-27

## Why

Teachers won't adopt VR rooms for lessons until they can control who enters and stop
disruption. Today any unauthenticated visitor can join an open room and nothing can be done
about a disruptive participant. This change adds entry approval, moderator mute/kick, and
room close/delete, using capabilities already present in the stack:
- Dialog protoo server exposes a `kick` request gated by an RS512 perms token carrying the
  `kick_users` claim (minted via `GUARDIAN_SECRET_KEY`, signed with `AUTH_KEY`).
- Reticulum `HubView` already supports `entry_mode` (allow / api / request).

## What changes

1. **Entry approval** — add an `entry_mode: request` flow with a pending-join queue and
   moderator approve/deny (UI + channel events).
2. **Moderator mute/kick** — wire the dialog `kick` protoo request behind a valid perms token
   (`kick_users`); client shows "muted/kicked by moderator".
3. **Room close/delete** — `DELETE /api/v1/hubs/:id` (or admin) so a teacher can end the room;
   subsequent joins refused.
4. **Safety briefing overlay** — optional configurable text injected on first join.

## Non-goals

- Per-student persistent roles/rosters (later).
- Recording/playback of sessions (Epic 7 analytics can reference, but capture is out of scope).

## Risks / preconditions

- Moderation actions require a perms token; minting must never leak `GUARDIAN_SECRET_KEY` to
  the public repo (private `hubs-compose-state` only).
- `kick` must validate the RS512 signature against `AUTH_KEY` (`/etc/perms.pub.pem`).
