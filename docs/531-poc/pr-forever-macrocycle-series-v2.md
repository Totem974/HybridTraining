# PR: replace the fixed Forever preset with finite macrocycle series

## What changed

- Introduces finite `ForeverProgramSeries` and structured macrocycle recipes.
- Adds the sourced 2L/1A recipe with distinct Leader, Anchor, Deload and TM Test
  revisions.
- Adds schema v4 with v2/v3 and FV-236 migrations.
- Makes the sequence compiler authoritative for cycle and protocol order.
- Lets the canonical generator consume compiled nodes and stable instance IDs.
- Adds explicit continuation and per-lift Training Max decisions.
- Replaces the single Forever template selector with an accessible eight-step
  composer and projected macrocycle horizon.
- Preserves completed history while regenerating only future macrocycles.

## Why

The former implementation encoded one fixed C1/C2/P1/C3/P2 preset across the
domain, adapter and UI. It could not safely represent another macrocycle,
continue a completed series, or preserve explicit future Training Max state.

## Product impact

Users can build and preview a finite Forever 2L/1A macrocycle series, complete
M1, choose a continuation mode and add M2 without rewriting completed history.
Beginner Prep School remains available as a standalone program. Unreviewed
recipes remain visible only as non-executable coverage.

## Validation

See `docs/audit/forever-macrocycle-series-v2-coverage.md` and the final task
report for exact commands, test results and Android builds.
