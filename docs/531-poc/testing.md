# Testing strategy

## Calculator parity validation (2026-07-20)

- `flutter analyze`: no issues.
- `flutter test --coverage`: 230 tests passed.
- POC Core/catalog/application line coverage: 787/844, or 93.25%.
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
flutter test --coverage
flutter build web
flutter test integration_test
```

Android dev/prod debug builds remain required when shared bootstrap or navigation
changes affect the existing application.

## Latest results

- `flutter analyze`: pass, no issues.
- `flutter test --coverage`: pass, 230 tests.
- POC Core/catalog/application: 787/844 instrumented lines, 93.25%.
- Branch records: unavailable (`BRF=0`) in the generated LCOV file.
- `flutter build web --release`: pass; Wasm dry run also succeeds.
- Android DEV and PROD debug APK builds: pass.
- Visual goldens: pass at 1200×900 desktop and 390×844 mobile.
- Route and exact configuration-mapping tests: pass.
- Browser E2E: Chrome and Firefox execute the checked-in scenarios. Edge and
  EdgeDriver are aligned on `150.0.4078.83`, but Flutter 3.44.6 submits
  `browserName: edge`; EdgeDriver rejects it because it requires
  `MicrosoftEdge`.
