# Tasks — Restore avatar catalog

- [ ] 1. Inventory recovered assets
  - [ ] 1.1 List 24 avatars in legion DB dump (`hubs-compose-state/db-dump/ret_dev_full_*.sql`)
  - [ ] 1.2 Map the 76 storage blobs (`storage/*.blob` + `meta.json`) to the 24 avatars
- [ ] 2. Dry-run restore on backup `ret_dev`
  - [ ] 2.1 Import avatar rows + avatar_listings on a throwaway DB
  - [ ] 2.2 Verify `GET /api/v1/avatars/:id/avatar.gltf` returns the model
- [ ] 3. Promote to live
  - [ ] 3.1 Apply restore to live `ret_dev` (verified, non-destructive)
  - [ ] 3.2 Confirm `avatar_listings` populated; picker shows the 24 avatars
- [ ] 4. Optional: school mascot upload
  - [ ] 4.1 `POST /api/v1/avatars` with owner token; upload glTF
  - [ ] 4.2 Verify served from `/api/v1/avatars/:id/avatar.gltf`
- [ ] 5. e2e coverage
  - [ ] 5.1 `e2e/pse-rooms.spec.ts` (or new `avatars.spec.ts`): avatar_listings non-empty; glTF 200
- [ ] 6. Validate & ship
  - [ ] 6.1 `openspec validate avatars-restore`
  - [ ] 6.2 `npx playwright test` green against live (currently 25/25)

## Notes
- Secrets/private data stay in private `hubs-compose-state`; public `hubs-compose` gets no
  blobs/keys/tokens.
- Use the bundle reassembled from `bundle.chunk.*` (SHA256 `c9ebff03…`) to import if running
  from the bundle instead of the SQL dump.
