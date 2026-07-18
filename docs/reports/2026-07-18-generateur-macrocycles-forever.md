# Rapport — générateur de macrocycles Forever

Date : 2026-07-18

## Livré

- moteur Dart pur déterministe pour les snapshots `ProgramBlueprint` D1 ;
- blocs Prep, Leader, Anchor et 7th Week discriminé ;
- cycles, semaines, planning civil local 3/4 jours, séances multi-mouvements et
  blocs de séance hétérogènes ;
- prescriptions avec arrondi injecté kg/lb et provenance par règle ;
- transitions et événements explicites de progression, TM Test et PR Test ;
- validation bloquante des règles/politiques non revues et des choix non
  autorisés ;
- snapshot JSON canonique détaché et sortie JSON versionnée ;
- adapter de compatibilité `forever-original-fsl-v1` ;
- tests unitaires et golden JSON.

## Choix de conception

Le domaine composable reste le contrat d'identité. Les détails exécutables sont
portés par `ProgramBlueprintSnapshot`, ce qui évite d'ajouter des suppositions
universelles aux modèles D1. Le moteur ne calcule aucune nouvelle valeur de TM :
il planifie une décision future avec sa règle source.

Les dates utilisent `LocalDate(year, month, day)`. Les calculs calendaires
passent par des dates civiles locales sans sérialisation UTC, notamment aux fins
de mois et d'année.

## Validation

La suite dédiée couvre les séquences 2L/Deload/1A/TM Test et 1L/1A, Prep,
plusieurs cycles, 7th Week typée, plusieurs mouvements, dates 3/4 jours,
changements de mois/année, kg/lb, provenance, refus `NEEDS_REVIEW`, stabilité du
snapshot, compatibilité historique et golden JSON.

Commandes exécutées depuis la racine le 2026-07-18 :

- `flutter pub get` : succès ;
- `dart format --set-exit-if-changed .` : succès, 63 fichiers inspectés et
  aucun changement ;
- `flutter analyze` : succès, aucun problème ;
- `flutter test` : succès, 89 tests passés ;
- suite ciblée du générateur : succès, 11 tests passés.

Aucun changement de persistance, navigation, parcours utilisateur ou Android
n'est inclus dans ce lot de domaine pur ; aucun test d'intégration ou build de
flavor supplémentaire n'est donc requis.
