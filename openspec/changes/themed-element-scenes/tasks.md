# Tasks — Themed 3D scenes for every element room

> Milestone A (data restore + join surfacing) **DONE** 2026-08-28. Scenes restored, all
> 74 chemistry rooms carry `scene_id`, `HubView` surfaces `scene` on join, and the GLB is
> served `200` so the client renders the themed model. See "Deployment config fixes" below —
> those two config changes were required to make the scenes actually load.

- [x] 1. Restore archetype scenes into live `ret_dev`
  - [x] 1.1 Mint/obtain owner token (from private `hubs-compose-state`, never public)
  - [x] 1.2 Upload 5 GLBs (v2) from `tools/pse-rooms/scenes/` via `POST /api/v1/media` + `POST /api/v1/scenes`
        (service account + Guardian owner token). Sids: ElementRoom `mhezdAw`, Lobby `5eCpjs5`,
        PeriodicPavilion `C8mDqXf`, LabWing `iqrm3d5`, ExperimentalRoom `UwGfarL`.
  - [x] 1.3 `GET /api/v1/scenes/:sid` returns 200 for all five.
- [x] 2. Map element rooms → scenes
  - [x] 2.1 Load `symbol_to_archetype.json` (118 symbols → 5 archetypes) + resolved `scene_id` bigints.
  - [x] 2.2 `UPDATE ret0.hubs SET scene_id=<bid> WHERE lower(user_data->'chemistry'->>'symbol')='<sym>'`
        over all 118 symbols (idempotent; re-run with `AND scene_id IS NULL` to backfill the
        e2e-suite-created rooms). All 74 chemistry rooms now carry `scene_id`.
  - [x] 2.3 Spot-check: Wasserstoff-Raum (`5Vnt5wx`) and a sampling join with non-null `scene.model_url`.
- [x] 3. Surface + verify the scene on the join path
  - [x] 3.0 **Resolved (discovery corrected):** Hypothesis that `HubView` omits `scene` was
        WRONG — `HubView` already serializes `scene` from the hub's `scene_id` association.
        The actual blocker was GLB **file serving** returning `403` (see below). Once serving
        works, the join returns `scene` with a reachable `model_url` and the client renders.
  - [x] 3.1 `hub.hub.scene` non-null in `hub:join` response (verified live).
  - [x] 3.2 Client receives a reachable `model_url`; `GET` returns `200 model/gltf-binary`
        (no `Failed to load glTF model`).
- [x] 4. Add/extend e2e regression tests
  - [x] 4.1 `e2e/scene-room.spec.ts`: HubView shape regression, `GET /api/v1/scenes/:sid` contract
        (200/404), element-query scene metadata, and a real acceptance test that joins the canonical
        Wasserstoff room (`5Vnt5wx`) and asserts `scene.model_url` is a reachable `model/gltf-binary`.
  - [x] 4.2 `e2e/pse-rooms.spec.ts`: element-query hub carries `scene` with `scene_id`.
  - [x] 4.3 `e2e/file-serving.spec.ts`: regression guards for the GLB/screenshot deployment fix —
        archetype scene metadata carries `/files/` URLs, the scene GLB serves `200 model/gltf-binary`,
        the screenshot serves `200 image/png`, and a missing/forbidden file is NOT `403` (host mismatch)
        or `500` (crash). These lock in the `Ret.Storage` scheme + `passHostHeader` fixes.
  - [x] 4.4 `e2e/infra-health.spec.ts`: reticulum `/health` answers `200` and the dialog signaling
        endpoint is reachable on `:4443` (guards against the dialog silently regressing to
        bridge+NAT port publishing, which hits the VE's netfilter/numiptent quota and fails to start).
- [x] 5. Validate & ship
  - [x] 5.1 `openspec validate themed-element-scenes` clean.
  - [x] 5.3 Restore steps documented in `docs/epics-user-stories.md` (US-2.3 AC).

## Deployment config fixes (required for scenes to load — applied live 2026-08-28)
These are **config, not code** changes; they live in the deployment repos, not in `hubs-compose`:

1. **`Ret.Storage` host needs a scheme.** In the live `reticulum-config.toml`
   (`[ret."Elixir.Ret.Storage"]`) the value was `host = "hubs.chemie-lernen.org"`. `render_file_with_token`
   does `URI.parse(Application.get_env(:ret, Ret.Storage)[:host])` — without a scheme, `URI.parse`
   parses the string as a *path*, so `.host` is `nil`, so `is_storage_host` (`conn.host === nil`)
   is always false → `403`. Fix: `host = "https://hubs.chemie-lernen.org"`.
2. **traefik must forward the public Host.** reticulum's `hubs-api` service needs
   `traefik.http.services.hubs-api.loadbalancer.passHostHeader=true` (added to
   `docker-compose.hubs.yml`). Without it traefik forwarded the backend address, so `conn.host`
   never matched `storage_host`.
3. Restart reticulum to reload config + pick up the label. GLB/PNG now serve `200`.

## Known issues / follow-ups
- **`hubs-dialog` is DOWN (Virtuozzo netfilter exhaustion, side-effect of traefik restarts during
  this work).** `docker start` fails with `iptables: Memory allocation problem` — the VE hit its
  `ve::numiptent`/netfilter memory limit. This is the recurring Epic 6.3 issue. Needs host-level
  cleanup (purge orphan veths/netns + raise the limit), not a code change. Dialog tests
  (`dialog-auth`, `ws-join` dialog) fail until it is recovered. Tracked under classroom/infra.
- `RoomAssigner` should assign `scene_id` on room creation (so e2e-created chemistry rooms are themed
  automatically) — split into a follow-up change-set.
