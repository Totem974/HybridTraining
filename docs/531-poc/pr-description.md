# PR: Hybrid 5/3/1 single-page calculator backed by Core v5

## Summary

This PR replaces the former landing/onboarding experience with one isolated
Flutter Web calculator at `/poc/531`. Its functional structure follows the
audited reference calculator without copying its code, assets, text, branding,
CSS, or visual identity. All calculations are delegated to pure Dart domain
packages.

## What changed

- Direct single-page calculator with Weight, Template, Additional Options,
  Plating & Barbell, Scheduling, Output, and Program sections.
- 1RM, Training Max, Rep Max and 1+ Set input modes for the four canonical lifts.
- Thirteen classic template families exposed from a typed catalogue, including
  eight BBB variants.
- Reviewed Original/Beyond warm-ups, 5/3/1 and 3/5/1 orders, deloads 1–5,
  high-intensity deload, BBB, Pyramid, FSL, 5's Progression and Simplest
  Strength prescriptions.
- Forever mode backed by Core v5, with reviewed FV-141 and FV-236 definitions,
  Leader/Anchor blocks and typed 7th Week transitions.
- Responsive Hybrid dark/green interface, plate loading, JSON export and
  serialized configuration sharing.
- Removed onboarding page, tests and E2E flow.

## Catalogue truthfulness

- Original, Beyond and Forever are the only primary generations.
- Powerlifting remains a supplement, never a fourth generation.
- All 354 imported rows remain classified in the auditable coverage report.
- A visible calculator family is disabled when its structured prescription is
  insufficient. No missing percentage, set, transition or compatibility rule is
  invented.

## Validation

- `flutter analyze`
- `flutter test --coverage`
- `flutter build web --release`
- responsive calculator visual checks

## Known limits

- Several reference families remain documentary until their full prescriptions
  are encoded from the sources; they are visible but cannot generate a plan.
- Joker sets remain a runtime decision after the performance set. The calculator
  stores and validates the policy but does not pretend the athlete's live result
  is known in advance.
- No backend, account, payment, medical advice or outcome guarantee is included.
