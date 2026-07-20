# Testing strategy

## Calculator parity validation (2026-07-20)

- `flutter analyze`: no issues.
- `flutter test --reporter compact`: 373 tests passed on the current recorded
  revision.
- Historical coverage baseline: 230 tests and 787/844 instrumented POC
  Core/catalog/application lines (93.25%); it is not the current suite count.
- Desktop and mobile calculator goldens pass.
- `flutter build web --release`: passed; Wasm dry run passed.
- The integration suite covers Original, Beyond and the reviewed Forever
  macrocycle. Chrome and Firefox pass the five current scenarios. Edge remains
  blocked by the Flutter SDK capability described below; Android validation is
  intentionally deferred.

## Core

Pure Dart tests cover estimated one-repetition max, Training Max ratios, kg/lb
progression and rounding, plate loading, configuration compatibility,
deterministic generation, serialization/version rejection, ambiguity blocking,
all three primary generations, Forever transitions, and exclusion of
Powerlifting from `Generation`.

## Catalogue

Tests validate the generated schema, unique stable IDs, known generations,
classification of every imported row, executable strategy links, explicit
non-executable reasons, and zero silently ignored entries.

## Widgets and integration

Widget tests cover generator input, validation, generation result rendering,
configuration restoration/export, generation changes, onboarding reversibility,
recommendations, and onboarding-to-generator prefill. Semantic labels, focus
visibility, narrow layouts, and reduced-motion behavior receive basic checks.

Integration scenarios cover Original, Beyond, and Forever. Each starts in
onboarding, chooses a recommendation, arrives at the prefilled generator,
generates a plan, opens a week/session, and exports JSON.

## Required commands

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
.\tool\build_web_release.ps1 -BaseHref "/"
```

For the reproducible Chrome E2E command, including driver and port parameters,
see [Web release](web-release.md). `flutter test integration_test` alone is not a
browser validation. Android validation is intentionally deferred for this
Forever v2 lot.

## Latest results

- `flutter analyze`: pass, no issues.
- `flutter test --reporter compact`: pass, 373 tests.
- Historical coverage baseline only: 787/844 instrumented POC
  Core/catalog/application lines, 93.25% (230-test suite at that time).
- Branch records: unavailable (`BRF=0`) in the generated LCOV file.
- `flutter build web --release`: pass; Wasm dry run also succeeds.
- Android results belong to an earlier baseline and are not a gate for this lot.
- Visual goldens: pass at 1200×900 desktop and 390×844 mobile.
- Route and exact configuration-mapping tests: pass.
- Browser E2E: Chrome and Firefox execute the checked-in scenarios. Edge and
  EdgeDriver are aligned on `150.0.4078.83`, but Flutter 3.44.6 submits
  `browserName: edge`; EdgeDriver rejects it because it requires
  `MicrosoftEdge`.
