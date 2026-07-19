import 'dart:convert';

import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

/// Thin translation layer between form values and the pure Dart CORE.
/// It deliberately contains no prescription, percentage, or compatibility rule.
class DomainPoc531GeneratorCore implements Poc531GeneratorCore {
  const DomainPoc531GeneratorCore();

  @override
  GeneratorOptions get options {
    final programs = core.listPrograms(
      const core.ProgramFilters(includeLegacy: true),
    );
    return GeneratorOptions(
      programs: [
        for (final program in programs)
          ProgramChoice(
            id: program.id,
            name: program.name,
            generation: program.generation!.name,
            family: program.family,
            variant: program.variant,
            status: program.status.name,
          ),
      ],
      // These values are presentation placeholders until the catalog exposes
      // typed option lists. They do not alter the generated prescription.
      supplemental: const ['Selon la définition CORE'],
      assistance: const ['Selon la définition CORE'],
      conditioning: const ['Selon la définition CORE'],
      transitions: const ['Selon la définition CORE'],
    );
  }

  @override
  Future<List<GeneratorWarning>> validate(
    Map<String, Object?> configuration,
  ) async {
    final parsed = _configuration(configuration);
    if (parsed == null) return const [];
    return [
      for (final issue in core.validateProgramConfiguration(parsed))
        GeneratorWarning(issue.message, isError: issue.blocking),
    ];
  }

  @override
  Future<GeneratorResult> generate(Map<String, Object?> configuration) async {
    final parsed = _configuration(configuration);
    if (parsed == null) {
      throw const FormatException('Configuration incomplète.');
    }
    final plan = core.generateProgram(parsed);
    final definition = core.getProgramDefinition(plan.programId)!;
    return GeneratorResult(
      title: definition.name,
      blocks: _payloadToBlocks(plan.payload),
      explanation: core.explainGeneratedProgram(plan),
      sources: [
        for (final source in plan.sources) '${source.title} — ${source.pages}',
      ],
      warnings: [
        for (final warning in plan.warnings) GeneratorWarning(warning),
      ],
      exportJson: core.serializeProgram(plan),
    );
  }

  @override
  Future<String> serializeConfiguration(
    Map<String, Object?> configuration,
  ) async => jsonEncode(configuration);

  @override
  Future<PlateLoadingView> calculatePlateLoading({
    required double weight,
    required double barWeight,
    required List<double> inventory,
    required String unit,
  }) async {
    final result = core.calculatePlateLoading(
      weight,
      core.PlateInventory(
        barWeight: barWeight,
        plates: {for (final plate in inventory) plate: 2},
      ),
    );
    return PlateLoadingView(
      perSide: result.perSide,
      actualWeight: result.loadedWeight,
      roundingError: result.roundingError,
    );
  }

  core.ProgramConfiguration? _configuration(Map<String, Object?> value) {
    final id = value['programId'] as String?;
    final liftValues = value['lifts'];
    if (id == null || liftValues is! Map) return null;
    final generation = core.Generation.values
        .where((item) => item.name == value['generation'])
        .firstOrNull;
    if (generation == null) return null;
    final kind = switch (value['inputMode']) {
      'Training Max' => core.LiftInputKind.trainingMax,
      'Rep max' => core.LiftInputKind.repetitionMax,
      _ => core.LiftInputKind.oneRepMax,
    };
    const names = {
      core.MainLift.overheadPress: 'Press',
      core.MainLift.benchPress: 'Bench Press',
      core.MainLift.squat: 'Squat',
      core.MainLift.deadlift: 'Deadlift',
    };
    final repetitions = value['repetitions'];
    final days = value['days'] as int? ?? 4;
    return core.ProgramConfiguration(
      programId: id,
      generation: generation,
      unit: value['unit'] == 'lb'
          ? core.WeightUnit.pounds
          : core.WeightUnit.kilograms,
      lifts: {
        for (final entry in names.entries)
          entry.key: core.LiftInput(
            lift: entry.key,
            kind: kind,
            weight: (liftValues[entry.value] as num?)?.toDouble() ?? 0,
            repetitions: repetitions is Map
                ? repetitions[entry.value] as int?
                : null,
          ),
      },
      trainingMaxRatio:
          ((value['trainingMaxRatio'] as num?)?.toDouble() ?? 90) /
          (((value['trainingMaxRatio'] as num?)?.toDouble() ?? 90) > 1
              ? 100
              : 1),
      daysPerWeek: days,
      trainingWeekdays: List<int>.generate(days, (index) => index + 1),
      options: core.GenerationSpecificOptions(
        projectFutureTrainingMaxes:
            value['projectFutureTrainingMaxes'] as bool? ?? false,
      ),
      startDate: DateTime.utc(2026, 1, 5),
    );
  }

  List<PlanBlockView> _payloadToBlocks(Map<String, Object?> payload) {
    final rawBlocks = payload['blocks'] ?? payload['cycles'];
    if (rawBlocks is! List) {
      return [
        PlanBlockView('Plan', [
          PlanWeekView('Données CORE', [
            PlanSessionView('Prescription structurée', [jsonEncode(payload)]),
          ]),
        ]),
      ];
    }
    return [
      for (var blockIndex = 0; blockIndex < rawBlocks.length; blockIndex++)
        _block(rawBlocks[blockIndex], blockIndex),
    ];
  }

  PlanBlockView _block(Object? raw, int index) {
    final map = raw is Map ? raw : const {};
    final rawWeeks = map['weeks'];
    return PlanBlockView(
      '${map['name'] ?? map['kind'] ?? 'Bloc ${index + 1}'}',
      [
        if (rawWeeks is List)
          for (var weekIndex = 0; weekIndex < rawWeeks.length; weekIndex++)
            _week(rawWeeks[weekIndex], weekIndex)
        else
          PlanWeekView('Contenu', [
            PlanSessionView('Prescription', [jsonEncode(raw)]),
          ]),
      ],
    );
  }

  PlanWeekView _week(Object? raw, int index) {
    final map = raw is Map ? raw : const {};
    final rawSessions = map['sessions'] ?? map['workouts'];
    return PlanWeekView('${map['name'] ?? 'Semaine ${index + 1}'}', [
      if (rawSessions is List)
        for (
          var sessionIndex = 0;
          sessionIndex < rawSessions.length;
          sessionIndex++
        )
          PlanSessionView('Séance ${sessionIndex + 1}', [
            jsonEncode(rawSessions[sessionIndex]),
          ])
      else
        PlanSessionView('Prescription', [jsonEncode(raw)]),
    ]);
  }
}
