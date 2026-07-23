import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _fslTemplateId = 'source_calculator_first_set_last';
const _gvtTemplateId = 'source_calculator_gvt';
const _standardVariantId = 'standard';
const _fourDayScheduleId = 'schedule_four_day_fixed';
const _sessionOrder = ['overhead_press', 'deadlift', 'bench_press', 'squat'];

void main() {
  late SourceTemplate fslTemplate;
  late SourceTemplate gvtTemplate;
  late List<SourceComponent> components;
  late List<SourceSchedule> sourceSchedules;
  late List<SourceCycleOptionRecipe> optionRecipes;
  late Map<String, Object?> exactGoldens;

  setUpAll(() {
    const codec = CatalogSourceDocumentCodec();
    final templates = codec.decodeTemplates(
      File(
        '../../catalog_src/source_fsl_gvt/templates.json',
      ).readAsStringSync(),
    );
    fslTemplate = templates.singleWhere(
      (candidate) => candidate.id == _fslTemplateId,
    );
    gvtTemplate = templates.singleWhere(
      (candidate) => candidate.id == _gvtTemplateId,
    );
    components = [
      ...codec.decodeComponents(
        File(
          '../../catalog_src/shared/cycle_components_v1.json',
        ).readAsStringSync(),
      ),
      ...codec.decodeComponents(
        File(
          '../../catalog_src/source_fsl_gvt/components.json',
        ).readAsStringSync(),
      ),
    ];
    sourceSchedules = codec.decodeSchedules(
      File(
        '../../catalog_src/schedules/cycle_schedules_v1.json',
      ).readAsStringSync(),
    );
    optionRecipes = codec.decodeCycleOptionRecipes(
      File(
        '../../catalog_src/shared/cycle_option_recipes_v1.json',
      ).readAsStringSync(),
    );
    exactGoldens =
        jsonDecode(
              File(
                '../../test/fixtures/source-calculator-v1/exact-goldens.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  test('source FSL and GVT variants preserve schedules and week topology', () {
    final fsl = fslTemplate.variants.single;
    final gvt = gvtTemplate.variants.single;

    expect(fslTemplate.surface, TemplateSurface.cyclePublic);
    expect(gvtTemplate.surface, TemplateSurface.cyclePublic);
    expect(fsl.id, _standardVariantId);
    expect(gvt.id, _standardVariantId);
    expect(fsl.loadRoundingPolicy, LoadRoundingPolicy.up);
    expect(gvt.loadRoundingPolicy, LoadRoundingPolicy.up);
    expect(fsl.optionRecipeId?.id, 'classic_additional_options');
    expect(gvt.optionRecipeId?.id, 'classic_additional_options');
    expect(fsl.scheduleIds.map((reference) => reference.id), [
      'schedule_four_day_fixed',
      'schedule_three_day_rotating',
    ]);
    expect(gvt.scheduleIds.map((reference) => reference.id), [
      'schedule_four_day_fixed',
      'schedule_three_day_rotating',
      'schedule_two_day_rotating_four_lifts',
    ]);
    expect(fsl.weekPlans.map((week) => week.weekNumber), [1, 2, 3, 4]);
    expect(gvt.weekPlans.map((week) => week.weekNumber), [1, 2, 3, 4]);
    expect(fsl.weekPlans.last.components.map((reference) => reference.id), [
      'deload_original_40_50_60',
    ]);
    expect(gvt.weekPlans.last.components.map((reference) => reference.id), [
      'deload_original_40_50_60',
      'source_gvt_assistance_ohp_default',
      'source_gvt_assistance_deadlift_default',
      'source_gvt_assistance_bench_default',
      'source_gvt_assistance_squat_default',
    ]);
  });

  test('specialized schemas preserve exact source controls and bounds', () {
    final schemas = const CatalogSourceDocumentCodec().decodeOptionSchemas(
      File(
        '../../catalog_src/source_fsl_gvt/option_schemas.json',
      ).readAsStringSync(),
    );
    for (final schema in schemas) {
      expect(schema['includeSchemaIds'], [
        {'id': 'classic_crosscut_options', 'revision': 1},
      ]);
    }

    final fsl = schemas.singleWhere(
      (schema) => schema['id'] == 'source_fsl_options',
    );
    final fslParameters = (fsl['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      _parameter(fslParameters, 'fsl_mode'),
      containsPair('default', 'amrap'),
    );
    expect(_parameter(fslParameters, 'fsl_mode')['allowedValues'], [
      'amrap',
      'multiple',
    ]);
    expect(
      _parameter(fslParameters, 'fsl_set_count'),
      containsPair('allowedValues', [3, 4, 5]),
    );
    expect(_parameter(fslParameters, 'fsl_set_count')['minimum'], 3);
    expect(_parameter(fslParameters, 'fsl_set_count')['maximum'], 5);
    expect(_parameter(fslParameters, 'fsl_repetitions')['allowedValues'], [
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(_parameter(fslParameters, 'fsl_repetitions')['minimum'], 3);
    expect(_parameter(fslParameters, 'fsl_repetitions')['maximum'], 8);

    final gvt = schemas.singleWhere(
      (schema) => schema['id'] == 'source_gvt_options',
    );
    final gvtParameters = (gvt['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final ratio = _parameter(gvtParameters, 'gvt_percentage');
    expect(ratio['scope'], 'perMovement');
    expect(ratio['requestPath'], 'gvt_percentage');
    expect(ratio['default'], 3000);
    expect(ratio['minimum'], 3000);
    expect(ratio['maximum'], 7500);
    expect(ratio['step'], 500);
    expect(ratio['allowedValues'], [
      3000,
      3500,
      4000,
      4500,
      5000,
      5500,
      6000,
      6500,
      7000,
      7500,
    ]);
    expect(_parameter(gvtParameters, 'gvt_alternate')['default'], false);
    expect(_parameter(gvtParameters, 'gvt_use_same_ratio')['default'], true);
  });

  test('ab_wheel is a first-class source-catalog exercise', () {
    final document =
        jsonDecode(
              File(
                '../../catalog_src/exercises/exercises.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final exercise = (document['exercises']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((candidate) => candidate['id'] == 'ab_wheel');

    expect(exercise['sourceRuleIds'], ['app.source_calculator.gvt_assistance']);
    expect(exercise['measurementModes'], ['repetitions']);
    expect(exercise['loadingModes'], ['bodyweight']);
  });

  final fslScenarios = {
    'fsl-amrap-4-day': const _FslOptions(
      mode: 'amrap',
      setCount: 3,
      repetitions: 5,
    ),
    'fsl-multiple-3x5-4-day': const _FslOptions(
      mode: 'multiple',
      setCount: 3,
      repetitions: 5,
    ),
    'fsl-multiple-5x8-4-day': const _FslOptions(
      mode: 'multiple',
      setCount: 5,
      repetitions: 8,
    ),
  };
  for (final entry in fslScenarios.entries) {
    test(
      '${entry.key} matches exact exercise order, repetitions, and loads',
      () {
        final actual = _compile(
          template: fslTemplate,
          components: components,
          sourceSchedules: sourceSchedules,
          optionRecipes: optionRecipes,
          optionValues: {
            'fsl_mode': entry.value.mode,
            'fsl_set_count': entry.value.setCount,
            'fsl_repetitions': entry.value.repetitions,
          },
        );
        final expected = _goldenScenario(exactGoldens, entry.key);

        expect(_canonicalCycle(actual), _canonicalGolden(expected));
      },
    );
  }

  final gvtScenarios = {
    'gvt-10x10-4-day': false,
    'gvt-10x10-alternate-4-day': true,
  };
  for (final entry in gvtScenarios.entries) {
    test('${entry.key} matches exact exercise order, repetitions, and loads', () {
      final actual = _compile(
        template: gvtTemplate,
        components: components,
        sourceSchedules: sourceSchedules,
        optionRecipes: optionRecipes,
        optionValues: {
          'gvt_alternate': entry.value,
          'gvt_use_same_ratio': true,
        },
        gvtPercentage: 3000,
      );
      final expected = _goldenScenario(exactGoldens, entry.key);
      expect(_canonicalCycle(actual), _canonicalGolden(expected));
    });
  }
}

Map<String, Object?> _parameter(
  List<Map<String, Object?>> parameters,
  String id,
) => parameters.singleWhere((parameter) => parameter['id'] == id);

GeneratedCycle _compile({
  required SourceTemplate template,
  required List<SourceComponent> components,
  required List<SourceSchedule> sourceSchedules,
  required List<SourceCycleOptionRecipe> optionRecipes,
  required Map<String, Object?> optionValues,
  int? gvtPercentage,
}) {
  final variant = template.variants.singleWhere(
    (candidate) => candidate.id == _standardVariantId,
  );
  final sourceSchedule = sourceSchedules.singleWhere(
    (candidate) => candidate.reference.id == _fourDayScheduleId,
  );
  final schedule = const CatalogScheduleDataResolver().resolve(sourceSchedule);
  final definition = const CatalogPlanResolver().resolve(
    const CatalogPlanDataResolver().resolve(
      catalogVersion: 2,
      template: template,
      variant: variant,
      scheduleReference: ComponentReference(_fourDayScheduleId, 1),
      schedules: sourceSchedules,
      components: components,
      sourceReference: 'source-calculator-v1/exact-goldens.json',
      optionValues: optionValues,
      optionRecipes: optionRecipes,
    ),
  );
  const trainingDays = [1, 2, 4, 5];
  final request = CycleRequest(
    cycleId: '${template.id}-$_fourDayScheduleId',
    startDate: DateTime(2026, 1, 5),
    trainingDays: trainingDays,
    sessionOrder: [for (final id in _sessionOrder) MovementId(id)],
    maxInputs: const {
      MovementId('overhead_press'): OneRepMaxInput(Weight(7500, WeightUnit.lb)),
      MovementId('deadlift'): OneRepMaxInput(Weight(20000, WeightUnit.lb)),
      MovementId('bench_press'): OneRepMaxInput(Weight(10000, WeightUnit.lb)),
      MovementId('squat'): OneRepMaxInput(Weight(15000, WeightUnit.lb)),
    },
    globalTrainingMaxRatio: const Percentage(9000),
    percentageParametersByMovement: {
      for (final id in _sessionOrder)
        if (gvtPercentage != null)
          MovementId(id): {'gvt_percentage': Percentage(gvtPercentage)},
    },
    unit: WeightUnit.lb,
    roundingIncrement: const Weight(500, WeightUnit.lb),
    barProfile: const BarProfile(
      weight: Weight(4500, WeightUnit.lb),
      platesPerSide: [
        Weight(4500, WeightUnit.lb),
        Weight(2500, WeightUnit.lb),
        Weight(1500, WeightUnit.lb),
        Weight(1000, WeightUnit.lb),
        Weight(500, WeightUnit.lb),
        Weight(250, WeightUnit.lb),
      ],
    ),
    includeDeload: true,
    cycleOptions: const CycleExecutionOptions(
      warmUp: WarmUpExecutionOptions(enabled: true, type: WarmUpType.original),
      deload: DeloadExecutionOptions(
        enabled: true,
        type: DeloadType.type1,
        skipWarmUp: true,
      ),
    ),
  );
  return const CycleCompilerImpl().compileScheduled(
    definition: definition,
    schedule: schedule,
    selection: CycleScheduleSelection(
      trainingDays: trainingDays,
      sessionOrder: [for (final id in _sessionOrder) SessionId(id)],
    ),
    request: request,
  );
}

Map<String, Object?> _goldenScenario(Map<String, Object?> root, String id) =>
    (root['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((scenario) => scenario['id'] == id);

List<Object?> _canonicalGolden(Map<String, Object?> scenario) {
  final output = scenario['output']! as Map<String, Object?>;
  return [
    for (final rawWeek in output['weeks']! as List<Object?>)
      [
        for (final rawSession
            in (rawWeek! as Map<String, Object?>)['sessions']! as List<Object?>)
          [
            for (final rawExercise
                in (rawSession! as Map<String, Object?>)['exercises']!
                    as List<Object?>)
              {
                'movementId': _movementIdForSourceName(
                  (rawExercise! as Map<String, Object?>)['name']! as String,
                ),
                'works': [
                  for (final rawSet
                      in (rawExercise as Map<String, Object?>)['sets']!
                          as List<Object?>)
                    (rawSet! as Map<String, Object?>)['work']! as String,
                ],
              },
          ],
      ],
  ];
}

List<Object?> _canonicalCycle(GeneratedCycle cycle) => [
  for (final week in cycle.weeks)
    [
      for (final session in week.sessions)
        _consecutiveExercises(session.blocks),
    ],
];

List<Map<String, Object?>> _consecutiveExercises(List<GeneratedBlock> blocks) {
  final result = <Map<String, Object?>>[];
  for (final block in blocks) {
    final movementId = block.movementId.value;
    final works = block.sets.map(_generatedWork).toList(growable: false);
    if (result.isNotEmpty && result.last['movementId'] == movementId) {
      (result.last['works']! as List<String>).addAll(works);
    } else {
      result.add({
        'movementId': movementId,
        'works': <String>[...works],
      });
    }
  }
  return result;
}

String _generatedWork(GeneratedSet set) {
  final repetitions = switch (set.repetitions['type']) {
    'fixed' => '${set.repetitions['count']}',
    'amrap' when set.repetitions['minimum'] == null => 'AMRAP',
    'amrap' || 'plus_set' => '${set.repetitions['minimum']}+',
    final type => throw StateError('Unsupported repetition type $type'),
  };
  final load = set.plannedLoad;
  if (load == null) return '$repetitions reps';
  return '$repetitions x ${_formatCentiUnits(load.centiUnits)}';
}

String _formatCentiUnits(int value) {
  if (value % 100 == 0) return '${value ~/ 100}';
  return (value / 100).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String _movementIdForSourceName(String value) => switch (value) {
  'Overhead Press' => 'overhead_press',
  'Deadlift' => 'deadlift',
  'Bench Press' => 'bench_press',
  'Squat' => 'squat',
  'Lat Pulldown' => 'lat_pulldown',
  'Hanging Leg Raise' => 'hanging_leg_raise',
  'Dumbbell Row' => 'dumbbell_row',
  'Ab Wheel' => 'ab_wheel',
  _ => throw StateError('Unknown source exercise $value'),
};

final class _FslOptions {
  const _FslOptions({
    required this.mode,
    required this.setCount,
    required this.repetitions,
  });

  final String mode;
  final int setCount;
  final int repetitions;
}
