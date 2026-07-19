class StatisticsScope {
  const StatisticsScope({
    this.from,
    this.until,
    this.planId,
    this.blockId,
    this.cycleId,
  });

  final DateTime? from;
  final DateTime? until;
  final String? planId;
  final String? blockId;
  final String? cycleId;

  bool includesDate(DateTime value) =>
      (from == null || !value.isBefore(from!)) &&
      (until == null || value.isBefore(until!));
}

class MovementStatistics {
  const MovementStatistics({
    required this.movementId,
    required this.actualRepetitions,
    required this.actualTonnage,
    required this.bestEstimatedOneRepMax,
    required this.currentTrainingMax,
    required this.trainingMaxChanges,
    required this.personalRecordCount,
  });

  final String movementId;
  final int actualRepetitions;
  final double? actualTonnage;
  final double? bestEstimatedOneRepMax;
  final double? currentTrainingMax;
  final int trainingMaxChanges;
  final int personalRecordCount;
}

class TrainingStatistics {
  const TrainingStatistics({
    required this.completedSessions,
    required this.failedSessions,
    required this.skippedSessions,
    required this.abandonedSessions,
    required this.successfulSets,
    required this.failedSets,
    required this.skippedSets,
    required this.actualRepetitions,
    required this.actualTonnage,
    required this.prescribedTonnageForRecordedSets,
    required this.movements,
    required this.successfulActivities,
    required this.failedActivities,
    required this.skippedActivities,
    required this.actualDistanceMeters,
    required this.actualDurationSeconds,
    required this.actualRounds,
  });

  final int completedSessions;
  final int failedSessions;
  final int skippedSessions;
  final int abandonedSessions;
  final int successfulSets;
  final int failedSets;
  final int skippedSets;
  final int actualRepetitions;
  final double? actualTonnage;

  /// Kept separate from actual tonnage; this is never used as performed work.
  final double prescribedTonnageForRecordedSets;
  final List<MovementStatistics> movements;
  final int successfulActivities;
  final int failedActivities;
  final int skippedActivities;
  final double actualDistanceMeters;
  final int actualDurationSeconds;
  final int actualRounds;

  double? get activitySuccessRate {
    final total = successfulActivities + failedActivities + skippedActivities;
    return total == 0 ? null : successfulActivities / total;
  }
}
