# POC progress

## Checkpoint 1 — complete

- Three read-only audits completed: repository, domain, and catalogue.
- Dirty user working tree preserved.
- Dedicated branch and worktree created from Core v5.
- Flutter Web selected; no second framework or Core.
- Source counts verified: 329 primary-generation rows plus 25 Powerlifting
  supplement rows.

## Checkpoint 2 — complete

- Public pure-Dart facade and typed contracts implemented.
- Reproducible catalogue import, generated manifest, and coverage report added.
- Targeted catalogue tests pass; full catalogue remains 354/354 classified.

## Checkpoint 3 — complete

- Deterministic vertical generation implemented for Original, Beyond, and
  Forever by orchestrating reviewed Core v5 rules.
- Unit, Training Max, plate loading, validation, recommendation, serialization,
  transitions, and ambiguity behavior covered by unit tests.

## Checkpoint 4 — complete

- 354 source rows classified: 4 executable and 350 blocked `NEEDS_REVIEW`.
- Every executable catalogue row references a registered Core v5 strategy.
- Powerlifting remains a supplement and is excluded from primary generations.
- Targeted Core and catalogue test suites pass.

## Checkpoint 5 — complete

- Responsive Flutter Web generator added with live CORE validation.
- Results, provenance, warnings, plate loading, JSON export, configuration copy,
  example, reset, and print guidance are available.
- Generator widget tests pass.

## Checkpoint 6 — complete

- Ten-step reversible onboarding added.
- Recommendations and final configuration use the same public CORE API.
- Onboarding widget tests pass, including the validated hand-off value.

## Checkpoint 7 — complete

- Isolated routes and landing page integrated without changing the default
  validation-shell route.
- Flutter Web scaffolding added and release build passes.
- Route and configuration transport tests pass.
- E2E scenarios for Original, Beyond, and Forever are checked in. Browser
  execution currently requires an Edge/Chrome WebDriver on port 4444; Android
  fallback execution timed out while installing on the connected device.

## Checkpoint 8 — complete

- Full formatting, static analysis, unit/widget/golden suite, Web release build,
  and Android DEV/PROD debug builds pass.
- 190 tests pass; POC Core line coverage is 290/303 (95.71%).
- Desktop and mobile golden states cover landing, onboarding, and generator.
- Browser E2E scenarios are implemented for all three generations; execution is
  blocked externally by the Edge 150.0.4078.65 / driver 150.0.4078.83 mismatch.

## Checkpoint 9 — complete

- Final read-only QA review completed and high-priority findings corrected.
- Future Training Max projection is now an explicit option.
- Decorative configuration choices were removed or disabled, catalogue
  duplicates were eliminated, and URL/JSON restoration was completed.
- The final regression suite and release/debug builds pass after the fixes.

## Template-first UX iteration — complete

- The public reference calculator was exercised in a clean browser session.
- Thirteen visible template families and their conditional variant controls
  were inventoried without copying source assets or presentation code.
- CORE gap analysis confirmed that five strategies are currently executable;
  advanced warm-up, Joker, deload, scheduling, and free Forever composition
  remain documentary and must stay explicitly unavailable.
- Generator presentation is being reorganized around lift inputs, template and
  variant, compatible options, scheduling, equipment, and program output.
- The template is now the primary program choice; generation is derived and
  displayed as provenance.
- Unsupported advanced options are visible but locked with an explicit CORE
  coverage explanation.
- Static analysis, 193 tests, updated desktop/mobile goldens, Web release, and
  Android DEV/PROD debug builds pass.

## Calculator parity iteration — complete

- The onboarding and landing flows were removed; `/poc/531` now opens one
  calculator page directly.
- The page follows the reference calculator's functional information
  architecture with an original Hybrid visual identity.
- 1RM, Training Max, Rep Max and 1+ Set inputs use shared Core calculations.
- Thirteen classic template families are catalogued. Reviewed prescriptions are
  executable; ambiguous families stay visible and disabled with a reason.
- Original/Beyond warm-ups, deloads 1–5 and high-intensity deload generate
  numeric prescriptions. Joker policy is a non-blocking runtime warning.
- Forever exposes reviewed definitions and the fixed Leader → 7th Week → Anchor
  sequence.

## Source-calculator parity correction — complete

- Audited the supplied `sitecalculator.tar` compiled React application and
  ported its structured behavior into the pure Dart calculator engine.
- Weight follows the source's three modes: editable rep-max input under
  `1 Rep Max`, direct Training Max, and 1+ Set derived at 95% of TM.
- Palette and page width use the source values (#181818, #323232, #727272,
  #f0f0f0 and #2c9eff) while retaining Hybrid branding and Flutter components.
- Triumvirate, Periodization Bible and Bodyweight are executable with sourced
  assistance mappings; Bodyweight exposes total reps and set count.
- Simplest Strength renders supplemental exercise names and assistance blocks.
- FSL Multiple Sets exposes and applies its set and repetition ranges.
- German Volume Training exposes same/per-lift ratios and the alternate-lift
  switch, and generates its sourced 10x10 prescription.
- Joker targets are generated every +5% through the selected cap.
- Empty executable-variant lists cannot create an empty `SegmentedButton`.
- Forever sessions render readable prescriptions instead of raw JSON cards.

## Calculator interaction and Forever repair — complete

- The complete plate inventory from 50 to 0.125 is available.
- Lift scheduling uses accessible numbered drag targets; Bastard work order is
  carried into the classic engine and changes the generated main-work order.
- BBB exposes its variants plus shared or per-lift supplemental ratios.
- Bodyweight displays the exact set distribution, and single-definition
  templates no longer display a meaningless Variant control.
- Simplest Strength accepts its four secondary max inputs with rep-max or direct
  Training Max modes; For Beginners exposes its Intermediate switch.
- Forever rendering now preserves blocks, cycles, weeks, sessions and nested
  prescriptions. Stale asynchronous Classic results can no longer overwrite a
  newly selected Forever program.
- Three-session weeks distribute their cards across the complete available
  width. Text and reorder-chip contrast were strengthened.
- Final validation: static analysis clean, 228 tests passed, Web release build
  passed, and POC Core/catalog/application line coverage is 93.25%.
