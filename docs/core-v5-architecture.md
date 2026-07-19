# Core v5 architecture

The active flow is `ProgramLibrary` → `CanonicalPlanGenerator` →
`VersionedTrainingPlan` → `SqliteVersionedPlanStore` → `WorkoutExecution`.
Application use cases sit above repository contracts; Flutter widgets do not own
training rules. The pure Dart domain has no Flutter, SQLite, clock, or device
dependency.

The library is the single source of availability and source metadata. The
generation-neutral orchestrator dispatches only complete, versioned blueprints.
Persisted plans retain their immutable definition snapshot, generated weeks,
events, transitions, protocol types, and TM timeline. The unified runtime reads
legacy loaded-set rows and v5 generic prescriptions through one ordered execution
model and writes an append-only event journal with each atomic mutation.

Legacy catalogs, generators, and runtime tables remain compatibility surfaces for
migration and backup reads only. They are not product-selection or active plan
execution paths.
