enum TrainingSessionState {
  planned,
  inProgress,
  completed,
  postponed,
  cancelled,
  skipped,
}

enum TrainingSetResultState { pending, completed, failed, skipped }

final class ActualSetResult {
  const ActualSetResult({
    required this.state,
    this.repetitions,
    this.loadCentiUnits,
    this.note,
  });
  final TrainingSetResultState state;
  final int? repetitions;
  final int? loadCentiUnits;
  final String? note;
}

final class StoredTrainingSnapshot {
  const StoredTrainingSnapshot({
    required this.cycleId,
    required this.resolvedCycleJson,
  });
  final String cycleId;
  final Map<String, Object?> resolvedCycleJson;
}
