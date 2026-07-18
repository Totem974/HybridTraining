# Inventaire des branches — 2026-07-18

Instantané après fetch. Aucun tag, stash, suppression ou archivage exécuté.

| Branche | SHA | Relation / état | Classement |
|---|---|---|---|
| `kevin`, `master` | `3e6c02d` | référence historique commune | `PROTECTED` |
| `rebuild/base0-foundation` | `51398a1` | 24 commits après kevin ; ancêtre de la lignée courante | `PROTECTED` |
| `feat/beginner-prep-school` | `2080a27` | 12 commits après Base0 ; propre ; Gitea/GitHub égaux | `ACTIVE` |
| `maintenance/poc-stabilization-20260718` | base `2080a27` | worktree isolé de ce lot | `ACTIVE` |
| `chore/freeze-onboarding-core` | `e3d0e9d` | ancêtre de la lignée courante | `ARCHIVE_CANDIDATE` |
| quatre branches `research/*` / `refactor/*` | commits dédiés | patchs équivalents réintégrés, worktrees actifs propres | `UNKNOWN_REQUIRES_OWNER` |
| jalons `feat/canonical-*`, macrocycle, persistence, runtime | ancêtres de `2080a27` | jalons linéaires | `ARCHIVE_CANDIDATE` |

Gitea et GitHub exposaient les mêmes cinq branches/SHA lors de l'audit. Cela ne prouve ni direction ni automatisme du miroir. La configuration Gitea nécessite un contrôle administrateur manuel.

Avant toute suppression future : bundle `--all` hors dépôt, vérification du bundle, manifeste SHA, refs/tags d'archive après accord, contrôle sur les deux serveurs, puis décision propriétaire distincte. Ne jamais supprimer `kevin` ou Base0.
