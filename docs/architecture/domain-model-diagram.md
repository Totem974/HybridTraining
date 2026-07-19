# Modèle de domaine

```mermaid
classDiagram
  class ProgramBlueprintSnapshot
  class ForeverMacrocycleGenerator
  class GeneratedTrainingPlan
  class VersionedTrainingPlan
  class WorkoutExecution
  class SetOutcome
  class TmAdjustmentDecision
  class TrainingStatistics

  ProgramBlueprintSnapshot --> ForeverMacrocycleGenerator
  ForeverMacrocycleGenerator --> GeneratedTrainingPlan
  GeneratedTrainingPlan --> VersionedTrainingPlan
  VersionedTrainingPlan "1" *-- "many" WorkoutExecution
  WorkoutExecution "1" *-- "many" SetOutcome
  SetOutcome --> TrainingStatistics
  TmAdjustmentDecision --> VersionedTrainingPlan : plan event
```

Les snapshots et décisions portent identifiants stables, versions et provenance.
Les classes du domaine sont en Dart pur ; contrôleurs Flutter et dépôts SQLite
restent dans les couches présentation et données.
