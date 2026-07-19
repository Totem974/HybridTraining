# État final du nettoyage des branches — 2026-07-19

Le bundle Git vérifié conserve toutes les références avant nettoyage. Aucune
branche distante n’a été supprimée et aucun push n’a été effectué.

| Référence | Classement final | Action |
| --- | --- | --- |
| `kevin` | PROTECTED | conserver |
| `maintenance/poc-stabilization-20260718` | PROTECTED | conserver jusqu’à autorisation finale |
| `rebuild/forever-engine-core-20260719` | PROTECTED | branche candidate au premier push GitHub |
| `feature/ui-poc-v4-flutter-20260719` | ARCHIVE_THEN_DELETE | conserver le worktree actuel ; proposer tag puis suppression après autorisation distincte |
| `research/forever-*` | KEEP_TEMPORARILY | worktrees encore présents ; ne pas supprimer automatiquement |
| `refactor/composable-program-domain` | KEEP_TEMPORARILY | worktree encore présent |
| `feat/beginner-prep-school` et branches techniques sans worktree | ARCHIVE_THEN_DELETE | vérifier/taguer avant toute suppression locale ou distante |
| `master`, `rebuild/base0-foundation` | KEEP_TEMPORARILY | historique partagé ; aucune suppression sans décision propriétaire |

La réduction physique des branches reste volontairement en attente : plusieurs
worktrees externes sont encore actifs et la suppression distante exige une
autorisation séparée. Ce document est le plan final, pas une preuve de suppression.
