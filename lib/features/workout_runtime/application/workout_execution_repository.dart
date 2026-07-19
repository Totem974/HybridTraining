import '../domain/workout_execution.dart';

abstract interface class WorkoutExecutionRepository {
  Future<WorkoutExecution> create(String sessionId);

  Future<WorkoutExecution?> load(String sessionId);

  Future<WorkoutExecution> mutate(
    String sessionId, {
    required String eventType,
    Map<String, Object?> payload,
    required WorkoutExecution Function(WorkoutExecution current) action,
  });
}
