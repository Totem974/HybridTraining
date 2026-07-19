import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;

/// Presentation transport only. Business validation and calculations stay in CORE.
Map<String, Object?> programConfigurationToForm(
  core.ProgramConfiguration configuration,
) {
  const labels = {
    core.MainLift.overheadPress: 'Press',
    core.MainLift.benchPress: 'Bench Press',
    core.MainLift.squat: 'Squat',
    core.MainLift.deadlift: 'Deadlift',
  };
  final kinds = configuration.lifts.values.map((input) => input.kind).toSet();
  final kind = kinds.length == 1 ? kinds.single : core.LiftInputKind.oneRepMax;
  return {
    'schemaVersion': 1,
    'programId': configuration.programId,
    'generation': configuration.generation.name,
    'unit': configuration.unit == core.WeightUnit.pounds ? 'lb' : 'kg',
    'inputMode': switch (kind) {
      core.LiftInputKind.oneRepMax => '1RM',
      core.LiftInputKind.trainingMax => 'Training Max',
      core.LiftInputKind.repetitionMax => 'Rep max',
    },
    'trainingMaxRatio': configuration.trainingMaxRatio * 100,
    'days': configuration.daysPerWeek,
    'lifts': {
      for (final entry in labels.entries)
        entry.value: configuration.lifts[entry.key]?.weight,
    },
    'repetitions': {
      for (final entry in labels.entries)
        entry.value: configuration.lifts[entry.key]?.repetitions,
    },
  };
}
