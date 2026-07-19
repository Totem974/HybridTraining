import '../../programs/domain/program_library.dart';
import '../../programs/domain/v2/generation/canonical_plan_generator.dart';
import '../../programs/domain/v2/program_domain.dart';
import '../domain/versioned_training_plan.dart';
import 'plan_repository.dart';

class CreateTrainingPlanRequest {
  const CreateTrainingPlanRequest({
    required this.planId,
    required this.athleteId,
    required this.presetId,
    required this.athlete,
    this.cycleModel = CanonicalCycleModel.standard531,
    this.macrocycle = 1,
  });

  final String planId;
  final String athleteId;
  final String presetId;
  final CanonicalAthleteConfiguration athlete;
  final CanonicalCycleModel cycleModel;
  final int macrocycle;
}

class CreateTrainingPlan {
  const CreateTrainingPlan({
    required this.repository,
    required this.clock,
    this.library = const InMemoryProgramLibraryRepository(),
    this.generator = const CanonicalPlanGenerator(),
  });

  final PlanRepository repository;
  final DateTime Function() clock;
  final ProgramLibraryRepository library;
  final CanonicalPlanGenerator generator;

  Future<VersionedTrainingPlan> call(CreateTrainingPlanRequest request) async {
    if (request.planId.trim().isEmpty ||
        request.athleteId.trim().isEmpty ||
        request.macrocycle < 1) {
      throw ArgumentError('Stable plan, athlete and macrocycle are required.');
    }
    final entry = library.findByPresetId(request.presetId);
    if (entry == null || !entry.isExecutable) {
      throw StateError('Preset is not executable: ${request.presetId}');
    }
    final blueprint = switch (entry.generatorId) {
      'canonical-powerlifting' => CanonicalGenerationBlueprint(
        id: CanonicalGenerationBlueprint.standardPowerlifting.id,
        version: CanonicalGenerationBlueprint.standardPowerlifting.version,
        sourceEdition: SourceEdition.powerlifting,
        generation: MethodGeneration.powerlifting,
        cycleModel: request.cycleModel,
        source: CanonicalGenerationBlueprint.standardPowerlifting.source,
      ),
      'canonical-beyond' => CanonicalGenerationBlueprint.beyondSixWeek,
      _ => throw StateError(
        'Preset uses a different creation contract: ${request.presetId}',
      ),
    };
    final generated = generator.generate(
      blueprint: blueprint,
      athlete: request.athlete,
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
