# Capability: avatars

Element-room users should choose a recognizable avatar instead of the default grey robot.

## ADDED Requirements

### Requirement: Restored avatar catalog
The system SHALL provide a catalog of curated avatars restored from the recovered data
(24 avatars), listed via `avatar_listings`.

- **WHEN** a user opens the avatar picker
- **THEN** the 24 recovered avatars are available to choose from

### Requirement: Avatar glTF served
The system SHALL serve each avatar's model via `GET /api/v1/avatars/:id/avatar.gltf` (200).

- **WHEN** a client requests a known avatar's glTF
- **THEN** the response is 200 with the model

### Requirement: Optional custom upload
The system SHALL allow uploading a new avatar with an owner token via `POST /api/v1/avatars`.

- **WHEN** an educator posts a glTF with a valid owner token
- **THEN** the avatar is stored and served from its `avatar.gltf` endpoint

## ADDED Scenario: student picks a recovered avatar
- **GIVEN** the avatar catalog is restored
- **WHEN** a student opens the picker and selects an avatar
- **THEN** their in-room representation uses that avatar (not the default robot)
