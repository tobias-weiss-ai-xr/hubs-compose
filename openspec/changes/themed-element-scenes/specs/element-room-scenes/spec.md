# Capability: element-room-scenes

Element rooms on hubs.chemie-lernen.org must load a themed 3D scene instead of an empty void.

## ADDED Requirements

### Requirement: Every element room has an assigned scene
The system SHALL assign each chemistry/element room a scene from the set of archetype scenes
(ElementRoom, PeriodicPavilion, LabWing, ExperimentalRoom, Lobby) according to
`symbol_to_archetype.json`, so that `hub.scene` is non-null on join.

- **WHEN** a chemistry room is queried or joined
- **THEN** `response.hubs[0].scene` is populated with a valid scene (scene_id + reachable `model_url`)

#### Scenario: restored Wasserstoff room surfaces a scene
- **GIVEN** the 5 archetype scenes are restored into live `ret_dev`
- **AND** all chemistry rooms have a `scene_id` assigned
- **WHEN** a client joins the Wasserstoff room (`5Vnt5wx`)
- **THEN** `response.hubs[0].scene.model_url` points at a served `.glb`

### Requirement: Archetype scenes are available in live storage
The system SHALL store the 5 archetype GLB scenes in live `ret_dev` (scenes + scene_listings
owned by an educator account) and serve them via `GET /api/v1/scenes/:sid` (200).

- **WHEN** a client requests `GET /api/v1/scenes/:sid` for a known archetype sid
- **THEN** the response is 200 with the scene metadata

#### Scenario: archetype scene fetch returns 200
- **GIVEN** the ElementRoom scene was restored with sid `mhezdAw`
- **WHEN** a client requests `GET /api/v1/scenes/mhezdAw`
- **THEN** the response status is 200

### Requirement: Join returns scene so the client loads the GLB
The `hub:join` Phoenix channel response SHALL include the scene so the Hubs client loads the
model (no `Failed to load glTF model` error).

> **Implementation note (2026-08-28):** `HubView` already serializes `scene` from the hub's
> `scene_id` association — no code change was required. The real blocker for rendering was GLB
> **file serving** (`403`): `Ret.Storage` host needs a scheme (`https://…`) and traefik must
> `passHostHeader=true` so the public Host reaches reticulum. See tasks.md "Deployment config fixes".

- **WHEN** a client joins `hub:<sid>`
- **THEN** `response.hubs[0].scene` is non-null and references a loadable GLB

#### Scenario: join response carries a loadable scene
- **GIVEN** the room has a `scene_id` assigned
- **WHEN** a client joins the room
- **THEN** `response.hubs[0].scene.model_url` is a URL the client can `GET` for `200 model/gltf-binary`

### Requirement: Scene load budget
The selected scene GLB SHALL load within 5 seconds on a mid-range laptop.

- **WHEN** a room with an assigned scene is joined on a mid-range laptop
- **THEN** the scene is interactive within 5 s

#### Scenario: themed scene renders without error
- **GIVEN** the room's `scene.model_url` serves `200 model/gltf-binary`
- **WHEN** the Hubs client loads the room
- **THEN** the 3D scene renders (not an empty gray space)
- **AND** no `Failed to load glTF model` console error is logged
