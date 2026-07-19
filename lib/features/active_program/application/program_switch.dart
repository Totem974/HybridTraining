import '../domain/versioned_training_plan.dart';

enum ActiveSessionDisposition { reject, abandon }

class ProgramSwitchPreview {
  const ProgramSwitchPreview({
    required this.currentPlanId,
    required this.nextPlanId,
    required this.currentBlueprintId,
    required this.nextBlueprintId,
    required this.completedSessionsPreserved,
    required this.plannedSessionsCancelled,
    required this.activeSessionIds,
    required this.nextStartDate,
  });

  final String currentPlanId;
  final String nextPlanId;
  final String currentBlueprintId;
  final String nextBlueprintId;
  final int completedSessionsPreserved;
  final int plannedSessionsCancelled;
  final List<String> activeSessionIds;
  final DateTime nextStartDate;

  bool get requiresActiveSessionDecision => activeSessionIds.isNotEmpty;
}

class ProgramSwitchRequest {
  const ProgramSwitchRequest({
    required this.currentPlanId,
    required this.nextPlan,
    required this.reason,
    this.activeSessionDisposition = ActiveSessionDisposition.reject,
  });

  final String currentPlanId;
  final VersionedTrainingPlan nextPlan;
  final String reason;
  final ActiveSessionDisposition activeSessionDisposition;
}
