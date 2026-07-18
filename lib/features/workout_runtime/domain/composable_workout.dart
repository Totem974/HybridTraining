enum WorkoutBlockRole {
  mobility,
  warmUp,
  jumpsThrows,
  mainWork,
  performanceSet,
  supplemental,
  assistancePush,
  assistancePull,
  assistanceSingleLegCore,
  conditioningEasy,
  conditioningHard,
  trainingMaxTest,
  personalRecordTest,
}

enum WorkoutSessionStatus { planned, started, completed, abandoned, skipped }

enum WorkoutBlockStatus { pending, active, completed, skipped }

enum PrescriptionStatus { pending, success, failure, skipped }

enum TargetType {
  setsRepsLoad,
  totalReps,
  duration,
  distance,
  rounds,
  completion,
}

class ActivityTarget {
  const ActivityTarget({
    required this.type,
    this.sets,
    this.reps,
    this.load,
    this.totalReps,
    this.durationSeconds,
    this.distanceMeters,
    this.rounds,
  });
  final TargetType type;
  final int? sets, reps, totalReps, durationSeconds, rounds;
  final double? load, distanceMeters;
  void validate() {
    final valid = switch (type) {
      TargetType.setsRepsLoad =>
        (sets ?? 0) > 0 && (reps ?? -1) >= 0 && (load ?? -1) >= 0,
      TargetType.totalReps => (totalReps ?? 0) > 0,
      TargetType.duration => (durationSeconds ?? 0) > 0,
      TargetType.distance => (distanceMeters ?? 0) > 0,
      TargetType.rounds => (rounds ?? 0) > 0,
      TargetType.completion => true,
    };
    if (!valid) throw ArgumentError('Invalid target for ${type.name}.');
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'sets': sets,
    'reps': reps,
    'load': load,
    'totalReps': totalReps,
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
    'rounds': rounds,
  };
}

class WorkoutPrescription {
  const WorkoutPrescription({
    required this.id,
    required this.label,
    required this.target,
    this.status = PrescriptionStatus.pending,
  });
  final String id, label;
  final ActivityTarget target;
  final PrescriptionStatus status;
}

class WorkoutBlock {
  WorkoutBlock({
    required this.id,
    required this.sequence,
    required this.role,
    required List<WorkoutPrescription> prescriptions,
    this.status = WorkoutBlockStatus.pending,
    this.movementId,
  }) : prescriptions = List.unmodifiable(prescriptions);
  final String id;
  final int sequence;
  final WorkoutBlockRole role;
  final String? movementId;
  final WorkoutBlockStatus status;
  final List<WorkoutPrescription> prescriptions;
}

class ComposableWorkout {
  ComposableWorkout({
    required this.id,
    required List<WorkoutBlock> blocks,
    this.status = WorkoutSessionStatus.planned,
    this.notes = '',
    this.activeBlockIndex = 0,
  }) : blocks = List.unmodifiable(blocks) {
    if (blocks.isEmpty) {
      throw ArgumentError('A workout requires at least one block.');
    }
    if (blocks.indexed.any((entry) => entry.$1 != entry.$2.sequence)) {
      throw ArgumentError('Workout blocks require a contiguous order.');
    }
    for (final block in blocks) {
      for (final item in block.prescriptions) {
        item.target.validate();
      }
    }
  }
  final String id, notes;
  final WorkoutSessionStatus status;
  final List<WorkoutBlock> blocks;
  final int activeBlockIndex;
  WorkoutBlock? get activeBlock =>
      activeBlockIndex < blocks.length ? blocks[activeBlockIndex] : null;
  int moveNext() => activeBlockIndex >= blocks.length - 1
      ? activeBlockIndex
      : activeBlockIndex + 1;
  int movePrevious() => activeBlockIndex <= 0 ? 0 : activeBlockIndex - 1;
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.total,
    required this.success,
    required this.failure,
    required this.skipped,
  });
  factory WorkoutSummary.fromWorkout(ComposableWorkout workout) {
    final values = workout.blocks
        .expand((block) => block.prescriptions)
        .map((item) => item.status)
        .toList();
    return WorkoutSummary(
      total: values.length,
      success: values.where((v) => v == PrescriptionStatus.success).length,
      failure: values.where((v) => v == PrescriptionStatus.failure).length,
      skipped: values.where((v) => v == PrescriptionStatus.skipped).length,
    );
  }
  final int total, success, failure, skipped;
}
