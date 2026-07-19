import 'dart:convert';

import '../catalog/catalog.dart' as catalog;
import '../../gyms/domain/plate_calculator.dart';
import '../../programs/domain/load_rounding.dart';
import '../../programs/domain/original_fsl_program.dart';
import '../../programs/domain/training_models.dart';
import '../../programs/domain/v2/generation/canonical_plan_generator.dart';
import '../../programs/domain/v2/generation/generated_training_plan.dart';
import '../../programs/domain/v2/program_domain.dart';
import '../../training_max/domain/max_calculator.dart';
import 'models.dart';

export '../../programs/domain/training_models.dart' show MainLift, WeightUnit;
export 'models.dart';

const _pocPrograms = <ProgramDefinition>[
  ProgramDefinition(
    id: 'original-fsl-v1',
    name: '5/3/1 Original — FSL',
    family: 'Original 5/3/1',
    variant: 'FSL',
    generation: Generation.original,
    status: ProgramStatus.legacy,
    sourceKind: SourceKind.canonical,
    entryKind: CatalogEntryKind.executableTemplate,
    frequencies: {4},
    levels: {ExperienceLevel.intermediate, ExperienceLevel.advanced},
    goals: {TrainingGoal.strength},
    generatorId: 'original-fsl',
    sources: [
      SourceProvenance(
        title: 'Core v5 reviewed historical compatibility contract',
        pages: 'ORIGINAL-FSL-MAIN-001 / SUPPLEMENTAL-001',
      ),
    ],
  ),
];

const _programAliases = <String, String>{
  'beyond-six-week-cycle-v1': 'BY-026',
  'forever-beginner-prep-school-v1': 'FV-141',
  'forever-original-531-fsl-2l1a-v1': 'FV-236',
  'powerlifting-standard-531-v1': 'PL-001',
};

CatalogSummary getCatalogSummary() {
  final definitions = catalog.catalogProgramDefinitions;
  return CatalogSummary(
    total: definitions.length,
    executable: definitions.where((program) => program.isExecutable).length,
    byGeneration: {
      for (final generation in Generation.values)
        generation: definitions
            .where(
              (program) =>
                  program.generation == generation &&
                  program.sourceKind == SourceKind.canonical,
            )
            .length,
    },
  );
}

List<Generation> listGenerations() => List.unmodifiable(Generation.values);

List<ProgramDefinition> listPrograms([
  ProgramFilters filters = const ProgramFilters(),
]) => List.unmodifiable(
  <ProgramDefinition>[
    ..._pocPrograms,
    ...catalog.catalogProgramDefinitions,
  ].where((program) {
    if (filters.generation != null &&
        program.generation != filters.generation) {
      return false;
    }
    if (!filters.includeLegacy && program.status == ProgramStatus.legacy) {
      return false;
    }
    if (!filters.includeSupplements &&
        program.sourceKind == SourceKind.supplement) {
      return false;
    }
    if (filters.executableOnly && !program.isExecutable) return false;
    return true;
  }),
);

ProgramDefinition? getProgramDefinition(String programId) =>
    <ProgramDefinition>[..._pocPrograms, ...catalog.catalogProgramDefinitions]
        .where(
          (program) => program.id == (_programAliases[programId] ?? programId),
        )
        .firstOrNull;

double calculateEstimatedOneRepMax(RepMaxInput input) => const MaxCalculator()
    .estimateOneRepMax(load: input.weight, repetitions: input.repetitions);

TrainingMaxResult deriveTrainingMax({
  required LiftInput input,
  required double ratio,
}) {
  if (input.kind == LiftInputKind.trainingMax) {
    if (input.weight <= 0 || ratio <= 0 || ratio > 1) {
      throw ArgumentError('Invalid Training Max input.');
    }
    return TrainingMaxResult(
      oneRepMax: input.weight / ratio,
      trainingMax: input.weight,
      ratio: ratio,
    );
  }
  final oneRepMax = input.kind == LiftInputKind.oneRepMax
      ? input.weight
      : calculateEstimatedOneRepMax(
          RepMaxInput(
            weight: input.weight,
            repetitions: input.repetitions ?? 0,
          ),
        );
  return TrainingMaxResult(
    oneRepMax: oneRepMax,
    trainingMax: const MaxCalculator().trainingMax(
      oneRepMax: oneRepMax,
      ratio: ratio,
    ),
    ratio: ratio,
  );
}

