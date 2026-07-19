import 'program_switch.dart';
import '../domain/versioned_training_plan.dart';
import 'create_training_plan.dart';

class PlanAmendmentRequest {
  PlanAmendmentRequest({
    required this.planId,
    required this.reason,
    required this.ruleId,
    Map<String, DateTime> rescheduledSessions = const {},
    Map<String, double> trainingMaxChanges = const {},
    this.activeSessionDisposition = ActiveSessionDisposition.reject,
  }) : rescheduledSessions = Map.unmodifiable(rescheduledSessions),
       trainingMaxChanges = Map.unmodifiable(trainingMaxChanges);

  final String planId;
  final String reason;
  final String ruleId;
  final Map<String, DateTime> rescheduledSessions;
  final Map<String, double> trainingMaxChanges;
  final ActiveSessionDisposition activeSessionDisposition;
}

class PlanAmendmentPreview {
  const PlanAmendmentPreview({
    required this.amendmentId,
    required this.planId,
    required this.version,
    required this.preservedCompletedSessionIds,
    required this.activeSessionIds,
    required this.rescheduledSessionIds,
    required this.regeneratedSessionIds,
    required this.cancelledSessionIds,
    required this.trainingMaxChanges,
    required this.prescriptionChanges,
  });

  final String amendmentId;
  final String planId;
  final int version;
  final List<String> preservedCompletedSessionIds;
  final List<String> activeSessionIds;
  final List<String> rescheduledSessionIds;
  final List<String> regeneratedSessionIds;
  final List<String> cancelledSessionIds;
  final Map<String, double> trainingMaxChanges;
  final int prescriptionChanges;

  bool get requiresActiveSessionDecision => activeSessionIds.isNotEmpty;
}

class LifecycleStatus {
  const LifecycleStatus({
    required this.sessionComplete,
    required this.cycleComplete,
    required this.blockComplete,
    required this.planComplete,
    required this.trainingMaxDecisionRequired,
    this.nextBlockId,
  });

  final bool sessionComplete;
  final bool cycleComplete;
  final bool blockComplete;
  final bool planComplete;
  final bool trainingMaxDecisionRequired;
  final String? nextBlockId;
}

abstract interface class PlanLifecycleRepository {
  Future<PlanAmendmentPreview> previewAmendment(PlanAmendmentRequest request);
  Future<void> applyAmendment(
    PlanAmendmentRequest request, {
    required String amendmentId,
    required bool confirmed,
  });
  Future<void> rescheduleSession(String sessionId, DateTime date);
  Future<void> skipSession(String sessionId, {required String reason});
  Future<void> abandonActiveSession(String sessionId, {required String reason});
  Future<LifecycleStatus> completeWorkout(String sessionId, DateTime at);
  Future<LifecycleStatus> completeCycle(String cycleId, DateTime at);
  Future<LifecycleStatus> completeBlock(String blockId, DateTime at);
  Future<LifecycleStatus> advancePlanLifecycle(String planId, DateTime at);
  Future<void> completeTrainingPlan(String planId, DateTime at);
  Future<void> applyTrainingMaxDecision({
    required String planId,
    required String movementId,
    required double confirmedTrainingMax,
    required String reason,
    required DateTime at,
  });
}

class PreviewPlanAmendment {
  const PreviewPlanAmendment(this.repository);
  final PlanLifecycleRepository repository;
  Future<PlanAmendmentPreview> call(PlanAmendmentRequest request) =>
      repository.previewAmendment(request);
}

class ApplyPlanAmendment {
  const ApplyPlanAmendment(this.repository);
  final PlanLifecycleRepository repository;
  Future<void> call(
    PlanAmendmentRequest request, {
    required String amendmentId,
    required bool confirmed,
  }) => repository.applyAmendment(
    request,
    amendmentId: amendmentId,
    confirmed: confirmed,
  );
}

class ReschedulePlannedSession {
  const ReschedulePlannedSession(this.repository);
  final PlanLifecycleRepository repository;
  Future<void> call(String sessionId, DateTime date) =>
      repository.rescheduleSession(sessionId, date);
}

class SkipPlannedSession {
  const SkipPlannedSession(this.repository);
  final PlanLifecycleRepository repository;
  Future<void> call(String sessionId, {required String reason}) =>
      repository.skipSession(sessionId, reason: reason);
}

class AbandonActiveSession {
  const AbandonActiveSession(this.repository);
  final PlanLifecycleRepository repository;
  Future<void> call(String sessionId, {required String reason}) =>
      repository.abandonActiveSession(sessionId, reason: reason);
}

class CompleteWorkout {
  const CompleteWorkout(this.repository);
  final PlanLifecycleRepository repository;
  Future<LifecycleStatus> call(String sessionId, DateTime at) =>
      repository.completeWorkout(sessionId, at);
}

class CompleteCycle {
  const CompleteCycle(this.repository);
  final PlanLifecycleRepository repository;
  Future<LifecycleStatus> call(String cycleId, DateTime at) =>
      repository.completeCycle(cycleId, at);
}

class CompleteBlock {
  const CompleteBlock(this.repository);
  final PlanLifecycleRepository repository;
  Future<LifecycleStatus> call(String blockId, DateTime at) =>
      repository.completeBlock(blockId, at);
}

class AdvancePlanLifecycle {
  const AdvancePlanLifecycle(this.repository);
  final PlanLifecycleRepository repository;
  Future<LifecycleStatus> call(String planId, DateTime at) =>
      repository.advancePlanLifecycle(planId, at);
}

class CompleteTrainingPlan {
  const CompleteTrainingPlan(this.repository);
  final PlanLifecycleRepository repository;
  Future<void> call(String planId, DateTime at) =>
      repository.completeTrainingPlan(planId, at);
}

class ApplyTrainingMaxDecision {
  const ApplyTrainingMaxDecision(this.repository);
  final PlanLifecycleRepository repository;
  Future<void> call({
    required String planId,
    required String movementId,
    required double confirmedTrainingMax,
    required String reason,
    required DateTime at,
  }) => repository.applyTrainingMaxDecision(
    planId: planId,
    movementId: movementId,
    confirmedTrainingMax: confirmedTrainingMax,
    reason: reason,
    at: at,
  );
}

class CreateNextPlan {
  const CreateNextPlan(this.createTrainingPlan);
  final CreateTrainingPlan createTrainingPlan;

  Future<VersionedTrainingPlan> call({
    required int completedMacrocycle,
    required CreateTrainingPlanRequest request,
  }) {
    if (completedMacrocycle < 1 ||
        request.macrocycle != completedMacrocycle + 1) {
      throw ArgumentError('The next plan must increment the macrocycle once.');
    }
    return createTrainingPlan(request);
  }
}
