# Discovery — POC 5/3/1

## Repository baseline

The initial working tree at `D:\GitHub\HybridTraining` is a dirty Android
skeleton and was left untouched. The POC branch is based on the clean Core v5
commit `610b60a` from `rebuild/forever-engine-core-20260719` because that line
already contains the reusable Dart domain, executable generators, provenance,
serialization, persistence adapters, and tests.

The isolated worktree is `C:\tmp\HybridTraining-531-poc` on branch
`poc/531-core-web-onboarding`.

## Existing stack and architecture

- Flutter and Dart, with a feature-first layout under `lib/features/`.
- Pure Dart business rules under `lib/features/programs/domain/`.
- Flutter widget tests and `integration_test` for user journeys.
- No JavaScript package manager or existing React application.

The POC therefore uses Flutter Web and extends the existing Core. Introducing a
second Web framework or a competing 5/3/1 engine would violate repository
conventions and create duplicated business rules.

## Existing executable coverage

Core v5 exposes four reviewed executable reference plans:

- Powerlifting Standard, a supplement rather than a primary generation;
- Beyond, two cycles and deload;
- Forever Original + FSL, two Leaders, a typed 7th Week deload, an Anchor, and a
  typed final TM test;
- Beginner Prep School, classified under Forever.

Original coverage is available through the existing canonical Original/FSL
generator. Documentary entries and rules marked `NEEDS_REVIEW` are deliberately
not executable.

## Source inventory

The protected, ignored `.SOURCE` directory contains duplicate Markdown and XLSX
catalogues at its root and under `.SOURCE/reference/`. Hash comparison showed the
two Markdown files are identical and the two workbooks are identical.

The catalogue contains 40 Original, 107 Beyond, and 182 Forever entries (329
primary-generation entries). The workbook additionally announces 25 detailed
Powerlifting supplement entries, producing 354 imported rows. The Markdown has
the Powerlifting heading but does not contain those 25 detailed rows, so it is
not sufficient by itself for an exhaustive import.

The requested `docs/reference/531/catalogue_exhaustif_531_3_livres_corrige.*`
paths do not exist in this checkout.

## Principal constraints discovered

- Catalogue rows are documentary records, not automatically executable plans.
- Repeated names across editions require generation/source-qualified stable IDs.
- Forever requires typed Leader/Anchor, 7th Week, and transition concepts rather
  than Original-cycle options.
- Ambiguous frequencies, durations, percentages, or phase relationships must be
  reported and blocked, never inferred.
- Powerlifting must remain `SourceKind.supplement` and must not appear in the
  primary `Generation` enum.
- `.SOURCE` is read-only and must never be committed.
