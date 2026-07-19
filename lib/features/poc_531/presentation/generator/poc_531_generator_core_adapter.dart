import 'dart:convert';

import 'package:hybrid_training/features/poc_531/domain/calculator/calculator.dart'
    as calc;
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/domain/forever_calculator/forever_calculator.dart'
    as forever;
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

/// Translation-only adapter. Every prescription and compatibility decision is
/// delegated to one of the two pure calculator engines.
class DomainPoc531GeneratorCore implements Poc531GeneratorCore {
  const DomainPoc531GeneratorCore();

  @override
  GeneratorOptions get options => GeneratorOptions(
    classicTemplates: [
      for (final template in calc.calculatorTemplates)
        if (template.id != calc.CalculatorTemplateId.standard)
          CalculatorTemplateChoice(
            id: template.id.name,
            name: template.label,
            allowedDays: template.allowedDays.toList()..sort(),
            variants: [
              for (final variant in template.variants)
                CalculatorVariantChoice(
                  id: variant.id,
                  name: variant.label,
                  executable: variant.executable,
                  allowedDays: variant.allowedDays.toList()..sort(),
                  blockedReason: variant.blockedReason,
                ),
            ],
          ),
    ],
    foreverTemplates: [
      for (final template in forever.listForeverCalculatorTemplates())
        ForeverTemplateChoice(
          id: template.id,
          name: template.name,
          variant: template.variant,
          executable: template.selectable,
          days: template.daysPerWeek,
          blockedReason: template.unavailableReason,
          sequence: [
            for (final block in template.sequence)
              '${_blockLabel(block.kind)} · semaines ${block.startWeek}–${block.startWeek + block.durationWeeks - 1}',
          ],
        ),
    ],
  );

  static String _blockLabel(forever.ForeverBlockKind kind) => switch (kind) {
    forever.ForeverBlockKind.leader => 'Leader',
    forever.ForeverBlockKind.anchor => 'Anchor',
    forever.ForeverBlockKind.seventhWeekDeload => '7th Week Deload',
    forever.ForeverBlockKind.seventhWeekTmTest => '7th Week TM Test',
  };

  @override
  Future<List<GeneratorWarning>> validate(Map<String, Object?> value) async {
    if (value['mode'] == 'forever') {
      final configuration = _foreverConfiguration(value);
      if (configuration == null) return const [];
      return [
        for (final issue in forever.validateForeverCalculatorConfiguration(
          configuration,
        ))
          GeneratorWarning(issue.message, isError: issue.blocking),
      ];
    }
    final configuration = _classicConfiguration(value);
    if (configuration == null) return const [];
    return [
      for (final issue in const calc.ClassicCalculatorEngine().validate(
        configuration,
      ))
        GeneratorWarning(issue.message, isError: issue.blocking),
    ];
  }

  @override
  Future<GeneratorResult> generate(Map<String, Object?> value) async {
    if (value['mode'] == 'forever') {
      final configuration = _foreverConfiguration(value);
      if (configuration == null) {
        throw const FormatException('Configuration incomplète.');
      }
      final plan = forever.generateForeverCalculatorProgram(configuration);
      final definition = core.getProgramDefinition(plan.programId)!;
      return GeneratorResult(
        title: definition.name,
        blocks: _payloadToBlocks(plan.payload),
        explanation: core.explainGeneratedProgram(plan),
        sources: [
          for (final source in plan.sources)
            '${source.title} · ${source.pages}',
        ],
        warnings: [
          for (final warning in plan.warnings) GeneratorWarning(warning),
        ],
        exportJson: forever.serializeForeverCalculatorProgram(plan),
      );
    }
    final configuration = _classicConfiguration(value);
    if (configuration == null) {
      throw const FormatException('Configuration incomplète.');
    }
    final program = const calc.ClassicCalculatorEngine().generate(
      configuration,
    );
    return GeneratorResult(
      title: calc.calculatorTemplate(configuration.template).label,
      blocks: [
        PlanBlockView('Cycle', [
          for (final week in program.weeks) _classicWeek(week),
        ]),
      ],
      sources: [
        for (final source in program.sources)
          '${source.title} · ${source.pages}',
      ],
      warnings: [
        for (final warning in program.warnings) GeneratorWarning(warning),
      ],
      exportJson: jsonEncode(program.toJson()),
    );
  }

  static PlanWeekView _classicWeek(calc.CalculatorWeek week) => PlanWeekView(
    week.deload ? 'Semaine ${week.number} · Deload' : 'Semaine ${week.number}',
    [
      for (final session in week.sessions)
        PlanSessionView(_liftLabel(session.lift), [
          for (final set in session.sets)
            '${set.kind == 'supplemental' ? 'SUP · ' : ''}${set.repetitions}${set.amrap ? '+' : ''} × ${set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1)} · ${set.percent}%',
        ]),
    ],
  );

  static String _liftLabel(String id) => switch (id) {
    'press' => 'Overhead Press',
    'bench' => 'Bench Press',
    'squat' => 'Squat',
    'deadlift' => 'Deadlift',
    _ => id,
  };

