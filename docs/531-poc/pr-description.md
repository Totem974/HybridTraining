# PR: isolated Hybrid 5/3/1 Core, Web generator, and onboarding POC

## Summary

This PR adds an isolated Flutter Web proof of concept on top of the existing
Core v5. It provides a pure Dart public facade, an auditable catalogue import,
a CORE-backed generator, and a ten-step onboarding journey that hands the exact
validated configuration to the generator.

## Architecture

- Reuses the existing Core v5; no second engine or Web framework.
- Keeps business rules under `lib/features/poc_531/domain/` with no Flutter,
  browser storage, SQLite, or global UI dependency.
- Adds immutable catalogue data under `lib/features/poc_531/catalog/` and a
  reproducible importer under `tool/531_catalog/`.
- Adds isolated routes under `/poc/531` while preserving the existing default
  validation shell.
- Adds Flutter Web scaffolding only; no backend, account, or database.

## Functional scope

- Original — Second Edition, Beyond, and Forever remain the only primary
  generations.
- Powerlifting is modelled only as a supplement and requires an explicit
  extension option at Core level.
- Supports 1RM, Training Max, and rep-max inputs, kg/lb, rounding, plate loading,
  validation, deterministic recommendations, generation, explanations, and
  versioned serialization.
- Displays blocks, weeks, sessions, prescriptions, loads, sources, warnings,
  transitions, plate loading, JSON export, configuration copy, reset, example,
  and print guidance.
- Uses a responsive template-first calculator layout. Selecting a template
  derives its generation provenance; unsupported documentary options are shown
  locked rather than behaving as decorative controls.

## Catalogue truthfulness

- 354 rows imported and classified.
- 329 primary-generation rows: 40 Original, 107 Beyond, 182 Forever.
- 25 Powerlifting supplement rows.
- 4 imported executable templates linked to reviewed Core v5 strategies.
- 350 rows explicitly blocked as ambiguous `NEEDS_REVIEW`.
- Classification coverage is complete; executable coverage is intentionally not
  claimed as complete.

## Validation

- `flutter analyze`: passes.
- `flutter test --coverage`: 193 tests pass.
- POC Core line coverage: 95.71% (290/303 instrumented lines); the LCOV emitter
  provides no branch records in this environment.
- `flutter build web --release`: passes, including Wasm dry run.
- Android DEV and PROD debug APK builds: pass.
- Desktop/mobile golden generation: passes after correcting a mobile dropdown
  overflow.
- Three E2E scenarios are checked in for Original, Beyond, and Forever. Browser
  execution is environment-blocked because Edge is `150.0.4078.65` and the
  supplied driver is `150.0.4078.83` (`No matching capabilities found`).

## Review focus

- Catalogue classifications and the 350 explicit ambiguity reasons.
- Original compatibility strategy provenance.
- Forever Leader/Anchor and typed 7th Week output.
- Onboarding-to-generator transport mapping.
- Responsive behavior and semantic labels.

## Known limits

- The catalogue is not fully executable; missing source prescriptions are never
  inferred.
- Supplemental/assistance/conditioning selectors currently reflect the reviewed
  program definition rather than exposing invented free combinations.
- Browser E2E needs a WebDriver version matching the installed browser.
- No medical advice or outcome guarantee is provided.
