# Testing strategy

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
- `flutter test --coverage`: pass, 190 tests.
- POC Core: 290/303 instrumented lines, 95.71%.
- Branch records: unavailable (`BRF=0`) in the generated LCOV file.
- `flutter build web --release`: pass; Wasm dry run also succeeds.
- Android DEV and PROD debug APK builds: pass.
- Visual goldens: pass at 1200×900 desktop and 390×844 mobile.
- Route and exact configuration-mapping tests: pass.
- Browser E2E: test source contains one full scenario per generation. Execution
  reached WebDriver session creation but was rejected because Edge
  `150.0.4078.65` does not match msedgedriver `150.0.4078.83`.
