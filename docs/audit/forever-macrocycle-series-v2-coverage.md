# Forever macrocycle series v2 — coverage

Date: 2026-07-20

## Executable coverage

| Category | Revision | Status | Source boundary |
| --- | --- | --- | --- |
| Standalone program | Beginner Prep School (`FV-141`, canonical alias `forever-beginner-prep-school-v1`) | Executable | 5/3/1 Forever, pages 50–57 |
| Leader | `forever-original-fsl-leader-v1` | Executable in `forever-2l1a-v2` | 5/3/1 Forever, pages 180–182 |
| Anchor | `forever-original-pr-set-anchor-v1` | Executable in `forever-2l1a-v2` | 5/3/1 Forever, pages 180–182 |
| Protocol | `forever-seventh-week-deload-v1` | Required, compiler-inserted | 5/3/1 Forever, pages 31 and 33 |
| Protocol | `forever-seventh-week-tm-test-v1` | Required, compiler-inserted | 5/3/1 Forever, pages 31–33 |
| Recipe | `forever-2l1a-v2` | Executable | Slots Leader 1, Leader 2, Anchor 1 plus both required boundaries |
| Transition | Leader 1 → Leader 2 | Allowed only with the same reviewed Leader revision | Four training days; sourced TM progression |
| Transition | Leader 2 → Anchor 1 | Allowed only to the reviewed PR Set Anchor revision | Four training days; mandatory deload boundary |

The old IDs `FV-236`, `forever-original-531-fsl-2l1a-v1`, and
`forever-original-531-fsl-v1` remain transport aliases. They are not separate
executable rules.

## Non-executable coverage

| Category | Entry | Status | Reason |
| --- | --- | --- | --- |
| Recipe | `forever-2l2a-v1` | `needsReview` | No complete reviewed productive rule set is registered. |
| Recipe | `forever-3l2a-v1` | `needsReview` | No complete reviewed productive rule set is registered. |
| Documentary templates | BBB, FSL component, Simplest Strength, Boring But Strong | `needsReview` or documentation-only | No complete reviewed calculator strategy is registered. |
| Arbitrary C2 | Any revision different from C1 without an explicit transition | Forbidden | The Core requires an explicit compatible transition. |

`needsReview` and forbidden entries fail validation in the codec, series
validator, compiler, and generator adapter. The UI does not present them as
productive choices.

## Runtime and migration coverage

- Schema v4 stores either `standaloneProgramId` or a finite program series.
- v2 migrates through v3 to v4; v3 migrates directly to v4.
- FV-236 migrates to a series containing active M1 with `forever-2l1a-v2`.
- Future macrocycles carry projected TM state.
- Completed and cancelled macrocycles are preserved as metadata and are never
  regenerated.
- Continuation is explicit: manual, repeat same, clone and edit, or recommend
  next. A configured finite limit prevents unbounded materialization.
- Per-lift TM confirmation accepts a hold, reset, or increase no greater than
  the sourced increment.

## Historical protection

The canonical JSON fixture
`test/fixtures/core-v5/forever-original-fsl-2l1a.golden.json` remains unchanged.
The desktop and mobile UI goldens are intentionally revised because the product
composer now exposes the required eight-step series workflow.
