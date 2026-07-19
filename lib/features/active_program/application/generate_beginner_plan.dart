import '../../programs/domain/load_rounding.dart';
import '../../programs/domain/program_library.dart';
import '../../programs/domain/training_models.dart';
import '../../programs/domain/v2/generation/canonical_plan_generator.dart';
import '../../programs/domain/v2/generation/generated_training_plan.dart';
import '../../programs/domain/v2/program_domain.dart';
import '../domain/versioned_training_plan.dart';
import 'plan_repository.dart';

class GenerateBeginnerPlanRequest {
  GenerateBeginnerPlanRequest({
    required this.planId,
    required this.athleteId,
    required Map<MainLift, double> trainingMaxes,
    required Map<MainLift, double> trainingMaxRatios,
    required this.unit,
    required List<int> trainingWeekdays,
    required this.startDate,
    required this.roundingIncrement,
    this.cycleCount = 1,
    this.macrocycle = 1,
    this.seed = 0,
    Map<String, String> assistanceSelections = const {},
    Map<String, String> conditioningSelections = const {},
  }) : trainingMaxes = Map.unmodifiable(trainingMaxes),
       trainingMaxRatios = Map.unmodifiable(trainingMaxRatios),
       trainingWeekdays = List.unmodifiable(trainingWeekdays),
       assistanceSelections = Map.unmodifiable(assistanceSelections),
       conditioningSelections = Map.unmodifiable(conditioningSelections);

  final String planId;
  final String athleteId;
  final Map<MainLift, double> trainingMaxes;
  final Map<MainLift, double> trainingMaxRatios;
  final WeightUnit unit;
  final List<int> trainingWeekdays;
  final LocalDate startDate;
  final double roundingIncrement;
  final int cycleCount;
  final int macrocycle;
  final int seed;
  final Map<String, String> assistanceSelections;
  final Map<String, String> conditioningSelections;
}

class GenerateBeginnerPlan {
  const GenerateBeginnerPlan({
    required this.repository,
    this.library = const InMemoryProgramLibraryRepository(),
    this.generator = const CanonicalPlanGenerator(),
    required this.clock,
  });

  final PlanRepository repository;
  final ProgramLibraryRepository library;
  final CanonicalPlanGenerator generator;
  final DateTime Function() clock;

  Future<VersionedTrainingPlan> call(
    GenerateBeginnerPlanRequest request,
  ) async {
    final preset = library.findByPresetId(
      CanonicalGenerationBlueprint.beginnerPrepSchool.id.value,
    );
    if (preset == null || !preset.isExecutable) {
      throw StateError('Beginner Prep School is not executable.');
    }
    if (request.planId.trim().isEmpty || request.athleteId.trim().isEmpty) {
      throw ArgumentError('Stable plan and athlete identifiers are required.');
    }
    if (request.trainingMaxes.length != MainLift.values.length ||
        request.trainingMaxRatios.length != MainLift.values.length ||
        MainLift.values.any((lift) {
          final ratio = request.trainingMaxRatios[lift];
          return (request.trainingMaxes[lift] ?? 0) <= 0 ||
              (ratio != 0.85 && ratio != 0.90);
        })) {
      throw ArgumentError(
        'Every main lift requires a positive TM and an 85% or 90% ratio.',
      );
    }
    if (request.cycleCount != 1) {
      throw StateError(
        'Canonical BPS is staged one cycle at a time pending its TM decision.',
      );
    }
    final movementOrder = MainLift.values.map(_movementId).toList();
    final generated = generator.generate(
      blueprint: CanonicalGenerationBlueprint.beginnerPrepSchool,
      athlete: CanonicalAthleteConfiguration(
        movementOrder: movementOrder,
        trainingMaxes: {
          for (final lift in MainLift.values)
            _movementId(lift): request.trainingMaxes[lift]!,
        },
        progressionIncrements: {
          for (final movement in movementOrder) movement: 1,
        },
        trainingMaxRatios: {
          for (final lift in MainLift.values)
            _movementId(lift): request.trainingMaxRatios[lift]!,
        },
        unit: request.unit,
        trainingWeekdays: request.trainingWeekdays,
        startDate: request.startDate,
        rounder: LoadRounder(increment: request.roundingIncrement),
      ),
    );
    final plan = VersionedTrainingPlan.fromCanonical(
      id: request.planId,
      athleteId: request.athleteId,
      macrocycle: request.macrocycle,
      createdAt: clock().toUtc(),
      generated: generated,
    );
    await repository.createPlan(plan);
    return plan;
  }
}

MovementId _movementId(MainLift lift) => switch (lift) {
  MainLift.squat => MovementId.squat,
  MainLift.benchPress => MovementId.benchPress,
  MainLift.deadlift => MovementId.deadlift,
  MainLift.overheadPress => MovementId.overheadPress,
};