  calc.CalculatorConfiguration? _classicConfiguration(
    Map<String, Object?> value,
  ) {
    final templateName = value['templateId'] as String?;
    final variant = value['variantId'] as String?;
    final maxes = _trainingMaxes(value);
    if (templateName == null || variant == null || maxes == null) return null;
    return calc.CalculatorConfiguration(
      template: calc.CalculatorTemplateId.values.byName(templateName),
      variantId: variant,
      trainingMaxes: maxes,
      daysPerWeek: value['days'] as int? ?? 4,
      supplementalPercent: value['supplementalPercent'] as int? ?? 50,
      liftOrder:
          (value['liftOrder'] as List?)?.cast<String>() ??
          const ['press', 'deadlift', 'bench', 'squat'],
      options: calc.CalculatorOptions(
        order: value['weekOrder'] == '351'
            ? calc.MainWorkOrder.threeFiveOne
            : calc.MainWorkOrder.fiveThreeOne,
        warmup: calc.WarmupOption.values.byName(
          value['warmup'] as String? ?? 'none',
        ),
        jokersEnabled: value['jokersEnabled'] as bool? ?? false,
        jokerIncrementPercent: value['jokerIncrement'] as int? ?? 5,
        jokerCapPercent: value['jokerCap'] as int? ?? 10,
        deload: calc.DeloadOption.values.byName(
          value['deload'] as String? ?? 'deload1',
        ),
        skipWarmupDuringDeload: value['skipDeloadWarmup'] as bool? ?? false,
      ),
    );
  }

  core.ProgramConfiguration? _foreverConfiguration(Map<String, Object?> value) {
    final id = value['foreverTemplateId'] as String?;
    final lifts = _liftInputs(value);
    if (id == null || lifts == null) return null;
    final days = value['days'] as int? ?? 4;
    return core.ProgramConfiguration(
      programId: id,
      generation: core.Generation.forever,
      unit: value['unit'] == 'lb'
          ? core.WeightUnit.pounds
          : core.WeightUnit.kilograms,
      lifts: lifts,
      trainingMaxRatio:
          ((value['trainingMaxRatio'] as num?)?.toDouble() ?? 90) / 100,
      daysPerWeek: days,
      trainingWeekdays: List.generate(days, (index) => index + 1),
      options: const core.GenerationSpecificOptions(
        projectFutureTrainingMaxes: true,
      ),
      startDate: DateTime.utc(2026, 1, 5),
    );
  }

  Map<String, double>? _trainingMaxes(Map<String, Object?> value) {
    final inputs = _liftInputs(value);
    if (inputs == null) return null;
    final ratio = ((value['trainingMaxRatio'] as num?)?.toDouble() ?? 90) / 100;
    return {
      for (final entry in inputs.entries)
        _coreLiftId(entry.key): core
            .deriveTrainingMax(input: entry.value, ratio: ratio)
            .trainingMax,
    };
  }

  Map<core.MainLift, core.LiftInput>? _liftInputs(Map<String, Object?> value) {
    final raw = value['lifts'];
    if (raw is! Map) return null;
    final reps = value['repetitions'];
    final kind = switch (value['inputMode']) {
      'tm' => core.LiftInputKind.trainingMax,
      'repMax' || 'plusSet' => core.LiftInputKind.repetitionMax,
      _ => core.LiftInputKind.oneRepMax,
    };
    const names = {
      core.MainLift.overheadPress: 'Press',
      core.MainLift.benchPress: 'Bench Press',
      core.MainLift.squat: 'Squat',
      core.MainLift.deadlift: 'Deadlift',
    };
    final result = <core.MainLift, core.LiftInput>{};
    for (final entry in names.entries) {
      final weight = raw[entry.value];
      if (weight is! num || weight <= 0) return null;
      result[entry.key] = core.LiftInput(
        lift: entry.key,
        kind: kind,
        weight: weight.toDouble(),
        repetitions: reps is Map ? reps[entry.value] as int? : null,
      );
    }
    return result;
  }

  static String _coreLiftId(core.MainLift lift) => switch (lift) {
    core.MainLift.overheadPress => 'press',
    core.MainLift.benchPress => 'bench',
    core.MainLift.squat => 'squat',
    core.MainLift.deadlift => 'deadlift',
  };

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

  static List<PlanBlockView> _payloadToBlocks(Map<String, Object?> payload) {
    final rawBlocks = payload['blocks'] ?? payload['cycles'];
    if (rawBlocks is! List) {
      return [
        PlanBlockView('Plan', [
          PlanWeekView('Programme', [
            PlanSessionView('Prescription', [jsonEncode(payload)]),
          ]),
        ]),
      ];
    }
    return [for (var i = 0; i < rawBlocks.length; i++) _block(rawBlocks[i], i)];
  }

  static PlanBlockView _block(Object? raw, int index) {
    final map = raw is Map ? raw : const {};
    final weeks = map['weeks'];
    return PlanBlockView(
      '${map['name'] ?? map['kind'] ?? 'Bloc ${index + 1}'}',
      [
        if (weeks is List)
          for (var i = 0; i < weeks.length; i++) _week(weeks[i], i)
        else
          PlanWeekView('Contenu', [
            PlanSessionView('Prescription', [jsonEncode(raw)]),
          ]),
      ],
    );
  }

  static PlanWeekView _week(Object? raw, int index) {
    final map = raw is Map ? raw : const {};
    final sessions = map['sessions'] ?? map['workouts'];
    return PlanWeekView('${map['name'] ?? 'Semaine ${index + 1}'}', [
      if (sessions is List)
        for (var i = 0; i < sessions.length; i++)
          PlanSessionView('Séance ${i + 1}', [jsonEncode(sessions[i])])
      else
        PlanSessionView('Prescription', [jsonEncode(raw)]),
    ]);
  }
}
