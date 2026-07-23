import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _templateId = 'source_calculator_bbb_challenge';
const _scheduleId = 'schedule_four_day_fixed';
const _trainingDays = [1, 2, 4, 5];
const _sessionOrder = ['overhead_press', 'deadlift', 'bench_press', 'squat'];

const _scenarios = <String, _Scenario>{
  'bbb-challenge-six-weeks': _Scenario(
    variantId: 'six_weeks',
    lessBoring: true,
    unit: WeightUnit.lb,
  ),
  'bbb-challenge-six-weeks-same-lift': _Scenario(
    variantId: 'six_weeks',
    lessBoring: false,
    unit: WeightUnit.lb,
  ),
  'bbb-challenge-three-months': _Scenario(
    variantId: 'three_months',
    lessBoring: true,
    unit: WeightUnit.lb,
  ),
  'bbb-challenge-thirteen-weeks': _Scenario(
    variantId: 'thirteen_weeks',
    lessBoring: true,
    unit: WeightUnit.lb,
  ),
  'bbb-challenge-thirteen-weeks-kg': _Scenario(
    variantId: 'thirteen_weeks',
    lessBoring: true,
    unit: WeightUnit.kg,
  ),
};

void main() {
  late SourceTemplate template;
  late List<SourceComponent> components;
  late List<SourceSchedule> schedules;
  late List<SourceCycleOptionRecipe> optionRecipes;
  late Map<String, Object?> exactGoldens;
  late Map<String, GeneratedCycle> cycles;

  setUpAll(() {
    const codec = CatalogSourceDocumentCodec();
    template = codec
        .decodeTemplates(
          File(
            '../../catalog_src/source_bbb_challenge/templates.json',
          ).readAsStringSync(),
        )
        .singleWhere((candidate) => candidate.id == _templateId);
    components = [
      ...codec.decodeComponents(
        File(
          '../../catalog_src/shared/cycle_components_v1.json',
        ).readAsStringSync(),
      ),
      ...codec.decodeComponents(
        File(
          '../../catalog_src/source_bbb_challenge/components.json',
        ).readAsStringSync(),
      ),
    ];
    schedules = codec.decodeSchedules(
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
    cycles = {
      for (final entry in _scenarios.entries)
        entry.key: _compile(
          template: template,
          scenario: entry.value,
          components: components,
          schedules: schedules,
          optionRecipes: optionRecipes,
        ),
    };
  });

  test('catalog exposes the three public Challenge duration variants', () {
    expect(template.surface, TemplateSurface.cyclePublic);
    expect(template.variants.map((variant) => variant.id), [
      'six_weeks',
      'three_months',
      'thirteen_weeks',
    ]);
    final sourceDocument =
        jsonDecode(
              File(
                '../../catalog_src/source_bbb_challenge/templates.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final rawTemplate = (sourceDocument['templates']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    final rawVariants = (rawTemplate['variants']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      [
        for (final variant in rawVariants)
          {
            'id': variant['id'],
            'labelEn':
                (variant['labels']! as Map<String, Object?>)['en'] as String,
          },
      ],
      [
        {'id': 'six_weeks', 'labelEn': 'Six Weeks'},
        {'id': 'three_months', 'labelEn': 'Three Months'},
        {'id': 'thirteen_weeks', 'labelEn': 'Thirteen Weeks'},
      ],
    );
    const expectedPhaseSteps = {
      'six_weeks': [0, 1, 1],
      'three_months': [0, 1, 2],
      'thirteen_weeks': [0, 1, 1, 2, 3, 3],
    };
    const expectedSelectionCounts = {
      'six_weeks': 10,
      'three_months': 10,
      'thirteen_weeks': 14,
    };
    for (final variant in template.variants) {
      expect(variant.loadRoundingPolicy, LoadRoundingPolicy.up);
      expect(variant.optionRecipeId?.id, 'classic_additional_options');
      expect(variant.optionSchemaId.id, 'source_bbb_challenge_options');
      expect(variant.scheduleIds.map((reference) => reference.id), [
        _scheduleId,
      ]);
      expect(variant.weekPlans, isEmpty);
      expect(
        variant.phases.map((phase) => phase.trainingMaxProgressionStep),
        expectedPhaseSteps[variant.id],
      );
      expect(
        variant.componentSelections,
        hasLength(expectedSelectionCounts[variant.id]!),
      );
    }
  });

  test('Less boring is one global boolean defaulting to cross-lift work', () {
    final schemas = const CatalogSourceDocumentCodec().decodeOptionSchemas(
      File(
        '../../catalog_src/source_bbb_challenge/option_schemas.json',
      ).readAsStringSync(),
    );
    final schema = schemas.single;

    expect(schema['id'], 'source_bbb_challenge_options');
    expect(schema['includeSchemaIds'], [
      {'id': 'classic_crosscut_options', 'revision': 1},
    ]);
    final parameter = (schema['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    expect(parameter['id'], 'bbb_challenge_less_boring');
    expect(parameter['type'], 'boolean');
    expect(parameter['scope'], 'global');
    expect(parameter['default'], true);
    expect(parameter['allowedValues'], [true, false]);
  });

  for (final id in _scenarios.keys) {
    test('$id matches every captured exercise, set, load, and plate', () {
      final expected = _goldenScenario(exactGoldens, id);

      _expectExact(
        _canonicalCycle(cycles[id]!),
        _canonicalGolden(expected),
        reason: id,
      );
    });
  }

  test('Six Weeks is the exact seven-week prefix of Thirteen Weeks', () {
    final sixWeeks = _canonicalCycle(cycles['bbb-challenge-six-weeks']!);
    final thirteenWeeks = _canonicalCycle(
      cycles['bbb-challenge-thirteen-weeks']!,
    );

    expect(sixWeeks, hasLength(7));
    _expectExact(
      sixWeeks,
      thirteenWeeks.take(sixWeeks.length).toList(growable: false),
      reason: 'six_weeks prefix',
    );
  });

  test('training-max progression preserves exact lb and kg increments', () {
    for (final variant in template.variants) {
      final progression =
          variant.trainingMaxProgression
              as LinearPhaseStepTrainingMaxProgression;
      expect(
        progression.incrementFor(
          WeightUnit.lb,
          const MovementId('overhead_press'),
        ),
        500,
      );
      expect(
        progression.incrementFor(
          WeightUnit.lb,
          const MovementId('bench_press'),
        ),
        500,
      );
      expect(
        progression.incrementFor(WeightUnit.lb, const MovementId('squat')),
        1000,
      );
      expect(
        progression.incrementFor(WeightUnit.lb, const MovementId('deadlift')),
        1000,
      );
      expect(
        progression.incrementFor(
          WeightUnit.kg,
          const MovementId('overhead_press'),
        ),
        250,
      );
      expect(
        progression.incrementFor(
          WeightUnit.kg,
          const MovementId('bench_press'),
        ),
        250,
      );
      expect(
        progression.incrementFor(WeightUnit.kg, const MovementId('squat')),
        500,
      );
      expect(
        progression.incrementFor(WeightUnit.kg, const MovementId('deadlift')),
        500,
      );
    }

    expect(
      _phaseTrainingMaxes(
        cycles['bbb-challenge-thirteen-weeks-kg']!,
        template.variants
                .singleWhere((variant) => variant.id == 'thirteen_weeks')
                .trainingMaxProgression
            as LinearPhaseStepTrainingMaxProgression,
        const [0, 1, 2, 3],
      ),
      [
        {
          'overhead_press': 6750,
          'deadlift': 18000,
          'bench_press': 9000,
          'squat': 13500,
        },
        {
          'overhead_press': 7000,
          'deadlift': 18500,
          'bench_press': 9250,
          'squat': 14000,
        },
        {
          'overhead_press': 7250,
          'deadlift': 19000,
          'bench_press': 9500,
          'squat': 14500,
        },
        {
          'overhead_press': 7500,
          'deadlift': 19500,
          'bench_press': 9750,
          'squat': 15000,
        },
      ],
    );
  });

  test('deload off removes every structural deload week', () {
    const expectedLengths = {
      'six_weeks': 6,
      'three_months': 9,
      'thirteen_weeks': 12,
    };

    for (final entry in expectedLengths.entries) {
      final cycle = _compile(
        template: template,
        scenario: _Scenario(
          variantId: entry.key,
          lessBoring: true,
          unit: WeightUnit.lb,
          includeDeload: false,
        ),
        components: components,
        schedules: schedules,
        optionRecipes: optionRecipes,
      );

      expect(cycle.weeks, hasLength(entry.value), reason: entry.key);
      expect(
        cycle.weeks
            .expand((week) => week.sessions)
            .expand((session) => session.blocks)
            .where((block) => block.role == 'deload'),
        isEmpty,
        reason: entry.key,
      );
    }
  });
}

GeneratedCycle _compile({
  required SourceTemplate template,
  required _Scenario scenario,
  required List<SourceComponent> components,
  required List<SourceSchedule> schedules,
  required List<SourceCycleOptionRecipe> optionRecipes,
}) {
  final variant = template.variants.singleWhere(
    (candidate) => candidate.id == scenario.variantId,
  );
  final sourceSchedule = schedules.singleWhere(
    (candidate) => candidate.reference.id == _scheduleId,
  );
  final schedule = const CatalogScheduleDataResolver().resolve(sourceSchedule);
  final definition = const CatalogPlanResolver().resolve(
    const CatalogPlanDataResolver().resolve(
      catalogVersion: 2,
      template: template,
      variant: variant,
      scheduleReference: ComponentReference(_scheduleId, 1),
      schedules: schedules,
      components: components,
      sourceReference: 'source-calculator-v1/exact-goldens.json',
      optionValues: {'bbb_challenge_less_boring': scenario.lessBoring},
      optionRecipes: optionRecipes,
    ),
  );
  final unit = scenario.unit;
  final request = CycleRequest(
    cycleId: '${scenario.variantId}-${unit.name}-${scenario.lessBoring}',
    startDate: DateTime(2026, 1, 5),
    trainingDays: _trainingDays,
    sessionOrder: [for (final id in _sessionOrder) MovementId(id)],
    maxInputs: {
      MovementId('overhead_press'): OneRepMaxInput(Weight(7500, unit)),
      MovementId('deadlift'): OneRepMaxInput(Weight(20000, unit)),
      MovementId('bench_press'): OneRepMaxInput(Weight(10000, unit)),
      MovementId('squat'): OneRepMaxInput(Weight(15000, unit)),
    },
    globalTrainingMaxRatio: const Percentage(9000),
    unit: unit,
    roundingIncrement: Weight(unit == WeightUnit.lb ? 500 : 250, unit),
    barProfile: _barProfile(unit),
    includeDeload: scenario.includeDeload,
    cycleOptions: CycleExecutionOptions(
      warmUp: const WarmUpExecutionOptions(
        enabled: true,
        type: WarmUpType.original,
      ),
      joker: const JokerExecutionOptions.disabled(),
      deload: scenario.includeDeload
          ? const DeloadExecutionOptions(
              enabled: true,
              type: DeloadType.type1,
              skipWarmUp: true,
            )
          : const DeloadExecutionOptions.disabled(),
    ),
  );
  return const CycleCompilerImpl().compileScheduled(
    definition: definition,
    schedule: schedule,
    selection: const CycleScheduleSelection(
      trainingDays: _trainingDays,
      sessionOrder: [
        SessionId('overhead_press'),
        SessionId('deadlift'),
        SessionId('bench_press'),
        SessionId('squat'),
      ],
    ),
    request: request,
  );
}

BarProfile _barProfile(WeightUnit unit) {
  if (unit == WeightUnit.lb) {
    return BarProfile(
      weight: const Weight(4500, WeightUnit.lb),
      platesPerSide: [
        for (var index = 0; index < 10; index++)
          const Weight(4500, WeightUnit.lb),
        const Weight(2500, WeightUnit.lb),
        const Weight(1000, WeightUnit.lb),
        const Weight(1000, WeightUnit.lb),
        const Weight(500, WeightUnit.lb),
        const Weight(250, WeightUnit.lb),
      ],
    );
  }
  return BarProfile(
    weight: const Weight(2000, WeightUnit.kg),
    platesPerSide: [
      for (var index = 0; index < 10; index++)
        const Weight(2000, WeightUnit.kg),
      const Weight(1000, WeightUnit.kg),
      const Weight(500, WeightUnit.kg),
      const Weight(250, WeightUnit.kg),
      const Weight(125, WeightUnit.kg),
    ],
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
                'sets': [
                  for (final rawSet
                      in (rawExercise as Map<String, Object?>)['sets']!
                          as List<Object?>)
                    {
                      'work':
                          (rawSet! as Map<String, Object?>)['work']! as String,
                      'plates': [
                        for (final plate
                            in (rawSet as Map<String, Object?>)['plates']!
                                as List<Object?>)
                          ..._plateCentiUnits(plate! as String),
                      ],
                    },
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
    final sets = [
      for (final set in block.sets)
        {
          'work': _generatedWork(set),
          'plates': [for (final plate in set.platesPerSide) plate.centiUnits],
        },
    ];
    if (result.isNotEmpty && result.last['movementId'] == movementId) {
      (result.last['sets']! as List<Object?>).addAll(sets);
    } else {
      result.add({
        'movementId': movementId,
        'sets': <Object?>[...sets],
      });
    }
  }
  return result;
}

String _generatedWork(GeneratedSet set) {
  final repetitions = switch (set.repetitions['type']) {
    'fixed' => '${set.repetitions['count']}',
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

List<int> _plateCentiUnits(String value) {
  final match = RegExp(r'^(?:(\d+)\s+x\s+)?(.+)$').firstMatch(value)!;
  final count = int.parse(match.group(1) ?? '1');
  final normalized = match
      .group(2)!
      .replaceAll('\u00C2', '')
      .replaceAll('\u00BD', '.5')
      .replaceAll('\u00BC', '.25')
      .replaceAll('\u00BE', '.75');
  final centiUnits = (double.parse(normalized) * 100).round();
  return List<int>.filled(count, centiUnits);
}

List<Map<String, int>> _phaseTrainingMaxes(
  GeneratedCycle cycle,
  LinearPhaseStepTrainingMaxProgression progression,
  List<int> steps,
) => [
  for (final step in steps)
    {
      for (final entry in cycle.effectiveTrainingMaxes.entries)
        entry.key:
            entry.value.centiUnits +
            progression.incrementFor(entry.value.unit, MovementId(entry.key))! *
                step,
    },
];

void _expectExact(Object? actual, Object? expected, {required String reason}) {
  final difference = _firstDifference(actual, expected);
  expect(difference, isNull, reason: reason);
}

String? _firstDifference(
  Object? actual,
  Object? expected, [
  String path = r'$',
]) {
  if (actual is List<Object?> && expected is List<Object?>) {
    if (actual.length != expected.length) {
      return '$path.length: expected ${expected.length}, actual ${actual.length}';
    }
    for (var index = 0; index < actual.length; index++) {
      final difference = _firstDifference(
        actual[index],
        expected[index],
        '$path[$index]',
      );
      if (difference != null) return difference;
    }
    return null;
  }
  if (actual is Map<String, Object?> && expected is Map<String, Object?>) {
    if (actual.keys.toSet().difference(expected.keys.toSet()).isNotEmpty ||
        expected.keys.toSet().difference(actual.keys.toSet()).isNotEmpty) {
      return '$path.keys: expected ${expected.keys}, actual ${actual.keys}';
    }
    for (final key in actual.keys) {
      final difference = _firstDifference(
        actual[key],
        expected[key],
        '$path.$key',
      );
      if (difference != null) return difference;
    }
    return null;
  }
  if (actual != expected) {
    return '$path: expected $expected, actual $actual';
  }
  return null;
}

String _movementIdForSourceName(String value) => switch (value) {
  'Overhead Press' => 'overhead_press',
  'Deadlift' => 'deadlift',
  'Bench Press' => 'bench_press',
  'Squat' => 'squat',
  'Dumbbell Row' => 'dumbbell_row',
  'Rear Lats Raises' => 'rear_lateral_raise',
  'Hanging Leg Raise' => 'hanging_leg_raise',
  'Pull Up' => 'pull_up',
  'Bicep Curl' => 'curl',
  'Ab Wheel' => 'ab_wheel',
  _ => throw StateError('Unknown source exercise $value'),
};

final class _Scenario {
  const _Scenario({
    required this.variantId,
    required this.lessBoring,
    required this.unit,
    this.includeDeload = true,
  });

  final String variantId;
  final bool lessBoring;
  final WeightUnit unit;
  final bool includeDeload;
}
