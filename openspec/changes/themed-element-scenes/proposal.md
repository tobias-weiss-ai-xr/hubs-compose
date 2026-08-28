# Change: Themed 3D scenes for every element room

**Epic:** 2 — Every element room has a themed 3D scene (Milestone A "Rooms that aren't empty")
**Status:** proposed
**Owner:** tobias-weiss
**Date:** 2026-08-27

## Why

Element rooms currently join successfully (Epic 1 fixed), but every room has `scene: null`
and `scenes` / `scene_listings` are empty on the live `ret_dev`. Users land in an empty
gray void. The 5 archetype scenes (ElementRoom, PeriodicPavilion, LabWing,
ExperimentalRoom, Lobby) were recovered from legion into `tools/pse-rooms/scenes/` and
their sids (`scene_sids_v2.json`), plus the per-element mapping (`symbol_to_archetype.json`)
and assignment script (`assign_hubs.py`, needs owner token). This change wires them into the
live rooms so each element room loads a real GLB.

## What changes

1. Restore the 5 archetype scenes into live `ret_dev` (upload GLBs; create `scenes` rows +
   `scene_listings` owned by an educator account).
2. Map every element room to an archetype scene via `symbol_to_archetype.json` using
   `assign_hubs.py` (or a server-side default in `HubView`/room creation).
3. Ensure `hub.hub.scene` is populated on join so the client loads the GLB (removes the
   `Failed to load glTF model` error).
4. Add e2e coverage asserting `hub.scene` non-null after join and the GLB loads.

## Non-goals

- Per-element unique atomic models (Epic 8) — out of scope.
- Scene editing in Spoke by teachers (later epic).
- Avatar restoration (Epic 5) — separate change.

## Risks / preconditions

- Requires the owner/Guardian token (kept in private `hubs-compose-state`), not public repo.
- Live DB restore must be done on the backup, verified, then promoted — no destructive
  overwrite of existing rooms.
- GLB size must stay within the <5 s load budget (US-2.4).
