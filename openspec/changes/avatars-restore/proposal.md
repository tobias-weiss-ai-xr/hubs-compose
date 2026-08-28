# Change: Restore avatar catalog from recovered data

**Epic:** 5 — Avatars make the room feel like "us" (Milestone C)
**Status:** proposed
**Owner:** tobias-weiss
**Date:** 2026-08-27

## Why

Live `ret_dev` has zero avatars and an empty storage volume; users see the default grey robot.
24 avatars were recovered from legion (DB dump + 76 storage blobs) and preserved in the
private `hubs-compose-state` repo. This change restores the avatar catalog so the avatar
picker shows real choices, and (optionally) lets a school upload its own mascot.

## What changes

1. **Restore catalog** — import the 24 avatars from the recovered DB dump / storage blobs into
   live `ret_dev` (avatars + avatar_listings owned by an educator account).
2. **Avatar picker** — ensure the client lists/restores available avatars on first join.
3. **Upload (optional)** — `POST /api/v1/avatars` with an owner token works, serving the glTF
   from `/api/v1/avatars/:id/avatar.gltf`.

## Non-goals

- Per-student custom avatars (later).
- Scene restoration (Epic 2 `themed-element-scenes` change handles scenes).

## Risks / preconditions

- Restore must run on a backup first, verified, then promoted — never overwrite existing live
  rooms/avatars destructively.
- Owner/Guardian token (private `hubs-compose-state`) required to mint `avatar_listings`;
  never commit secrets to public `hubs-compose`.
- Storage blobs are named `*.blob` + `meta.json` in `hubs-compose-state/storage/`; the
  restore must re-map blob references to the target storage backend.
