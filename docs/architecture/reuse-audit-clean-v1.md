# Audit de réutilisation — clean v1

## Portée et légende

État observé sur `codex/catalog-cycle-clean-v1`. `REUSE` = reprendre sans dépendance
legacy; `ADAPT` = extraire ou remodeler; `GOLDEN_ONLY` = conserver comme oracle;
`DROP` = ne pas porter dans le nouveau cœur. Une cible décrite par `AGENTS.md` mais
absente du code est explicitement marquée **non implémentée**.

## Décisions par composant

| Composant | Chemin | Responsabilité observée | Décision | Justification |
| --- | --- | --- | --- | --- |
| Estimation 1RM | `lib/features/training_max/domain/max_calculator.dart` | Formule d’Epley et validation des entrées. | REUSE | Fonction Dart pure, déterministe et déjà testée, sans Flutter ni SQLite. |
| Calcul TM | `lib/features/training_max/domain/max_calculator.dart` | Applique un ratio `]0,1]` au 1RM. | REUSE | Le calcul correspond directement à une primitive amont du nouveau compilateur. |
| Progression TM | `lib/features/training_max/domain/max_calculator.dart` | Ajoute 2,5/5 kg ou 5/10 lb selon le lift. | ADAPT | Le calcul est pur, mais dépend de l’enum legacy `MainLift` et encode une règle 5/3/1 particulière. |
| Façade des saisies max | `lib/features/poc_531/domain/core.dart` (`deriveTrainingMax`) | Résout 1RM, rep-max ou TM direct. | ADAPT | La logique utile doit devenir un résolveur générique typé, hors façade `poc_531`. |
| Arrondi de charge | `lib/features/programs/domain/load_rounding.dart` | Arrondit au multiple le plus proche. | REUSE | Petite primitive pure et paramétrable, avec comportement déterministe testé. |
| Recherche de plaques exacte | `lib/features/gyms/domain/plate_calculator.dart` | Cherche une combinaison symétrique selon barres et quantités. | REUSE | Le solveur est pur, indépendant du programme et respecte l’inventaire réel. |
| Repli de plating | `lib/features/poc_531/domain/core.dart` (`calculatePlateLoading`) | Cherche par pas de 0,001 une charge inférieure réalisable. | ADAPT | La politique de repli et sa borne doivent être explicites et séparées du solveur exact. |
| Schedule générique existant | `lib/features/programs/domain/training_schedule.dart` | Valide puis date des schedules 3/4 jours, fixes ou rotatifs. | ADAPT | Dates et value objects sont utiles, mais les contraintes « quatre lifts exactement » sont spécialisées. |
| Planning POC | `lib/features/poc_531/domain/planning/planning.dart` | Compile des séquences propres au POC/Forever. | GOLDEN_ONLY | Il peut vérifier les dates et ordres historiques, mais ne doit pas devenir le contrat générique. |
| Générateur Standard historique | `lib/features/programs/domain/original_fsl_program.dart` | Produit trois semaines de main work et FSL. | GOLDEN_ONLY | Il branche implicitement sur Standard/FSL et omet warm-up/deload, donc sert d’oracle partiel. |
| Façade de génération POC | `lib/features/poc_531/domain/core.dart` (`generateProgram`) | Sélectionne un générateur par `generatorId` et fabrique un payload. | DROP | Le branchement par identifiant et la grande façade contredisent le compilateur générique demandé. |
| Générateurs Core v5 | `lib/features/programs/domain/v2/generation/` | Génèrent plusieurs blueprints canoniques spécialisés. | GOLDEN_ONLY | Ils fournissent fixtures et sorties comparables, sans être importés par le nouveau domaine. |
| Goldens Core v5 | `test/fixtures/core-v5/*.golden.json` | Figent des plans de référence. | GOLDEN_ONLY | Ce sont des oracles utiles pour détecter les écarts, pas des définitions exécutables. |
| Tests Standard/FSL | `test/unit/features/programs/original_fsl_program_test.dart` | Vérifient ratios, répétitions, performance set et arrondi. | ADAPT | Reprendre les cas comme tests de compatibilité autour du nouveau compilateur, sans couplage au moteur. |
| Schéma SQLite actuel | `lib/core/database/database_schema.dart` | Mélange profil, matériel, catalogue, plans, prescriptions et résultats en versions 1–5. | GOLDEN_ONLY | Il documente les données à migrer, mais ne respecte ni les trois fichiers ni l’absence de FK inter-base. |
| Ouverture de base actuelle | `lib/core/database/local_database.dart` | Ouvre `hybrid_training.db` en schéma version 5. | DROP | Cette façade monolithique ne peut pas représenter `catalog.db`, `workspace.db` et `training.db`. |
| Données candidates à `workspace.db` | `database_schema.dart`: `athlete_profiles`, `training_max_history`, `gyms`, `gym_bars`, `gym_plates` | Stocke profil, max et équipement. | ADAPT | Les colonnes simples sont réutilisables, mais les identités et migrations doivent être isolées dans le workspace. |
| Données candidates à `training.db` | `database_schema.dart`: `program_definition_snapshots`, `training_plans`, `training_blocks`, `plan_training_cycles`, `plan_training_sessions`, `session_blocks`, `set_prescriptions`, résultats | Stocke plans, prescriptions et exécution. | ADAPT | La hiérarchie éclaire le snapshot cible, mais contient doublons v1–v5 et références à l’athlète externe. |
| Anciennes tables parallèles | `database_schema.dart`: `training_cycles`/`training_sessions`/`training_sets`, runtimes v3/v4, prescriptions sets/activities | Maintient plusieurs représentations du même plan et de son exécution. | DROP | Le nouveau `training.db` doit choisir une représentation canonique et migrer sans dupliquer le runtime. |
| Tests de migrations historiques | `test/unit/core/database/database_schema_test.dart` | Vérifient création et upgrades du schéma monolithique. | GOLDEN_ONLY | Ils sécurisent la lecture legacy; de nouveaux tests sont requis séparément pour chaque base. |
| Inventaire 354 | `lib/features/poc_531/catalog/catalog.generated.dart` | Expose 354 lignes typées issues du classeur. | ADAPT | Conserver identités, ordre et provenance, mais promouvoir seulement des définitions strictement validées. |
| Rapport de couverture | `tool/531_catalog/catalog-coverage.json` | Compte 354 classées, 4 exécutables, 350 ambiguës. | REUSE | C’est une preuve auditable des limites; « classée » ne doit jamais être assimilé à « générable ». |
| Import d’inventaire | `tool/531_catalog/import_catalog.ps1` | Lit deux feuilles XLSX, classe heuristiquement et génère Dart/JSON. | ADAPT | Garder le contrôle 354 et la provenance, mais sortir vers le stockage catalogue et corriger l’encodage observé. |
| Modèle de catalogue POC | `lib/features/poc_531/catalog/catalog_schema.dart` et `catalog.dart` | Enveloppe les lignes et autorise quatre stratégies par registre. | DROP | Le registre de `generatorId` et les entrées documentaires dans le runtime entretiennent un second catalogue concurrent. |
| Contrat générique cible | `AGENTS.md`: `ResolvedCycleDefinition + CycleRequest = GeneratedCycle` | Sépare définition résolue, requête et résultat déterministe. | ADAPT | **Non implémenté**: créer ces types sous `features/cycle_generation/domain`, sans imports legacy. |
| Catalogue relationnel cible | `AGENTS.md`: `features/training_catalog/{domain,application,data}` | Versions publiées immuables, relations ordonnées et JSON polymorphe strict. | ADAPT | **Non implémenté**: dériver le schéma uniquement des primitives nécessaires au premier Standard réel. |
| Promotion/publication cible | `AGENTS.md` (version publiée immuable) | Valide un brouillon puis crée une version publiée dans `catalog.db`. | ADAPT | **Non implémenté**: aucune commande, transaction ou migration de promotion n’existe aujourd’hui. |

## Limites et ordre de reprise

- Le total 354 prouve l’exhaustivité de l’index importé, pas celle des prescriptions:
  350 lignes restent `NEEDS_REVIEW` et ambiguës.
- Le « Standard » exécutable actuel est éclaté entre `OriginalFslProgram`, la
  façade POC et les moteurs v2; aucun ne satisfait seul warm-up + main work +
  deload + schedule configurable + snapshot autonome.
- `workspace.db`, `training.db`, `catalog.db`, leurs migrations et la promotion
  ne sont pas présents; toute documentation les décrivant au présent serait aspiratoire.
- Ordre sûr: extraire primitives pures, figer un golden Standard legacy, définir
  le contrat générique, publier une seule définition Standard, puis écrire/lire
  son snapshot et un résultat réel dans le nouveau `training.db`.
