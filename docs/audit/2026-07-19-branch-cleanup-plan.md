# Branch cleanup plan - 2026-07-19

## Safety state

- Base: `5e538572a298961866412acbd7a2775fd72955a1`.
- `kevin` ancestor check: passed.
- Work branch: `rebuild/forever-engine-core-20260719`.
- Working remote: `GitHub`; `GiTea` is out of scope.
- Verified bundle: `HybridTraining-all-refs.bundle`, 6,454,963 bytes,
  SHA-256 `73E19F686AA1CC37BC424F13DEFAEA3FFB908415482F1387CA2A7D743CE1DA75`.
- No remote deletion or push is authorized.

## Classification

| Reference | Classification | Planned action |
| --- | --- | --- |
| `kevin` | PROTECTED | Keep |
| `maintenance/poc-stabilization-20260718` | PROTECTED | Keep |
| `rebuild/forever-engine-core-20260719` | PROTECTED | Active worktree |
| `feature/ui-poc-v4-flutter-20260719` | ARCHIVE_THEN_DELETE | Keep until the rejected UI is removed; create a verified archive tag before any local deletion |
| `refactor/composable-program-domain` | KEEP_TEMPORARILY | Patch is integrated; remove its clean worktree before later local deletion |
| `research/forever-core-rules` | KEEP_TEMPORARILY | Patch is integrated; remove its clean worktree before later local deletion |
| `research/forever-program-catalog` | KEEP_TEMPORARILY | Patch is integrated; remove its clean worktree before later local deletion |
| `research/forever-session-components` | KEEP_TEMPORARILY | Patch is integrated; remove its clean worktree before later local deletion |
| Other local feature branches ancestral to stabilization | DELETE_SAFE | Delete locally only after the core is green and final ref verification |

GitHub branch SHAs were fetched and match the known stabilization references.
Remote candidates will be listed with exact SHAs only at the final approval gate.

