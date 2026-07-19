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

## Compte rendu final normalisé

### ÉTAT GLOBAL — COMPLETED

Le cœur local demandé est implémenté, documenté et validé. Le premier push
GitHub reste une action distante en attente d’autorisation, pas une condition de
validité du commit local.

### BASE ET BRANCHE — COMPLETED

`rebuild/forever-engine-core-20260719` descend de `kevin` via le commit stabilisé
`5e538572a298961866412acbd7a2775fd72955a1`. Le worktree final est propre.

### ARCHIVES DE SÉCURITÉ — COMPLETED

Le bundle Git et l’archive `.SOURCE` ont été vérifiés avec les empreintes données
dans la section « Base et sécurité ».

### BRANCHES NETTOYÉES — PARTIAL

L’inventaire et le plan final sont complets. Aucune suppression physique n’a été
faite : les worktrees externes sont actifs et toute suppression distante exige
une autorisation séparée.

### SOURCE NETTOYÉE — COMPLETED

Les références restent locales, ignorées et en lecture seule. Ordre propriétaire
retenu : `531_Powerlifting.pdf`, `Beyond_531_-_Jim_Wendler.pdf`, puis le PDF
Forever, source primaire de l’application. Aucun texte substantiel ni actif
protégé n’a été copié.

### UI/ONBOARDING RETIRÉS — COMPLETED

L’ancien onboarding et l’UI rejetée ne sont plus dans le chemin compilé. Le Core
Validation Shell démarre directement avec quatre destinations.

### MOTEUR CANONIQUE — COMPLETED

Le runtime v4 est l’unique moteur actif. Les tables v3 restent uniquement pour
la migration et la compatibilité des sauvegardes.

### PROGRAMMES ACTIVABLES — COMPLETED

Beginner Prep School v1 est le seul preset activable et fonctionne de bout en
bout avec définition versionnée, RuleId et golden tests.

### PROGRAMMES BLOQUÉS — COMPLETED

Original 5/3/1, Original + FSL et toute variante contenant des règles
`NEEDS_REVIEW` restent explicitement non activables.

### RUNTIME DE SÉANCE — COMPLETED

Exécution, résultats réels, repos, pause/reprise après réouverture, annulation de
la dernière saisie, fin, déplacement, saut et abandon confirmé sont couverts.

### PERSISTANCE ET MIGRATIONS — COMPLETED

Les écritures critiques sont transactionnelles. Les migrations v1/v2/v3→v4,
dont une séance v3 interrompue avec résultat, et les sauvegardes compatibles sont
testées.

### STATISTIQUES ET PROGRESSION — COMPLETED

Tonnage réel, e1RM, records, historique TM et décisions bornées utilisent les
résultats effectivement saisis, séparément du volume prescrit.

### TESTS ET COUVERTURE — COMPLETED

131 tests passent ; analyse et formatage passent ; couverture des quatre domaines
critiques : 1 284/1 348 lignes, soit 95,25 % ; APK DEV et PROD construits.

### VALIDATION REDMI NOTE 7 — COMPLETED

Le scénario Android 13 passe sur le Redmi Note 7 physique en 46 secondes.

### COMMITS — COMPLETED

Les changements sont répartis en commits locaux cohérents jusqu’à `ca53e0e` ; le
commit documentaire final qui contient cette grille est listé dans l’historique.

### LIMITES — COMPLETED

Le shell n’est pas présenté comme l’UI produit définitive. Les programmes non
revus, la suppression des branches et les actions distantes restent déclarés.

### ACTIONS DISTANTES EN ATTENTE D’AUTORISATION — BLOCKED

Branche proposée au premier push GitHub :
`rebuild/forever-engine-core-20260719`. Aucun tag n’est proposé au push et aucune
branche distante n’est proposée à la suppression dans cette autorisation. GiTea
reste hors circuit. Le SHA exact doit être relu après le commit de ce rapport,
puis comparé au SHA GitHub après un push autorisé.
