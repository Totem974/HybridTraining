final class AssistanceIntegerParameter {
  const AssistanceIntegerParameter({
    required this.id,
    required this.defaultValue,
    required this.minimum,
    required this.maximum,
    this.step = 1,
  }) : assert(id != ''),
       assert(minimum > 0),
       assert(maximum >= minimum),
       assert(defaultValue >= minimum),
       assert(defaultValue <= maximum),
       assert(step > 0);

  final String id;
  final int defaultValue;
  final int minimum;
  final int maximum;
  final int step;
}

enum AssistanceLoadKind { bodyweight, unconfigured }

enum AssistanceDistributionKind { roundedAverageEdgeRemainder }

sealed class AssistanceVolumePrescription {
  const AssistanceVolumePrescription();
}

final class FixedAssistanceVolume extends AssistanceVolumePrescription {
  const FixedAssistanceVolume({
    required this.setCount,
    required this.repetitions,
  }) : assert(setCount > 0),
       assert(repetitions > 0);

  final int setCount;
  final int repetitions;
}

final class DistributedTotalAssistanceVolume
    extends AssistanceVolumePrescription {
  const DistributedTotalAssistanceVolume({
    required this.setCount,
    required this.totalRepetitions,
    this.distribution = AssistanceDistributionKind.roundedAverageEdgeRemainder,
  });

  final AssistanceIntegerParameter setCount;
  final AssistanceIntegerParameter totalRepetitions;
  final AssistanceDistributionKind distribution;
}

final class AssistanceExercisePrescription {
  const AssistanceExercisePrescription({
    required this.exerciseId,
    required this.volume,
    required this.load,
  }) : assert(exerciseId != '');

  final String exerciseId;
  final AssistanceVolumePrescription volume;
  final AssistanceLoadKind load;
}

final class AssistanceSessionSlot {
  const AssistanceSessionSlot({
    required this.id,
    required this.sessionRole,
    required this.prescriptions,
  }) : assert(id != ''),
       assert(sessionRole != '');

  final String id;
  final String sessionRole;
  final List<AssistanceExercisePrescription> prescriptions;
}

final class ResolvedAssistancePlan {
  const ResolvedAssistancePlan({
    required this.id,
    required this.revision,
    required this.slots,
  }) : assert(id != ''),
       assert(revision > 0);

  final String id;
  final int revision;
  final List<AssistanceSessionSlot> slots;
}
