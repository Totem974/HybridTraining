# Workspace database v2

`workspace.db` version 2 closes the persistence contract needed before an
adapter can build a generic `EngineRequest`. It stores user choices and catalog
coordinates; it does not make a draft executable. The future adapter must still
resolve every catalog ID against the exact published catalog version and reject
an incomplete or incompatible draft.

## Draft identity and provenance

Every `workspace_drafts` row carries all three catalog coordinates:
`catalog_version_id`, `catalog_content_hash`, and
`catalog_canonicalization_version`. `payload_schema_version` versions the local
draft payload independently. Both versions are positive, identifiers and hashes
are non-empty, and `payload_json` must be valid JSON.

The v1-to-v2 migration assigns version `1` to the two previously implicit v1
formats. Migration is transactional and records recoverable anomalies in
`workspace_migration_quarantine` with source and target schema versions,
athlete/entity IDs, a stable issue code, the original row as valid JSON, the
verbatim original draft payload when applicable, and an explicit
`pending`/`acknowledged` state.

An invalid v1 draft is not copied into the constrained v2 draft table. Its whole
row and unmodified payload are quarantined under
`workspace_draft.invalid_json`, while valid drafts and unrelated workspace data
remain accessible. Empty legacy catalog coordinates follow the same path under
`workspace_draft.invalid_catalog_coordinate`. Nothing is silently discarded.

If a v1 athlete has several default gyms, every gym is preserved and every
conflicting row is reported under `gym.multiple_defaults`. The migration clears
all of that athlete's default flags before installing the v2 unique index. It
deliberately chooses no winner: selecting one by row order, name, or identifier
would create a user preference that does not exist in the source data.

## Rounding and equipment

`athlete_profiles.rounding_increment` is optional persisted input constrained to
a positive number. `NULL` means “not configured”; it is not a numeric default.
An adapter must reject a generation request without a resolved positive
increment.

`workspace_draft_equipment` records an explicit gym and bar choice for one
draft. Composite foreign keys ensure that the gym belongs to the draft athlete
and the bar belongs to that gym. There can be at most one default gym per
athlete. An absent equipment row means that no choice was made; the adapter must
not infer the default gym or the first bar.

Inventory quantities have these storage semantics:

- `bars.quantity` is the total number of interchangeable physical bars
  represented by that row. A selected bar contributes the row's `weight` once
  to a single loading calculation.
- `plates.quantity` is the total number of individual physical plates, not a
  number of pairs. A symmetric per-side loader can therefore use at most
  `quantity ~/ 2` matching pairs. An odd remainder stays recorded but is not a
  complete pair.
- Units remain explicit on every bar and plate. No conversion or compatibility
  is implied by sharing a gym.

Equipment IDs and supported load kinds are separate child rows, so sets and
ordering are not inferred from JSON object keys.

## Assistance and conditioning

Assistance stores the selected plan ID, slot and movement IDs, deload mode, and
regular/deload prescriptions in relational rows. Repetition shape and load shape
have explicit discriminators and constrained numeric fields. Conditioning stores
ordered definition IDs, modality, target, work duration, and rest duration.

These tables mirror the data shapes requested by the pure-Dart engine without
copying catalog definitions into the workspace. A draft may be incomplete while
it is edited. Before generation, the adapter must fail closed unless:

- every ID resolves inside the draft's exact catalog coordinates;
- every assistance selection satisfies the resolved slot bounds;
- a `custom` assistance deload has exactly one deload prescription and other
  modes have none;
- equipment capabilities, units, bar, and plates satisfy the selected movement;
- conditioning modality is allowed by its resolved definition; and
- all required training-max inputs and the rounding increment are present.

Those are validation responsibilities at the adapter/domain boundary, not
defaults supplied by SQLite.