List<ValidationIssue> validateProgramConfiguration(
  ProgramConfiguration configuration,
) {
  final issues = <ValidationIssue>[];
  final program = getProgramDefinition(configuration.programId);
  if (program == null) {
    return const [
      ValidationIssue(
        code: 'unknown_program',
        message: 'Programme inconnu.',
        field: 'programId',
      ),
    ];
  }
  if (program.generation == null ||
      (program.sourceKind == SourceKind.supplement &&
          !configuration.options.enablePowerliftingExtension)) {
    issues.add(
      const ValidationIssue(
        code: 'supplement_not_generation',
        message:
            'Powerlifting est une extension, pas une génération principale.',
        field: 'generation',
      ),
    );
  } else if (program.generation != configuration.generation) {
    issues.add(
      const ValidationIssue(
        code: 'generation_mismatch',
        message: 'La génération ne correspond pas au programme.',
        field: 'generation',
      ),
    );
  }
  if (!program.frequencies.contains(configuration.daysPerWeek) ||
      configuration.trainingWeekdays.length != configuration.daysPerWeek ||
      configuration.trainingWeekdays.toSet().length !=
          configuration.daysPerWeek) {
    issues.add(
      const ValidationIssue(
        code: 'invalid_frequency',
        message: 'Fréquence ou jours incompatibles avec ce programme.',
        field: 'daysPerWeek',
      ),
    );
  }
  if (configuration.lifts.keys.toSet().length != MainLift.values.length ||
      !configuration.lifts.keys.toSet().containsAll(MainLift.values)) {
    issues.add(
      const ValidationIssue(
        code: 'missing_lifts',
        message: 'Les quatre lifts sont obligatoires.',
        field: 'lifts',
      ),
    );
  }
  if (configuration.trainingMaxRatio <= 0 ||
      configuration.trainingMaxRatio > 1) {
    issues.add(
      const ValidationIssue(
        code: 'invalid_tm_ratio',
        message: 'Le ratio de Training Max doit être dans ]0, 1].',
        field: 'trainingMaxRatio',
      ),
    );
  }
  if (configuration.roundingIncrement <= 0) {
    issues.add(
      const ValidationIssue(
        code: 'invalid_rounding',
        message: 'Incrément d’arrondi invalide.',
        field: 'roundingIncrement',
      ),
    );
  }
  for (final input in configuration.lifts.values) {
    if (input.weight <= 0 ||
        (input.kind == LiftInputKind.repetitionMax &&
            (input.repetitions == null || input.repetitions! <= 0))) {
      issues.add(
        ValidationIssue(
          code: 'invalid_lift',
          message: 'Valeur de lift invalide.',
          field: 'lifts.${input.lift.name}',
        ),
      );
    }
  }
  return List.unmodifiable(issues);
}

List<Recommendation> recommendPrograms(UserProfile profile) {
  final candidates =
      listPrograms(
        ProgramFilters(includeLegacy: profile.constraints.allowLegacy),
      ).where(
        (program) =>
            program.generation != null &&
            program.sourceKind == SourceKind.canonical &&
            program.isExecutable &&
            program.frequencies.contains(profile.constraints.daysPerWeek) &&
            profile.constraints.hasBarbell &&
            (profile.constraints.allowLegacy ||
                (program.status != ProgramStatus.legacy &&
                    program.status != ProgramStatus.superseded)),
      );
  final results =
      candidates.map((program) {
        var score = 40;
        final reasons = <String>[];
        final tradeoffs = <String>[];
        if (program.goals.contains(profile.goal)) {
          score += 25;
          reasons.add('Objectif compatible');
        } else {
          tradeoffs.add('Objectif moins directement ciblé');
        }
        if (program.levels.contains(profile.level)) {
          score += 20;
          reasons.add('Niveau compatible');
        } else {
          score -= 15;
          tradeoffs.add('Niveau non optimal');
        }
        if (profile.preferredGeneration == program.generation) {
          score += 10;
          reasons.add('Génération préférée');
        }
        if (program.requiresLeaderAnchor) {
          tradeoffs.add('Séquence Leader/Anchor et 7th Week requise');
        }
        return Recommendation(
          program: program,
          score: score,
          reasons: List.unmodifiable(reasons),
          tradeoffs: List.unmodifiable(tradeoffs),
        );
      }).toList()..sort(
        (a, b) => b.score != a.score
            ? b.score.compareTo(a.score)
            : a.program.id.compareTo(b.program.id),
      );
  return List.unmodifiable(results);
}

