# HybridTraining

HybridTraining est une application Flutter locale de programmation et de suivi d'entraînement.

## Architecture active

```text
catalog.db + demande utilisateur
→ définition résolue
→ CycleCompiler Dart pur
→ cycle généré
→ snapshot autonome dans training.db
```

- `catalog.db` : définitions publiées et versionnées ;
- `workspace.db` : profil, max, ratios, matériel et brouillons ;
- `training.db` : cycles générés, séances, séries et résultats.

Le chantier actif est le générateur de cycles piloté par le catalogue. Les anciens moteurs restent uniquement des oracles de migration. Forever viendra ensuite comme générateur de macrocycles composant ces cycles.

Le code métier générique vit sous `lib/features/training_catalog`, `lib/features/cycle_generation` et `lib/features/training_log`. Le domaine n'importe ni Flutter, ni SQLite, ni code legacy.

## Validation

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
flutter build web --release
```

L'état factuel du chantier est tenu dans `docs/cycle-generator-status.md`. Les ouvrages et autres sources locales non redistribuables sont rangés sous `docs/sources-local/`, dossier ignoré par Git.
