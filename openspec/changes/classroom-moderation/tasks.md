# Tasks — Classroom & moderator controls

- [ ] 1. Entry-mode approval flow
  - [ ] 1.1 Add `entry_mode: request` handling in `HubView`/create (reticulum)
  - [ ] 1.2 Pending-join queue + moderator approve/deny channel events
  - [ ] 1.3 Client UI for approve/deny (host view)
- [ ] 2. Moderator mute/kick
  - [ ] 2.1 Mint perms token with `kick_users` claim via `GUARDIAN_SECRET_KEY` (RS512, `AUTH_KEY`)
  - [ ] 2.2 Wire dialog `kick` protoo request to require/verify the token (`/etc/perms.pub.pem`)
  - [ ] 2.3 Client: moderator can mute audio/video; student sees "muted by moderator"
  - [ ] 2.4 Client: moderator kick removes participant (peer-closed)
- [ ] 3. Room close/delete
  - [ ] 3.1 `DELETE /api/v1/hubs/:id` teardown; joins after close refused (no-such-hub)
  - [ ] 3.2 Teacher "End lesson" button -> close room
- [ ] 4. Safety briefing overlay
  - [ ] 4.1 Configurable text shown on first join (lobby/scene UI)
- [ ] 5. e2e regression coverage
  - [ ] 5.1 `e2e/ws-join.spec.ts` or new `moderation.spec.ts`: kick requires valid perms token
  - [ ] 5.2 Dialog `kick` without token -> rejected (no remove)
  - [ ] 5.3 Closed room join -> refused
- [ ] 6. Validate & ship
  - [ ] 6.1 `openspec validate classroom-moderation`
  - [ ] 6.2 `npx playwright test` green against live (currently 25/25)

## Notes
- Do NOT commit `GUARDIAN_SECRET_KEY` / private keys to public `hubs-compose`; use private
  `hubs-compose-state`.
- Perms token minting helper can live in `tools/pse-rooms/scripts/` (reads secret from env).