GeneratedProgram generateProgram(ProgramConfiguration configuration) {
  final issues = validateProgramConfiguration(
    configuration,
  ).where((issue) => issue.blocking).toList();
  if (issues.isNotEmpty) throw ProgramGenerationException(issues);
  final program = getProgramDefinition(configuration.programId)!;
  final maxes = {
    for (final lift in MainLift.values)
      lift: deriveTrainingMax(
        input: configuration.lifts[lift]!,
        ratio: configuration.trainingMaxRatio,
      ).trainingMax,
  };
  Map<String, Object?> payload;
  if (program.generatorId == 'original-fsl') {
    const original = OriginalFslProgram();
    final rounder = LoadRounder(increment: configuration.roundingIncrement);
    payload = {
      'schemaVersion': 1,
      'blueprintId': program.id,
      'generation': Generation.original.name,
      'unit': configuration.unit.name,
      'blocks': [
        {
          'id': 'original-cycle-1',
          'role': 'classicCycle',
          'cycles': [
            {
              'number': 1,
              'weeks': [
                for (var week = 1; week <= 3; week++)
                  {
                    'number': week,
                    'sessions': [
                      for (final lift in MainLift.values)
                        {
                          'id': 'original-w$week-${lift.name}',
                          'lift': lift.name,
                          'sets': [
                            for (final set
                                in original
                                    .buildSession(
                                      week: week,
                                      liftMax: LiftMax(
                                        lift: lift,
                                        oneRepMax: maxes[lift]!,
                                        trainingMaxRatio: 1,
                                        unit: configuration.unit,
                                      ),
                                      rounder: rounder,
                                    )
                                    .sets)
                              {
                                'kind': set.kind.name,
                                'percentage': set.percentage,
                                'repetitions': set.repetitions,
                                'trainingMax': set.trainingMax,
                                'unroundedLoad': set.unroundedLoad,
                                'load': set.load,
                                'roundingIncrement': set.roundingIncrement,
                                'isPerformanceSet': set.isPerformanceSet,
                              },
                          ],
                        },
                    ],
                  },
              ],
            },
          ],
          'rule': {
            'document': 'Core v5 reviewed historical compatibility contract',
            'location': 'ORIGINAL-FSL-MAIN-001 / SUPPLEMENTAL-001',
          },
        },
      ],
      'transitions': const <Object?>[],
    };
  } else {
    final movementMaxes = {
      for (final entry in maxes.entries) _movement(entry.key): entry.value,
    };
    final increments = {
      for (final lift in MainLift.values)
        _movement(lift): _progression(lift, configuration.unit),
    };
    Map<MovementId, double>? confirmedAt(int week) {
      final values = configuration.options.confirmedTrainingMaxesByWeek[week];
      if (values == null) return null;
      return {
        for (final entry in values.entries) _movement(entry.key): entry.value,
      };
    }

    Map<MovementId, double> progressed(int count) => {
      for (final movement in movementMaxes.keys)
        movement: movementMaxes[movement]! + increments[movement]! * count,
    };

    final canonicalAthlete = CanonicalAthleteConfiguration(
      movementOrder: MainLift.values.map(_movement).toList(),
      trainingMaxes: movementMaxes,
      progressionIncrements: increments,
      trainingWeekdays: configuration.trainingWeekdays,
      startDate: LocalDate.fromDateTime(configuration.startDate),
      unit: configuration.unit,
      rounder: LoadRounder(increment: configuration.roundingIncrement),
      confirmedBeyondTrainingMaxes: program.generatorId == 'canonical-beyond'
          ? confirmedAt(3) ??
                (configuration.options.projectFutureTrainingMaxes
                    ? progressed(1)
                    : null)
          : null,
      confirmedTrainingMaxesByWeek:
          program.generatorId == 'canonical-forever' ||
              program.generatorId == 'canonical-forever-original-fsl'
          ? {
              for (final week in const [3, 6, 10])
                if (confirmedAt(week) case final confirmation?)
                  week: confirmation
                else if (configuration.options.projectFutureTrainingMaxes)
                  week: progressed(switch (week) {
                    3 => 1,
                    6 => 2,
                    _ => 3,
                  }),
            }
          : const {},
      trainingMaxRatios: program.generatorId == 'canonical-bps'
          ? {
              for (final movement in movementMaxes.keys)
                movement: configuration.trainingMaxRatio,
            }
          : const {},
    );
    final blueprint = switch (program.generatorId) {
      'canonical-powerlifting' =>
        CanonicalGenerationBlueprint.standardPowerlifting,
      'canonical-beyond' => CanonicalGenerationBlueprint.beyondSixWeek,
      'canonical-forever' || 'canonical-forever-original-fsl' =>
        CanonicalGenerationBlueprint.foreverOriginalFsl,
      'canonical-bps' => CanonicalGenerationBlueprint.beginnerPrepSchool,
      _ => throw StateError('No reviewed generator registered.'),
    };
    payload = const CanonicalPlanGenerator()
        .generate(blueprint: blueprint, athlete: canonicalAthlete)
        .toJson();
  }
  return GeneratedProgram(
    schemaVersion: 1,
    programId: program.id,
    generation: configuration.generation,
    payload: Map.unmodifiable(payload),
    sources: program.sources,
    warnings:
        configuration.options.projectFutureTrainingMaxes &&
            configuration.options.confirmedTrainingMaxesByWeek.isEmpty &&
            configuration.generation != Generation.original
        ? const [
            'Les Training Max futurs sont des projections explicites de la progression source ; confirmez-les aux checkpoints.',
          ]
        : payload['awaitingTrainingMaxConfirmation'] == true
        ? const [
            'Une confirmation explicite du Training Max est requise au prochain checkpoint.',
          ]
        : const [],
  );
}

