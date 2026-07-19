# Rapport final — Stabilisation Base0 et Forever par défaut

## Objectif

Stabiliser le parcours Base0, rendre explicite l'identité du programme Forever
par défaut et renforcer la persistance, la séance guidée et les validations
automatisées.

## Résultat

- identité de programme structurée avec famille, template stable, version,
  statut documentaire et références ;
- compatibilité des anciennes définitions SQLite conservée ;
- onboarding en six étapes et date/fréquence réellement utilisées ;
- reprise de séance, résultats succès/échec/saut, notes et repos persistants ;
- import/export et suppression pilotés par le contrôleur ;
- écrans d'accueil, séance, historique, statistiques, profil, réglages et
  bibliothèque consolidés ;
- traductions françaises et anglaises adaptées ;
- tests unitaires, widget et intégration étendus.

## Fichiers principaux

- `lib/features/programs/domain/program_identity.dart`
- `lib/features/programs/domain/original_fsl_program.dart`
- `lib/features/active_program/data/sqlite_training_store.dart`
- `lib/features/active_program/presentation/training_home_screen.dart`
- `lib/features/onboarding/presentation/profile_setup_screen.dart`
- `integration_test/app_flow_test.dart`
- `docs/product/default-program-decision.md`

## Validations

- `flutter pub get` : réussi ;
- `dart format --set-exit-if-changed .` : 39 fichiers, aucun changement ;
- `flutter analyze` : aucune erreur ;
- `flutter test` : 32 tests réussis ;
- `flutter test integration_test/app_flow_test.dart -d <Redmi> --flavor dev` :
  réussi ;
- APK debug `dev` et `prod` : compilés avec succès.

## Limites

Le template automatisé reste volontairement unique. Les autres programmes sont
informatifs ou `NEEDS_REVIEW` tant que leurs règles ne sont pas validées par les
spécifications documentaires.
