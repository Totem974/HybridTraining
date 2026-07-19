# Final Core v5 readiness report — 2026-07-19

## Scope and revision

- Starting branch head: `6ee747a`.
- Branch: `rebuild/forever-engine-core-20260719`.
- Remote: `GitHub`; GiTea remained unused.
- Final branch SHA is reported in the release handoff after the report commit.

## Delivered architecture

The active product path now has one canonical program library, one extensible
multi-generation domain, one generation-neutral orchestrator, one v5 persisted
plan representation, and one unified workout execution repository. Historical
catalogs, generators, tables, and the v3 runtime remain compatibility-only paths
for migration and old backup proof; they are not used to select or execute new
plans.

Core v5 preserves programming weeks, events, transitions, source edition,
ruleset generation, typed 7th Week purpose, generic prescriptions/results, TM
timeline decisions, amendments, and rule provenance. Future amendments and TM
decisions preview before atomic application and do not rewrite completed or active
history without an explicit disposition.

## Executable reference programs

- Powerlifting Standard four-week cycle.
- Beyond two three-week cycles plus deload, with a real second-cycle TM change.
- Forever Original + FSL: two Leaders, Deload, Anchor, and final TM Test.
- Beginner Prep School: A/B three-day sessions, two main movements, 5’s Pro,
  FSL/SSL, warm-up, jumps, assistance, and conditioning.

Each has a deterministic JSON golden containing structure, dates, loads, TM
timeline, transitions, events, and provenance. Other library entries remain
documentary unless their explicit availability and implementation status allow
generation; `NEEDS_REVIEW` is rejected.

## Persistence, migration, and backup

SQLite v5 is additive and covers v1→v5, v2→v5, v3→v5, and v4→v5, including
transactional rollback tests. Native backup v5 and import compatibility for v1–v4
are covered by export, dry-run simulation, atomic apply, and reopen tests. Legacy
tables are retained because removing them before compatibility is no longer needed
would violate the migration contract.

## Cleanup

The root README and eight active Core v5 contracts replace the contradictory
documentation set. Eighty-six historical files moved to
`docs/archive/legacy-2026-07-19/`. No PDFs, `.SOURCE/` files, protected assets,
decompiled code, secrets, screenshots, or personal data were added. The POC and
product onboarding were not integrated; PROD exposes no fixture/demo action.

## Verification results

- `flutter pub get`: passed.
- `dart format --set-exit-if-changed .`: passed; 95 Dart files checked.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 158 tests.
- `flutter test --coverage`: passed, 158 tests.
- Coverage: 88.00% overall lines; 96.61% for the canonical pure-domain set
  (1,113/1,152 lines), above the 95% critical-domain floor.
- `flutter build apk --debug --flavor dev -t lib/main_dev.dart`: passed;
  `app-dev-debug.apk` built.
- `flutter build apk --debug --flavor prod -t lib/main_prod.dart`: passed;
  `app-prod-debug.apk` built.
- Android target: Redmi Note 7, Android 13/API 33, connected over wireless ADB.
- Initial wireless runs showed that the app launched and exposed a VM service,
  but Flutter did not discover the random port. The DEV-only Android manifest now
  assigns port `42424`; PROD is unaffected.
- `flutter drive --driver=test_driver/integration_test.dart
  --target=integration_test/app_flow_test.dart -d
  adb-fb5709d-2Bp9K8._adb-tls-connect._tcp --flavor dev
  --device-vmservice-port 42424 --host-vmservice-port 42425 --no-dds`: passed on
  the physical Android 13 device. The complete scenario took 58 seconds.

## Remaining limitations and verdict

All repository, persistence, golden, runtime, lifecycle, coverage, APK, and
physical Android gates pass. Historical compatibility adapters and tables remain
deliberately isolated until a later schema can remove them without breaking old
backup restores. Documentary library entries still require source review before
they can become executable; none is incorrectly advertised as available.

`CORE READY FOR PRODUCT UI`
