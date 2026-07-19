# Forever engine core rebuild - 2026-07-19

## Baseline

| Check | Result |
| --- | --- |
| `flutter pub get` | PASS |
| `dart format --set-exit-if-changed .` | PASS, 71 files unchanged |
| `flutter analyze` | PASS, no issues |
| `flutter test` | PASS, 112 tests |
| Dev debug APK | PASS |
| Prod debug APK | PASS |
| Redmi Note 7 integration baseline | FAIL |

The existing integration test fails at `integration_test/app_flow_test.dart:126`:
it expects `overheadPress` but reads `deadlift`. This is a captured baseline defect;
it must not be hidden. The test also exercises the rejected onboarding and will be
replaced by the core validation flow with an explicit regression test.

## Audit decisions

- The v1 stack is the only production-connected path. The v2 program domain,
  versioned plan store and composable workout runtime are tested but disconnected.
- v2 is the canonical target. v1 remains only as a temporary compatibility and
  migration path until end-to-end tests prove replacement safety.
- Original 5/3/1 and Original + FSL remain non-executable while conditioning,
  rounding and transition rules are incomplete.
- Beginner Prep School is `READY_TO_IMPLEMENT`, but its two catalogues and rule
  references must be reconciled before exposure.
- The Original/Classic book is still absent. `531_Powerlifting.pdf` is a readable
  2011 Powerlifting work, not a substitute for Original/Classic.
- Persisted v1 and v2/v3 workout state currently form two unsynchronised sources
  of truth. Program switching, ordered undo and actual-load statistics require
  explicit application services and transactional tests.

## Current status

Implementation has not yet been declared complete. No source reference was
modified, copied into the product, or committed. No remote write occurred.

