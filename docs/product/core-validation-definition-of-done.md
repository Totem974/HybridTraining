# Core Validation Shell definition of done

The shell is a temporary engine verification tool, not the future product UI.

## Active destinations

1. Engine: shows the sole reviewed preset and can create a deterministic DEV
   fixture and persisted plan.
2. Tracking: shows only aggregates derived from persisted outcomes. Tonnage is
   unavailable until an actual load is recorded.
3. Profile: shows the local athlete and unit without calculating business
   values in widgets.
4. Settings: exports a complete backup and provides a confirmed local reset.

## Flavor rules

- DEV displays a permanent validation-tool banner and may create one explicitly
  fictitious athlete.
- PROD contains no automatic fixture and exposes no fixture action.
- Both flavors start without onboarding.

## Current validation

- Widget tests cover direct startup, four destinations, DEV-only fixture,
  absence of PROD demo data and unavailable actual tonnage.
- SQLite tests prove idempotent Beginner plan creation and that tonnage uses
  actual successful load rather than prescription.
- The Redmi integration test covers direct startup, persisted restart and
  backup export.

Workout execution, program switching and import UI remain separate completion
items for the full engine rebuild and are not claimed complete here.

