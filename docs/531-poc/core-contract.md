# Public Core contract

The POC exposes a pure Dart facade with the following responsibilities:

- catalogue discovery: `getCatalogSummary`, `listGenerations`, `listPrograms`,
  `getProgramDefinition`, and `getCatalogCoverageReport`;
- calculations: `calculateEstimatedOneRepMax`, `deriveTrainingMax`, and
  `calculatePlateLoading`;
- decisions: `validateProgramConfiguration`, `recommendPrograms`, and
  `explainRecommendation`;
- generation: `generateProgram` and `explainGeneratedProgram`;
- transport: `serializeProgram` and `deserializeProgram`.

`Generation` contains only `original`, `beyond`, and `forever`. Powerlifting is
represented through `SourceKind.supplement` and an explicit extension flag.

Lift inputs use discriminated modes for one-repetition max, training max, and a
load/repetitions estimate. Validation returns structured issues with stable code,
severity, field path, human-readable message, and optional provenance. It does
not silently correct incompatible combinations.

Generation returns a versioned immutable plan containing blocks/cycles, weeks,
sessions, prescriptions, calculated and unrounded loads, rounding metadata,
assistance/conditioning when supported, typed transitions, provenance, warnings,
and decision explanations. Failure is a structured result rather than a partial
plan.

The contract is usable from Dart tests and future backend, mobile, or CLI
adapters without importing Flutter.

