# Rapport final Base0 / POC

## Résultat

- Branche : `rebuild/base0-foundation`, descendante de `kevin` (vérifié par
  `git merge-base --is-ancestor`).
- Modèle automatisé : Original 5/3/1 + First Set Last, trois semaines, règles
  documentées et testées.
- Architecture : Flutter feature-first, domaine Dart pur, persistance SQLite
  derrière `TrainingStore`, état injecté par `FoundationController`.
- Flavors : `fr.totem974.hybridtraining.dev` et
  `fr.totem974.hybridtraining`.

## Tranche fonctionnelle

Le POC permet de créer un profil local, choisir kg/lb, saisir les quatre
mouvements, choisir une date et une fréquence, générer un cycle, exécuter une
séance, saisir l'AMRAP, réussir/échouer/sauter une série, reprendre un repos,
enregistrer des notes et records, terminer la séance et retrouver l'historique
après réouverture. Les Training Max et séries futures sont modifiables. Le
panneau Configuration permet aussi l'export JSON, la simulation et l'import
atomique d'une sauvegarde, ainsi que l'effacement confirmé des données locales.

## Dépendances principales

- `sqflite` : stockage local Android ;
- `sqflite_common_ffi` : tests de persistance sur le poste ;
- `path` : chemins de base ;
- `integration_test` : parcours Android bout en bout.

Les justifications détaillées figurent dans `docs/architecture/dependencies.md`.

## Vérifications du 17 juillet 2026

- `flutter pub get` : réussi ;
- `dart format` : réussi ;
- `flutter analyze` : aucune erreur ;
- `flutter test` : 23 tests unitaires et 3 tests d'interface réussis ;
- ascendance depuis `kevin` : confirmée ;
- références protégées suivies par Git : aucune détectée.

Le test `integration_test/app_flow_test.dart` a été actualisé pour la nouvelle
interface. Sa dernière exécution n'a pas démarré l'application : Gradle a refusé
le Java 8 de la session et exige Java 17. Il avait été exécuté avec succès sur
Android avant les évolutions d'interface. Une nouvelle validation sur appareil
reste requise avec le JDK Android Studio ; elle produirait un APK de test et a
donc été différée conformément à la demande du propriétaire.

## Matériaux et limites

Les captures, vidéos, APK, décompression et livres restent sous `.SOURCE/`,
ignorés et non committés. L'import historique attend toujours un export réel
anonymisé. Les règles d'échauffement et d'assistance non confirmées restent
`NEEDS_REVIEW`. Les autres programmes du catalogue sont indexés mais désactivés.

## Commits structurants

- `a75507c` à `4767f01` : fondation Base0 ;
- `92b6df8` à `3083cc7` : parcours et séance POC ;
- `a9fc30f` à `9571281` : direction GUI et onboarding ;
- `891fcdb` : édition des Training Max du cycle.

## Prochaines phases après le POC

1. partage natif du fichier de sauvegarde et échantillon historique anonymisé ;
2. salles, barres et inventaires de plaques configurables ;
3. notifications locales ;
4. localisation ARB avec sélecteur français/anglais ;
5. validation et implémentation progressive des autres programmes.
