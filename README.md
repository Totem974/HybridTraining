# HybridTraining

HybridTraining est une application Flutter locale de programmation et de suivi d'entraînement.

## Architecture active

Le chantier actif livre un premier chemin vertical testable :

```text
catalog.db + demande utilisateur
→ définition résolue
→ CycleCompiler Dart pur
→ cycle généré
→ snapshot autonome dans training.db
```

Les données sont séparées par responsabilité :

- `catalog.db` : définitions publiées, versionnées et référencées ;
- `workspace.db` : profil, max, ratios, matériel et brouillons de l'utilisateur ;
- `training.db` : cycles générés, séances, séries prévues et résultats réels.

Le premier gate est Standard 5/3/1 sur quatre jours. Les anciens moteurs restent présents comme références et oracles de migration ; le nouveau chemin de production ne les appelle pas. Forever et une nouvelle interface produit sont hors du gate actuel.

## Organisation du nouveau cœur

Le code métier générique vit sous `lib/features/training_catalog`, `lib/features/cycle_generation` et `lib/features/training_log`. Le domaine n'importe ni Flutter, ni SQLite, ni code legacy.

## Validation

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

L'architecture n'est considérée fonctionnelle qu'après réussite du test bout en bout chargeant le catalogue SQLite, compilant le cycle, persistant son snapshot et relisant un résultat réel de série.

Les documents historiques et les anciens rapports restent disponibles sous `docs/archive/` mais ne décrivent pas le chemin de production actif.
