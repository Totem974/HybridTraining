# Core v5 logical schema

Core v5 is additive. V1–v4 tables remain for migration and backup compatibility.
`training_plans`, `training_blocks`, cycles, and sessions preserve source edition,
ruleset generation, structural type, role, protocol purpose, programming numbers,
and calendar position. Each plan references its immutable definition snapshot.

`activity_prescriptions` and `activity_results` are the canonical generic
prescription/result pair. They cover loaded and unloaded work while retaining
movement/activity ID, target type and JSON, rule identity, source, calculated and
unrounded load, RPE, notes, and timestamps. Existing `set_prescriptions` and
outcomes remain readable by the unified runtime.

`training_max_timeline`, `plan_amendments`, `plan_transitions_v5`, and
`planned_events_v5` preserve decisions and history without flattening programming
weeks. Workout executions and their ordered event journal support exact resume and
atomic mutation.
