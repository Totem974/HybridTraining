# PR: séparer Cycle 5/3/1 et composer Forever

## Résumé

Ce changement transforme le choix Forever du générateur Web en une frontière de
planification typée. Le mode Cycle conserve le calculateur Original/Beyond et ses
extensions. Le mode Forever distingue programme autonome et macrocycle, compile
la recette revue 2 Leaders / 1 Anchor et affiche ses protocoles automatiques dans
une timeline.

## Changements principaux

- contrôle segmenté Cycle 5/3/1 / Forever visible en haut ;
- profil commun conservé et brouillons Cycle/Forever indépendants ;
- domaine Dart pur avec configurations typées, révisions, rôles, protocoles,
  pairing, validation structurée et projections TM par nœud ;
- compilateur unique de `forever-2l1a` vers C1, C2, P1, C3, P2 ;
- C2 identique à C1 et changement désactivé faute d'autre règle sourcée ;
- Deload et TM Test auto-insérés, typés et non supprimables ;
- Beginner Prep School maintenu comme programme autonome ;
- schéma de configuration v4 déterministe et migrations v2/v3/aliases ;
- restauration par URL `?mode=` et lien partagé contenant le payload v4 ;
- TM futurs projetés, confirmations adressées par C1/C2/C3, plus aucune décision
  Forever liée aux semaines 3, 6, 10 ou 11 ;
- timeline responsive, contrôles clavier de réordonnancement et annonces de copie ;
- audit, architecture, schéma, compatibilité, TM, migration, couverture et tests
  documentés.

## Couverture honnête

Activés : Forever Original + FSL, Beginner Prep School, 7th Week Deload et 7th
Week Training Max Test. Une seule relation Original + FSL Leader → Anchor est
recommandée. Les 180 autres entrées Forever restent documentaires/non
exécutables; les entrées globales `NEEDS_REVIEW` restent bloquées. PR Test et
autres familles ne sont pas activés.

## Validation

- format : pass ;
- analyse statique : pass ;
- 329 tests unitaires/widget/routes/persistance/goldens : pass ;
- E2E Google Chrome : 5/5 en 34,7 secondes ;
- E2E Mozilla Firefox : 5/5 en 34,7 secondes ;
- persistance Web réelle : série M1/M2 terminée restaurée après recréation de
  la page, avec décisions TM et état de terminaison conservés ;
- E2E Microsoft Edge : non exécuté ; Flutter 3.44.6 utilise
  `browserName: edge`, alors qu'EdgeDriver 150 exige `MicrosoftEdge` ;
- validations et builds Android : explicitement reportés à un chantier
  ultérieur et non bloquants pour ce lot.

## Risques et suivi

- reprendre la validation Edge après correction de la capability Edge dans le
  SDK Flutter ;
- reprendre les validations et builds Android dans le chantier dédié ;
- retirer définitivement l'adaptateur de checkpoints v2 par semaine après la
  fenêtre de migration ;
- localiser l'ensemble des chaînes historiques du calculateur ;
- activer de nouveaux pairings uniquement après revue complète et sourcée.
