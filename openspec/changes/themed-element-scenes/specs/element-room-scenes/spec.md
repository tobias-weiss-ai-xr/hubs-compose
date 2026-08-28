# Capability: element-room-scenes

Element rooms on hubs.chemie-lernen.org must load a themed 3D scene instead of an empty void.

## ADDED Requirements

### Requirement: Every element room has an assigned scene
The system SHALL assign each element room a scene from the set of archetype scenes
(ElementRoom, PeriodicPavilion, LabWing, ExperimentalRoom, Lobby) according to
`symbol_to_archetype.json`, so that `hub.scene` is non-null on room creation/query.

- **WHEN** an element room is created or queried
- **THEN** the room's `hub.scene` field is populated with a valid scene (id + base.gltf)

### Requirement: Archetype scenes are available in live storage
The system SHALL store the 5 archetype GLB scenes in live `ret_dev` (scenes + scene_listings
owned by an educator account) and serve them via `GET /api/v1/scenes/:sid` (200).

- **WHEN** a client requests `GET /api/v1/scenes/:sid` for a known archetype sid
- **THEN** the response is 200 with the scene metadata

### Requirement: Join returns scene so the client loads the GLB
The `hub:join` Phoenix channel response SHALL include the scene so the Hubs client loads the
model (no `Failed to load glTF model` error).

- **WHEN** a client joins `hub:<sid>`
- **THEN** `response.hubs[0].scene` is non-null and references a loadable GLB

### Requirement: Scene load budget
The selected scene GLB SHALL load within 5 seconds on a mid-range laptop.

- **WHEN** a room with an assigned scene is joined on a mid-range laptop
- **THEN** the scene is interactive within 5 s

## ADDED Scenario: element room join shows themed scene
- **GIVEN** the archetype scenes are restored and mapped
- **WHEN** a student joins the Wasserstoff room (`5Vnt5wx`)
- **THEN** they see a rendered 3D scene (not an empty gray space)
- **AND** no `Failed to load glTF model` console error is logged
