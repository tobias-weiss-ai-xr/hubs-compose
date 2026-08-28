# Capability: classroom-moderation

Teachers running element rooms must be able to control entry and remove disruption.

## ADDED Requirements

### Requirement: Entry approval
The system SHALL support an `entry_mode: request` where joining users enter a pending queue
until a moderator approves.

- **WHEN** a room is in `entry_mode: request` and a user joins
- **THEN** the join is held pending and a moderator can approve/deny

### Requirement: Moderator mute
A moderator SHALL be able to mute a participant's audio/video; the participant sees the
status.

- **WHEN** a moderator mutes a participant
- **THEN** the participant's stream is disabled and they see "muted by moderator"

### Requirement: Moderator kick (perms-token gated)
A moderator SHALL be able to kick a participant via the dialog `kick` protoo request, which
requires a valid RS512 perms token with the `kick_users` claim.

- **WHEN** a `kick` request is sent with a valid perms token
- **THEN** the peer is closed (peer-closed)
- **WHEN** a `kick` request is sent without a valid token
- **THEN** the request is rejected and the peer stays

### Requirement: Room close
A teacher SHALL be able to close/delete a room; later joins are refused.

- **WHEN** a room is closed/deleted
- **THEN** subsequent `hub:<sid>` joins are refused (no-such-hub)

## ADDED Scenario: disruptive student removed
- **GIVEN** a teacher is moderator of a room
- **WHEN** they kick a disruptive student via the dialog protoo `kick` with a valid perms token
- **THEN** the student's peer closes and they can't rejoin until allowed