String explainRecommendation(Recommendation result) =>
    '${result.program.name}: ${result.reasons.join(', ')}${result.tradeoffs.isEmpty ? '' : '. Compromis: ${result.tradeoffs.join(', ')}'}.';

String explainGeneratedProgram(GeneratedProgram plan) =>
    '${plan.programId} (${plan.generation.name}), schéma ${plan.schemaVersion}. Les prescriptions et transitions proviennent exclusivement du blueprint Core v5 référencé.';

PlateLoadingResult calculatePlateLoading(
  double weight,
  PlateInventory equipment,
) {
  final calculator = const PlateCalculator();
  final exact = calculator.exact(
    target: weight,
    barWeight: equipment.barWeight,
    inventory: [
      for (final entry in equipment.plates.entries)
        PlateInventoryItem(weight: entry.key, quantity: entry.value),
    ],
  );
  if (exact != null) {
    return PlateLoadingResult(
      requestedWeight: weight,
      loadedWeight: weight,
      perSide: List.unmodifiable(exact.perSide),
      roundingError: 0,
    );
  }
  PlateLoad? nearest;
  for (var delta = 1; delta <= 10000; delta++) {
    final candidate = weight - delta / 1000;
    if (candidate < equipment.barWeight) break;
    nearest = calculator.exact(
      target: candidate,
      barWeight: equipment.barWeight,
      inventory: [
        for (final entry in equipment.plates.entries)
          PlateInventoryItem(weight: entry.key, quantity: entry.value),
      ],
    );
    if (nearest != null) break;
  }
  if (nearest == null) {
    throw ArgumentError(
      'Le poids ne peut pas être chargé avec cet inventaire.',
    );
  }
  return PlateLoadingResult(
    requestedWeight: weight,
    loadedWeight: nearest.target,
    perSide: List.unmodifiable(nearest.perSide),
    roundingError: nearest.target - weight,
  );
}

String serializeProgram(GeneratedProgram plan) => jsonEncode(plan.toJson());

GeneratedProgram deserializeProgram(String payload) {
  final decoded = jsonDecode(payload);
  if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
    throw const FormatException('Version de schéma non prise en charge.');
  }
  final generationName = decoded['generation'];
  final generation = Generation.values
      .where((value) => value.name == generationName)
      .firstOrNull;
  if (generation == null ||
      decoded['payload'] is! Map<String, dynamic> ||
      decoded['sources'] is! List) {
    throw const FormatException('Programme sérialisé invalide.');
  }
  return GeneratedProgram(
    schemaVersion: 1,
    programId: decoded['programId'] as String,
    generation: generation,
    payload: Map<String, Object?>.from(decoded['payload'] as Map),
    sources: [
      for (final raw in decoded['sources'] as List)
        SourceProvenance(
          title: (raw as Map)['title'] as String,
          pages: raw['pages'] as String,
        ),
    ],
    warnings: [
      for (final warning in (decoded['warnings'] as List? ?? const []))
        warning as String,
    ],
  );
}

CatalogCoverageReport getCatalogCoverageReport() =>
    catalog.getCatalogCoverageReport();

MovementId _movement(MainLift lift) => switch (lift) {
  MainLift.squat => MovementId.squat,
  MainLift.benchPress => MovementId.benchPress,
  MainLift.deadlift => MovementId.deadlift,
  MainLift.overheadPress => MovementId.overheadPress,
};
double _progression(MainLift lift, WeightUnit unit) => switch (unit) {
  WeightUnit.kilograms =>
    (lift == MainLift.squat || lift == MainLift.deadlift) ? 5 : 2.5,
  WeightUnit.pounds =>
    (lift == MainLift.squat || lift == MainLift.deadlift) ? 10 : 5,
};

class ProgramGenerationException implements Exception {
  const ProgramGenerationException(this.issues);
  final List<ValidationIssue> issues;
  @override
  String toString() => issues.map((issue) => issue.message).join(' ');
}
