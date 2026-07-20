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

abstract interface class ProgramSwitchRepository {
  Future<ProgramSwitchPreview> previewProgramSwitch(
    ProgramSwitchRequest request,
  );
  Future<void> applyProgramSwitch(ProgramSwitchRequest request);
  Future<ForeverFutureAmendmentPreview> previewForeverFutureAmendment(
    ForeverFutureAmendmentRequest request,
  );
  Future<void> applyForeverFutureAmendment(
    ForeverFutureAmendmentRequest request, {
    required String previewId,
    required bool confirmed,
  });
}

class ForeverFutureAmendmentRequest {
  const ForeverFutureAmendmentRequest({
    required this.currentPlanId,
    required this.futurePlan,
    required this.reason,
    required this.ruleId,
  });

  final String currentPlanId;
  final VersionedTrainingPlan futurePlan;
  final String reason;
  final String ruleId;
}

class ForeverFutureAmendmentPreview {
  const ForeverFutureAmendmentPreview({
    required this.previewId,
    required this.currentPlanId,
    required this.preservedSessionIds,
    required this.replacedPlannedSessionIds,
    required this.addedPlannedSessionIds,
    required this.addedBlockIds,
  });

  final String previewId;
  final String currentPlanId;
  final List<String> preservedSessionIds;
  final List<String> replacedPlannedSessionIds;
  final List<String> addedPlannedSessionIds;
  final List<String> addedBlockIds;
}

class PreviewProgramSwitch {
  const PreviewProgramSwitch(this.repository);
  final ProgramSwitchRepository repository;
  Future<ProgramSwitchPreview> call(ProgramSwitchRequest request) =>
      repository.previewProgramSwitch(request);
}

class ApplyProgramSwitch {
  const ApplyProgramSwitch(this.repository);
  final ProgramSwitchRepository repository;
  Future<void> call(ProgramSwitchRequest request) =>
      repository.applyProgramSwitch(request);
}

class PreviewForeverFutureAmendment {
  const PreviewForeverFutureAmendment(this.repository);
  final ProgramSwitchRepository repository;
  Future<ForeverFutureAmendmentPreview> call(
    ForeverFutureAmendmentRequest request,
  ) => repository.previewForeverFutureAmendment(request);
}

class ApplyForeverFutureAmendment {
  const ApplyForeverFutureAmendment(this.repository);
  final ProgramSwitchRepository repository;
  Future<void> call(
    ForeverFutureAmendmentRequest request, {
    required String previewId,
    required bool confirmed,
  }) => repository.applyForeverFutureAmendment(
    request,
    previewId: previewId,
    confirmed: confirmed,
  );
}
