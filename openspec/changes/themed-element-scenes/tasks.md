# Tasks — Themed 3D scenes for every element room

- [ ] 1. Restore archetype scenes into live `ret_dev`
  - [ ] 1.1 Mint/obtain owner token (from private `hubs-compose-state`, never public)
  - [ ] 1.2 Upload 5 GLBs (v2) from `tools/pse-rooms/scenes/` via reticulum scene API
  - [ ] 1.3 Verify `scenes` / `scene_listings` rows exist and `GET /api/v1/scenes/:sid` returns 200
- [ ] 2. Map element rooms → scenes
  - [ ] 2.1 Load `symbol_to_archetype.json` + `scene_sids_v2.json`
  - [ ] 2.2 Run `assign_hubs.py` (or server-side default) over the 171 element rooms
  - [ ] 2.3 Spot-check: Wasserstoff-Raum (`5Vnt5wx`) and a sampling across the table have `hub.scene` set
- [ ] 3. Verify the join path serves the scene
  - [ ] 3.1 `hub.hub.scene` non-null in `hub:join` response
  - [ ] 3.2 Client no longer logs `Failed to load glTF model`; scene renders in <5 s
- [ ] 4. Add/extend e2e regression tests
  - [ ] 4.1 `e2e/ws-join.spec.ts`: after hub join, assert `response.hubs[0].scene` populated
  - [ ] 4.2 `e2e/pse-rooms.spec.ts`: element-query hub carries `scene` with `scene_id`
- [ ] 5. Validate & ship
  - [ ] 5.1 `openspec validate themed-element-scenes`
  - [ ] 5.2 Run full `npx playwright test` against live → green (currently 25/25, must stay)
  - [ ] 5.3 Document restore steps in `docs/epics-user-stories.md` (US-2.3 AC)

## Notes
- The recovered DB dump (`hubs-compose-state/db-dump/ret_dev_full_*.sql`) can be imported
  into a throwaway `ret_dev` to dry-run the mapping before touching live.
- Do NOT push owner token / private keys to public `hubs-compose`.
