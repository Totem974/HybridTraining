import '../../workout_runtime/domain/workout_execution.dart';

class CoreWorkoutSnapshot {
  const CoreWorkoutSnapshot({
    required this.sessionId,
    required this.scheduledFor,
    required this.state,
    required this.currentSetNumber,
    required this.totalSets,
    required this.prescriptionId,
    required this.prescribedRepetitions,
    required this.prescribedLoad,
    required this.completedSets,
    required this.restUntil,
    required this.itemKind,
  });

  final String sessionId;
  final String scheduledFor;
  final WorkoutExecutionState state;
  final int currentSetNumber;
  final int totalSets;
  final String prescriptionId;
  final int prescribedRepetitions;
  final double prescribedLoad;
  final int completedSets;
  final DateTime? restUntil;
  final ExecutionItemKind itemKind;

  bool get canStart =>
      state == WorkoutExecutionState.planned ||
      state == WorkoutExecutionState.ready;
  bool get canRecord =>
      state == WorkoutExecutionState.activeSet && completedSets < totalSets;
  bool get canComplete => completedSets == totalSets && !isClosed;
  bool get isClosed => const {
    WorkoutExecutionState.completed,
    WorkoutExecutionState.abandoned,
    WorkoutExecutionState.skipped,
  }.contains(state);
}
