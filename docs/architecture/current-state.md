# Architecture actuelle

Source : code au `2080a27`, revu le 18 juillet 2026.

## CURRENT

```mermaid
flowchart TD
  Entry["main / main_dev / main_prod"] --> App["HybridTrainingApp"]
  App --> Controller["FoundationController"]
  Controller --> Store["TrainingStore"]
  Store --> Legacy["SqliteTrainingStore — parcours UI v1"]
  Legacy --> Factory["ProgramGeneratorFactory — Original FSL"]
  Legacy --> DB[("SQLite schema 3")]
  App --> Setup["ProfileSetup / DevelopmentBootstrap"]
  App --> Home["TrainingHomeScreen"]
  Home --> Library["ProgramLibraryScreen"]
  V2["Domaine/générateurs v2"] --> PlanStore["SqliteVersionedPlanStore"]
  Runtime["ComposableWorkout"] --> RuntimeStore["SqliteWorkoutRuntimeStore"]
  PlanStore --> DB
  RuntimeStore --> DB
  V2 -. "non raccordé à l'app" .-> App
  Runtime -. "non raccordé à l'app" .-> App
```

La navigation est actuellement impérative (`MaterialPageRoute`). L'organisation feature-first existe, mais `TrainingHomeScreen` regroupe encore plusieurs destinations. Le schéma v2/v3 et ses stores sont testés isolément ; ils ne décrivent pas encore le parcours produit actif.

## TARGET

Présentation par feature, état injecté testable, navigation déclarative et raccordement du plan versionné/runtime composable, tout en conservant un adaptateur de lecture v1.
