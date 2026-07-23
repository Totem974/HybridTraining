import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _templateId = 'source_calculator_two_days_per_week';
const _pairedScheduleId = 'schedule_two_day_paired_source_order';
const _rotatingScheduleId = 'schedule_two_day_rotating_four_lifts';
const _trainingDays = [1, 4];

const _scenarios = <String, _Scenario>{
  'two-day-option-one-deload': _Scenario(
    variantId: 'option_one',
    scheduleId: _pairedScheduleId,
    sessionOrder: ['deadlift_overhead_press', 'squat_bench_press'],
  ),
  'two-day-option-one-no-deload': _Scenario(
    variantId: 'option_one',
    scheduleId: _pairedScheduleId,
    sessionOrder: ['deadlift_overhead_press', 'squat_bench_press'],
    includeDeload: false,
  ),
  'two-day-option-two-deload': _Scenario(
    variantId: 'option_two',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
  ),
  'two-day-option-two-no-deload': _Scenario(
    variantId: 'option_two',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    includeDeload: false,
  ),
  'two-day-option-three-profile-65-75-85': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
  ),
  'two-day-option-three-profile-70-80-90': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    secondLiftProfile: '70_80_90',
  ),
  'two-day-option-three-profile-75-85-95': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    secondLiftProfile: '75_85_95',
  ),
  'two-day-option-three-profile-80-90-100': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    secondLiftProfile: '80_90_100',
  ),
  'two-day-option-three-no-deload': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    includeDeload: false,
  ),
  'two-day-option-one-reordered-pairs': _Scenario(
    variantId: 'option_one',
    scheduleId: _pairedScheduleId,
    sessionOrder: ['squat_bench_press', 'deadlift_overhead_press'],
  ),
  'two-day-option-three-reordered-lifts': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['squat', 'overhead_press', 'deadlift', 'bench_press'],
  ),
  'two-day-option-one-warmup-joker': _Scenario(
    variantId: 'option_one',
    scheduleId: _pairedScheduleId,
    sessionOrder: ['deadlift_overhead_press', 'squat_bench_press'],
    jokerCeilingBasisPoints: 500,
  ),
  'two-day-option-three-deload-two': _Scenario(
    variantId: 'option_three',
    scheduleId: _rotatingScheduleId,
    sessionOrder: ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    deloadType: DeloadType.type2,
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
            '../../catalog_src/source_two_day/templates.json',
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
          '../../catalog_src/source_two_day/components.json',
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

  test('catalog exposes three public source variants with exact schedules', () {
    expect(template.surface, TemplateSurface.cyclePublic);
    expect(template.variants.map((variant) => variant.id), [
      'option_one',
      'option_two',
      'option_three',
    ]);
    for (final variant in template.variants) {
      expect(variant.loadRoundingPolicy, LoadRoundingPolicy.up);
      expect(variant.optionRecipeId?.id, 'classic_additional_options');
      expect(variant.weekPlans.map((week) => week.weekNumber), [1, 2, 3, 4]);
      expect(variant.phases, isEmpty);
    }
    expect(
      template.variants
          .singleWhere((variant) => variant.id == 'option_one')
          .scheduleIds
          .map((reference) => reference.id),
      [_pairedScheduleId],
    );
    for (final id in ['option_two', 'option_three']) {
      expect(
        template.variants
            .singleWhere((variant) => variant.id == id)
            .scheduleIds
            .map((reference) => reference.id),
        [_rotatingScheduleId],
      );
    }
  });

  test('Option Three exposes four profiles through paired selections', () {
    final variant = template.variants.singleWhere(
      (candidate) => candidate.id == 'option_three',
    );

    expect(variant.componentSelections, hasLength(2));
    for (final selection in variant.componentSelections) {
      expect(selection.parameterId, 'second_lift_profile');
      expect(selection.choices.map((choice) => choice.value), [
        '65_75_85',
        '70_80_90',
        '75_85_95',
        '80_90_100',
      ]);
    }
    final deloadReferences = variant.weekPlans.last.components
        .map((reference) => reference.id)
        .toList(growable: false);
    expect(deloadReferences.first, 'source_two_day_three_before_65_75_85');
    expect(deloadReferences, contains('deload_original_40_50_60'));
    expect(deloadReferences, contains('source_two_day_three_after_65_75_85'));
  });

  test('specialized schemas compose cross-cut options and exact profiles', () {
    final schemas = const CatalogSourceDocumentCodec().decodeOptionSchemas(
      File(
        '../../catalog_src/source_two_day/option_schemas.json',
      ).readAsStringSync(),
    );
    for (final schema in schemas) {
      expect(schema['includeSchemaIds'], [
        {'id': 'classic_crosscut_options', 'revision': 1},
      ]);
    }
    final optionThree = schemas.singleWhere(
      (schema) => schema['id'] == 'source_two_day_option_three_options',
    );
    final profile = (optionThree['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    expect(profile['id'], 'second_lift_profile');
    expect(profile['default'], '65_75_85');
    expect(profile['allowedValues'], [
      '65_75_85',
      '70_80_90',
      '75_85_95',
      '80_90_100',
    ]);
  });

  test('dumbbell_side_bend is a first-class source exercise', () {
    final document =
        jsonDecode(
              File(
                '../../catalog_src/exercises/exercises.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final exercise = (document['exercises']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((candidate) => candidate['id'] == 'dumbbell_side_bend');

    expect(exercise['sourceRuleIds'], [
      'app.source_calculator.two_day_assistance',
    ]);
    expect(exercise['categories'], ['singleLegCore']);
    expect(exercise['measurementModes'], ['repetitions']);
    expect(exercise['loadingModes'], ['externalWeight']);
  });

  for (final id in _scenarios.keys) {
    test('$id matches exact exercise, set, load, and plate order', () {
      final expected = _goldenScenario(exactGoldens, id);

      _expectExact(
        _canonicalCycle(cycles[id]!),
        _canonicalGolden(expected),
        reason: id,
      );
    });
  }

  test('deload-off cycles are exact prefixes of their deload counterparts', () {
    const pairs = [
      (
        without: 'two-day-option-one-no-deload',
        withDeload: 'two-day-option-one-deload',
      ),
      (
        without: 'two-day-option-two-no-deload',
        withDeload: 'two-day-option-two-deload',
      ),
      (
        without: 'two-day-option-three-no-deload',
        withDeload: 'two-day-option-three-profile-65-75-85',
      ),
    ];
    for (final pair in pairs) {
      final without = _canonicalCycle(cycles[pair.without]!);
      final withDeload = _canonicalCycle(cycles[pair.withDeload]!);

      _expectExact(
        without,
        withDeload.take(without.length).toList(growable: false),
        reason: pair.without,
      );
    }
  });
}

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
      if (difference != null) {
        return difference;
      }
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
      if (difference != null) {
        return difference;
      }
    }
    return null;
  }
  if (actual != expected) {
    return '$path: expected $expected, actual $actual';
  }
  return null;
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
    (candidate) => candidate.reference.id == scenario.scheduleId,
  );
  final schedule = const CatalogScheduleDataResolver().resolve(sourceSchedule);
  final definition = const CatalogPlanResolver().resolve(
    const CatalogPlanDataResolver().resolve(
      catalogVersion: 2,
      template: template,
      variant: variant,
      scheduleReference: ComponentReference(scenario.scheduleId, 1),
      schedules: schedules,
      components: components,
      sourceReference: 'source-calculator-v1/exact-goldens.json',
      optionValues: {
        if (scenario.variantId == 'option_three')
          'second_lift_profile': scenario.secondLiftProfile,
      },
      optionRecipes: optionRecipes,
    ),
  );
  final request = CycleRequest(
    cycleId: '${scenario.variantId}-${scenario.secondLiftProfile}',
    startDate: DateTime(2026, 1, 5),
    trainingDays: _trainingDays,
    sessionOrder: [for (final id in scenario.sessionOrder) MovementId(id)],
    maxInputs: const {
      MovementId('overhead_press'): OneRepMaxInput(Weight(7500, WeightUnit.lb)),
      MovementId('deadlift'): OneRepMaxInput(Weight(20000, WeightUnit.lb)),
      MovementId('bench_press'): OneRepMaxInput(Weight(10000, WeightUnit.lb)),
      MovementId('squat'): OneRepMaxInput(Weight(15000, WeightUnit.lb)),
    },
    globalTrainingMaxRatio: const Percentage(9000),
    unit: WeightUnit.lb,
    roundingIncrement: const Weight(500, WeightUnit.lb),
    barProfile: const BarProfile(
      weight: Weight(4500, WeightUnit.lb),
      platesPerSide: [
        Weight(4500, WeightUnit.lb),
        Weight(2500, WeightUnit.lb),
        Weight(1000, WeightUnit.lb),
        Weight(1000, WeightUnit.lb),
        Weight(500, WeightUnit.lb),
        Weight(250, WeightUnit.lb),
      ],
    ),
    includeDeload: scenario.includeDeload,
    cycleOptions: CycleExecutionOptions(
      warmUp: const WarmUpExecutionOptions(
        enabled: true,
        type: WarmUpType.original,
      ),
      joker: scenario.jokerCeilingBasisPoints == null
          ? const JokerExecutionOptions.disabled()
          : JokerExecutionOptions(
              enabled: true,
              ceilingBasisPoints: scenario.jokerCeilingBasisPoints,
            ),
      deload: scenario.includeDeload
          ? DeloadExecutionOptions(
              enabled: true,
              type: scenario.deloadType,
              skipWarmUp: true,
            )
          : const DeloadExecutionOptions.disabled(),
    ),
  );
  return const CycleCompilerImpl().compileScheduled(
    definition: definition,
    schedule: schedule,
    selection: CycleScheduleSelection(
      trainingDays: _trainingDays,
      sessionOrder: [for (final id in scenario.sessionOrder) SessionId(id)],
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
                          _plateCentiUnits(plate! as String),
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
          'work': _generatedWork(block.role, set),
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

String _generatedWork(String role, GeneratedSet set) {
  final repetitions = role == 'joker'
      ? '\u{1F0CF}'
      : switch (set.repetitions['type']) {
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

int _plateCentiUnits(String value) {
  final normalized = value
      .replaceAll('\u00C2', '')
      .replaceAll('\u00BD', '.5')
      .replaceAll('\u00BC', '.25')
      .replaceAll('\u00BE', '.75');
  return (double.parse(normalized) * 100).round();
}

String _movementIdForSourceName(String value) => switch (value) {
  'Overhead Press' => 'overhead_press',
  'Deadlift' => 'deadlift',
  'Bench Press' => 'bench_press',
  'Squat' => 'squat',
  'Dumbbell Row' => 'dumbbell_row',
  'Dip' => 'dip',
  'Good Morning' => 'good_morning',
  'Bicep Curl' => 'curl',
  'Pull Up' => 'pull_up',
  'Back Raise' => 'back_raise',
  'Dumbbell Bench Press' => 'dumbbell_bench_press',
  'Rear Lats Raises' => 'rear_lateral_raise',
  'Dumbbell Side Bend' => 'dumbbell_side_bend',
  'Sit-up' => 'sit_up',
  'Ab Wheel' => 'ab_wheel',
  'Front Squat' => 'front_squat',
  'Straight Leg Deadlift' => 'stiff_leg_deadlift',
  'Hanging Leg Raise' => 'hanging_leg_raise',
  'Hamstring Curl' => 'hamstring_curl',
  _ => throw StateError('Unknown source exercise $value'),
};

final class _Scenario {
  const _Scenario({
    required this.variantId,
    required this.scheduleId,
    required this.sessionOrder,
    this.secondLiftProfile = '65_75_85',
    this.includeDeload = true,
    this.jokerCeilingBasisPoints,
    this.deloadType = DeloadType.type1,
  });

  final String variantId;
  final String scheduleId;
  final List<String> sessionOrder;
  final String secondLiftProfile;
  final bool includeDeload;
  final int? jokerCeilingBasisPoints;
  final DeloadType deloadType;
}
