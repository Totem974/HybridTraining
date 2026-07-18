# Stabilisation du POC — 2026-07-18

## Objectif et base

Stabiliser le POC sans implémenter le moteur Forever complet. Branche créée depuis `2080a27`, descendant linéaire de l'ancrage `51398a1`, dans un worktree isolé.

## Résultat

- sauvegarde schema 3 étendue aux tables runtime avec compatibilité import v1/v2 ;
- export réalisé dans un snapshot SQLite cohérent et import refusé si un profil n'a plus de cycle/séances/séries utilisables ;
- Beginner Prep School maintenu consultable mais non activable avant raccordement UI v2 ;
- navigation basse réparée entre accueil, statistiques, profil et réglages ;
- écritures de notes sérialisées et retour bloqué jusqu'à la persistance de la dernière révision ;
- erreurs d'import/export/suppression/TM et repos rendues visibles et réessayables ;
- sémantique de navigation et mise en page du profil améliorées ;
- documentation CURRENT/POC_TARGET/FUTURE, diagrammes, schéma logique et audits consolidés.

## Baseline

Au SHA de base : format sans changement, analyse sans issue, 105 tests, builds debug dev/prod. Redmi Note 7 Android 13 détecté.

## Validation finale

- `flutter pub get --offline` : réussi ;
- `dart format --set-exit-if-changed .` : 71 fichiers, aucun changement ;
- `git diff --check` : réussi ;
- `flutter analyze --no-pub` : aucune issue ;
- `flutter test --no-pub` : 112 tests réussis ;
- `flutter test integration_test/app_flow_test.dart ... --flavor dev` : réussi sur Redmi Note 7 Android 13 ;
- builds APK debug `dev` et `prod` : réussis.

Le SHA Gitea est consigné après le push final.

## Limites

Localisation anglaise non raccordée à `MaterialApp` (`VALIDATED_WITH_LIMITS`) ; filtre initial Actuels/Legacy/Tous à reprendre avec la migration de bibliothèque ; audit live de l'application originale non rejoué faute d'ADB dans l'agent dédié ; animations, TalkBack, 200 %, rotation, fonctionnement hors ligne manuel et profilage restent à valider. Aucun nettoyage/suppression de branche n'a été exécuté.
