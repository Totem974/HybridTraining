import '../../programs/domain/load_rounding.dart';
import '../../programs/domain/program_library.dart';
import '../../programs/domain/training_models.dart';
import '../../programs/domain/v2/generation/beginner_prep_school_blueprint.dart';
import '../../programs/domain/v2/generation/forever_macrocycle_generator.dart';
import '../../programs/domain/v2/generation/generated_training_plan.dart';
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
    this.generator = const ForeverMacrocycleGenerator(),
    required this.clock,
  });

  final PlanRepository repository;
  final ProgramLibraryRepository library;
  final ForeverMacrocycleGenerator generator;
  final DateTime Function() clock;

  Future<VersionedTrainingPlan> call(
    GenerateBeginnerPlanRequest request,
  ) async {
    final preset = library.findByPresetId(beginnerPrepSchoolPresetId);
    if (preset == null || !preset.isExecutable) {
      throw StateError('Beginner Prep School is not executable.');
    }
    if (request.planId.trim().isEmpty || request.athleteId.trim().isEmpty) {
      throw ArgumentError('Stable plan and athlete identifiers are required.');
    }
    final snapshot = BeginnerPrepSchoolBlueprint.create(
      trainingMaxRatios: request.trainingMaxRatios,
      cycleCount: request.cycleCount,
    );
    final generated = generator.generate(
      snapshot: snapshot,
      athlete: AthletePlanConfiguration(
        trainingMaxes: request.trainingMaxes,
        unit: request.unit,
        trainingWeekdays: request.trainingWeekdays,
        startDate: request.startDate,
        rounder: LoadRounder(increment: request.roundingIncrement),
        assistanceSelections: request.assistanceSelections,
        conditioningSelections: request.conditioningSelections,
        seed: request.seed,
      ),
    );
    final plan = VersionedTrainingPlan.fromGenerated(
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
