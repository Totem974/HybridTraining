import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/active_program/application/generate_beginner_plan.dart';
import 'package:hybrid_training/features/active_program/application/plan_repository.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';

void main() {
  test(
    'generates and persists Beginner Prep School deterministically',
    () async {
      final repository = _MemoryPlanRepository();
      final useCase = GenerateBeginnerPlan(
        repository: repository,
        clock: () => DateTime.utc(2026, 7, 19, 8),
      );
      final request = GenerateBeginnerPlanRequest(
        planId: 'plan-bps-1',
        athleteId: 'athlete-1',
        trainingMaxes: const {
          MainLift.squat: 100,
          MainLift.benchPress: 70,
          MainLift.deadlift: 120,
          MainLift.overheadPress: 45,
        },
        trainingMaxRatios: const {
          MainLift.squat: .85,
          MainLift.benchPress: .85,
          MainLift.deadlift: .90,
          MainLift.overheadPress: .90,
        },
        unit: WeightUnit.kilograms,
        trainingWeekdays: const [
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        ],
        startDate: const LocalDate(2026, 7, 20),
        roundingIncrement: 2.5,
        seed: 531,
      );

      final plan = await useCase(request);

      expect(repository.created, same(plan));
      expect(plan.blueprintId, 'forever-beginner-prep-school-v1');
      expect(plan.createdAt, DateTime.utc(2026, 7, 19, 8));
      expect(plan.blocks, hasLength(1));
      expect(plan.blocks.single.cycles.single.sessions, hasLength(9));
      expect(
        plan.blocks.single.cycles.single.sessions.first.scheduledFor,
        DateTime(2026, 7, 20),
      );
    },
  );

  test('does not persist invalid training max ratios', () async {
    final repository = _MemoryPlanRepository();
    final useCase = GenerateBeginnerPlan(
      repository: repository,
      clock: () => DateTime.utc(2026, 7, 19),
    );
    final request = GenerateBeginnerPlanRequest(
      planId: 'plan',
      athleteId: 'athlete',
      trainingMaxes: {for (final lift in MainLift.values) lift: 100},
      trainingMaxRatios: {for (final lift in MainLift.values) lift: .80},
      unit: WeightUnit.kilograms,
      trainingWeekdays: const [1, 3, 5],
      startDate: const LocalDate(2026, 7, 20),
      roundingIncrement: 2.5,
    );

    expect(() => useCase(request), throwsArgumentError);
    expect(repository.created, isNull);
  });
}

class _MemoryPlanRepository implements PlanRepository {
  VersionedTrainingPlan? created;

  @override
  Future<void> createPlan(VersionedTrainingPlan plan) async => created = plan;

  @override
  Future<Map<String, Object?>?> loadPlan(String planId) async => null;
}
