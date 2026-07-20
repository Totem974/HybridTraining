import '../domain/core_validation_snapshot.dart';
import '../domain/core_workout_snapshot.dart';
import '../../import_export/domain/import_models.dart';
import '../../workout_runtime/domain/workout_execution.dart';
import '../../active_program/application/program_switch.dart';
import '../../active_program/application/plan_lifecycle.dart';

class CoreWorkoutAmendmentDraft {
  const CoreWorkoutAmendmentDraft({
    required this.request,
    required this.preview,
  });

  final PlanAmendmentRequest request;
  final PlanAmendmentPreview preview;
}

abstract interface class CoreValidationRepository {
  Future<CoreValidationSnapshot> load();

  Future<void> createDevelopmentFixture();

  Future<CoreWorkoutSnapshot?> loadFirstWorkout();

  Future<void> startFirstWorkout();

  Future<void> recordCurrentSet({
    required SetOutcomeStatus status,
    int? actualRepetitions,
    double? actualLoad,
    double? rpe,
    String notes,
  });

  Future<void> pauseOrResumeWorkout();

  Future<void> undoLastSet();

  Future<void> beginOrEndRest({required Duration duration});

  Future<void> completeWorkout();

  Future<void> abandonWorkout();

  Future<CoreWorkoutAmendmentDraft> previewSkipWorkout();

  Future<CoreWorkoutAmendmentDraft> previewRescheduleWorkout(DateTime date);

  Future<void> applyWorkoutAmendment(
    PlanAmendmentRequest request, {
    required String amendmentId,
    required bool confirmed,
  });

  Future<ProgramSwitchPreview> previewProgramSwitch(DateTime startDate);

  Future<void> applyProgramSwitch(
    DateTime startDate, {
    required bool abandonActiveSession,
    required String previewId,
    required bool confirmed,
  });

  Future<String> exportBackup();

  Future<ImportReport> importBackup(String source, {required bool dryRun});

  Future<void> deleteAllData();
}
