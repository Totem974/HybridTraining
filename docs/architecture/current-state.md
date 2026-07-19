# Current state

The active application starts directly in the Core Validation Shell. The
rejected onboarding, dashboard, visual calendar, visual program library and
guided workout presentation were removed from the compiled source tree.

The active dependency direction is:

```text
Core Validation presentation
  -> application use cases and repository interfaces
  -> pure Dart program and plan domain
  <- SQLite repository implementations
```

Beginner Prep School v1 is the only executable preset. Its generation flows
through `GenerateBeginnerPlan`, `ForeverMacrocycleGenerator`,
`VersionedTrainingPlan` and `PlanRepository`. Original + FSL remains available
only to the isolated legacy persistence compatibility path and cannot be
selected by the active application.

SQLite schema v3 is still in use. The v1 tables remain readable for migration
and backup compatibility; new shell plans use the versioned v2/v3 tables.
