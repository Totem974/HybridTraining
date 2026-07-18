# Modèle de domaine

```mermaid
classDiagram
  ProgramConcept "1" --> "many" ProgramRevision
  ProgramRevision "many" --> "many" ProgramBlueprint
  ProgramBlueprint --> MacrocycleBlueprint
  MacrocycleBlueprint --> TrainingBlock
  TrainingBlock --> TrainingCycle
  TrainingCycle --> PlannedSession
  PlannedSession --> SessionBlock
  SessionBlock --> SetPrescription
  PlannedSession --> ComposableWorkout
  ComposableWorkout --> WorkoutBlock
  WorkoutBlock --> WorkoutPrescription
```

`CURRENT` : ces concepts Dart purs existent et sont testés. `POC_TARGET` : leur raccordement au contrôleur et aux écrans. Les IDs persistants sont en anglais stable et indépendants des libellés.
