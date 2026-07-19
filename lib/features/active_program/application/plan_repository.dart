import '../domain/versioned_training_plan.dart';

abstract interface class PlanRepository {
  Future<void> createPlan(VersionedTrainingPlan plan);

  Future<Map<String, Object?>?> loadPlan(String planId);
}
