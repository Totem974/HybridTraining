# Rapport — reconstruction du cœur Forever — 2026-07-19

## Base et sécurité

- Base : `5e538572a298961866412acbd7a2775fd72955a1`, descendante de `kevin`.
- Branche : `rebuild/forever-engine-core-20260719`.
- Bundle Git : 6 454 963 octets, SHA-256
  `73E19F686AA1CC37BC424F13DEFAEA3FFB908415482F1387CA2A7D743CE1DA75`, vérifié.
- Archive `.SOURCE` : 4 669 fichiers, 128 819 792 octets avant compression,
  SHA-256 `39D3FFF8AEC8E110D80C4FA5C36535ECA507400A640CFFF03F208A4436F1C3CA`,
  extraction vérifiée sans fichier manquant ni hash divergent.

## Architecture et programmes

L’ancienne UI et l’onboarding ont quitté le chemin compilé. Le Core Validation
Shell appelle des interfaces application, des domaines Dart purs et des dépôts
SQLite. Beginner Prep School v1 est le seul preset exécutable. Original 5/3/1,
Original + FSL et les autres entrées indexées restent non activables lorsque des
règles indispensables sont `NEEDS_REVIEW`.

Le schéma v4 ajoute `workout_executions`, `workout_set_outcomes` et
`workout_execution_events`. Il permet pause/reprise, repos, RPE, résultats réels,
annulation ordonnée et journal atomique. La migration v3→v4 convertit une séance
interrompue, sa position et ses résultats vers le runtime canonique ; les
migrations v1/v2/v3→v4 et les sauvegardes v1/v2/v3→v4 sont testées.

Le changement de programme génère le prochain plan avant transaction, fournit un
aperçu, exige une décision pour la séance active et préserve les séances
terminées, performances, records et TM. Les décisions TM portent RuleId, source,
génération et motif.

## Validation exacte

| Validation | Résultat |
| --- | --- |
| `flutter pub get` | PASS |
| formatage | PASS |
| `flutter analyze` | PASS, 0 problème |
| `flutter test` / couverture | PASS, 131 tests |
| couverture domaines critiques | 1 284 / 1 348 lignes, 95,25 % |
| intégration Redmi Note 7 Android 13 | PASS, scénario complet en 46 s |
| APK DEV debug | PASS |
| APK PROD debug | PASS |

Le scénario Redmi démarre sans onboarding, crée uniquement la fixture DEV,
génère BPS, exécute plusieurs résultats, reprend après reconstruction, termine,
vérifie 405 de tonnage réel, simule puis applique un changement, déplace et saute
une séance, abandonne explicitement une séance active, exporte/importe et confirme
l’absence de fixture en PROD. Le dialogue de confirmation est couvert par le test
widget ; le service transactionnel est exécuté sur le Redmi.

## Limites déclarées

- aucune branche distante n’est poussée ou supprimée ;
- les worktrees de recherche et de l’UI rejetée restent présents ;
- les programmes incomplets restent documentaires ;
- le shell est fonctionnel mais volontairement non destiné au produit final.
