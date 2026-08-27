# PSE Rooms — element-room tooling & scenes

Tooling and assets recovered from the original deployment (legion, 2026-08-27) that power
the PSE (Periodensystem der Elemente) rooms on hubs.chemie-lernen.org.

## Layout

| Path | Purpose |
|---|---|
| `scenes/` | 5 archetype room GLB models + screenshots (v2): `ElementRoom`, `PeriodicPavilion`, `LabWing`, `ExperimentalRoom`, `Lobby` |
| `symbol_to_archetype.json` | Element symbol → archetype room mapping (e.g. `"Ac": "ElementRoom"`) |
| `live_hubs.json` | Element room sids + names (e.g. `JQLHx3e` = "Chemie Raum – Wasserstoff (H)") |
| `scene_sids.json` / `scene_sids_v2.json` | Archetype name → scene sid (v1/v2 uploads) |
| `scene_models.txt` | Legacy scene-sid → owned-file id mapping |
| `scripts/assign_hubs.py` | Patches every element room's `scene_id` via the API (uses owner token) |
| `scripts/insert_scenes_route.py`, `fix_scenes_route.py` | Scene insert/fix helpers |
| `scripts/probe_owner.py`, `probe_owner2.py` | Owner/perms diagnostics |
| `scripts/repro-room.js` | Room join reproduction harness |

## How rooms work

- Rooms are Hubs hubs named `Chemie Raum – <Element> (<Symbol>)`.
- The PSE-in-VR app at `pse.chemie-lernen.org` maps `?element=<symbol>` to a room index
  (embed contract `a64fdd4` in `src/embed/mount.ts` of the hello-webxr repo).
- Each room links to `https://pse.chemie-lernen.org?element=<symbol>` via the Reticulum
  fork's `HubView` `pse_url` injection.

## Secrets

Do **not** commit tokens/keys to this public repo. `assign_hubs.py` expects the Guardian
owner token at `/tmp/owner_token.txt` (obtained / minted out-of-band; see private
`tobias-weiss-ai-xr/hubs-compose-state` repo for a preserved copy of the original).
