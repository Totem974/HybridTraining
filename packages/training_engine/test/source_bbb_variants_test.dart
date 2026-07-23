import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _templateId = 'source_calculator_boring_but_big';
const _fourDayScheduleId = 'schedule_four_day_fixed';
const _threeDayScheduleId = 'schedule_three_day_rotating';
const _assistancePlanId = 'source_bbb_exact_assistance';
const _sessionOrder = ['overhead_press', 'deadlift', 'bench_press', 'squat'];

const _goldenVariants = {
  'bbb-original-4-day': 'original_5x10',
  'bbb-5x5-4-day': 'five_by_five_80',
  'bbb-5x3-4-day': 'five_by_three_90',
  'bbb-5x1-4-day': 'five_by_one_100',
  'bbb-beyond-variation-1-4-day': 'beyond_variation_one',
  'bbb-beyond-variation-2-4-day': 'beyond_variation_two',
};
const _sameLiftVariantIds = [
  'original_5x10',
  'five_by_five_80',
  'five_by_three_90',
  'five_by_one_100',
  'beyond_variation_one',
  'beyond_variation_two',
];

void main() {
  late SourceTemplate template;
  late List<SourceComponent> components;
  late List<SourceSchedule> sourceSchedules;
  late List<SourceCycleOptionRecipe> optionRecipes;
  late ResolvedAssistancePlan assistancePlan;
  late Map<String, Object?> exactGoldens;

  setUpAll(() {
    const codec = CatalogSourceDocumentCodec();
    template = codec
        .decodeTemplates(
          File(
            '../../catalog_src/source_parity/templates.json',
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
          '../../catalog_src/beyond/templates/components/bbb_variations.v1.json',
        ).readAsStringSync(),
      ),
      ...codec.decodeComponents(
        File(
          '../../catalog_src/source_parity/components.json',
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
    assistancePlan = const AssistancePlanResolver()
        .decodeDocument(
          File(
            '../../catalog_src/source_parity/assistance_plans.json',
          ).readAsStringSync(),
        )
        .single;
    exactGoldens =
        jsonDecode(
              File(
                '../../test/fixtures/source-calculator-v1/exact-goldens.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  test('source documents preserve the six same-lift BBB variants', () {
    expect(template.surface, TemplateSurface.cyclePublic);
    expect(
      template.variants.map((variant) => variant.id),
      containsAll([
        ..._sameLiftVariantIds,
        'less_boring_5x10',
        'two_days_per_week',
      ]),
    );

    final sameLiftVariants = template.variants
        .where((variant) => _sameLiftVariantIds.contains(variant.id))
        .toList(growable: false);
    expect(sameLiftVariants.map((variant) => variant.id), _sameLiftVariantIds);

    for (final variant in sameLiftVariants) {
      expect(variant.scheduleIds.map((reference) => reference.id), [
        _fourDayScheduleId,
        _threeDayScheduleId,
      ]);
      expect(variant.weekPlans.map((week) => week.weekNumber), [1, 2, 3, 4]);
      expect(variant.phases, isEmpty);
      expect(variant.assistancePlanIds.map((reference) => reference.id), [
        _assistancePlanId,
      ]);
      expect(
        variant.weekPlans.last.components.map((reference) => reference.id),
        ['deload_original_40_50_60'],
      );
    }
  });

  test('specialized schemas compose cross-cut options and bound BBB ratio', () {
    final schemas = const CatalogSourceDocumentCodec().decodeOptionSchemas(
      File(
        '../../catalog_src/source_parity/option_schemas.json',
      ).readAsStringSync(),
    );
    for (final schema in schemas) {
      expect(schema['includeSchemaIds'], [
        {'id': 'classic_crosscut_options', 'revision': 1},
      ]);
    }

    final original = schemas.singleWhere(
      (schema) => schema['id'] == 'source_bbb_original_options',
    );
    final parameter = (original['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    expect(parameter['id'], 'bbb_percentage');
    expect(parameter['scope'], 'perMovement');
    expect(parameter['default'], 3000);
    expect(parameter['minimum'], 3000);
    expect(parameter['maximum'], 7500);
    expect(parameter['step'], 500);
    expect(parameter['allowedValues'], [
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
  });

  for (final entry in _goldenVariants.entries) {
    test('${entry.value} matches exact source structure and repetitions', () {
      final actual = _compile(
        template: template,
        variantId: entry.value,
        scheduleId: _fourDayScheduleId,
        components: components,
        sourceSchedules: sourceSchedules,
        optionRecipes: optionRecipes,
        assistancePlan: assistancePlan,
        trainingDays: const [1, 2, 4, 5],
      );
      final expected = _goldenScenario(exactGoldens, entry.key);

      expect(_canonicalCycle(actual), _canonicalGolden(expected));
    });
  }

  test('Original 3-day rotation matches the exact five-week source shape', () {
    final actual = _compile(
      template: template,
      variantId: 'original_5x10',
      scheduleId: _threeDayScheduleId,
      components: components,
      sourceSchedules: sourceSchedules,
      optionRecipes: optionRecipes,
      assistancePlan: assistancePlan,
      trainingDays: const [1, 3, 5],
    );
    final expected = _goldenScenario(exactGoldens, 'bbb-original-3-day');

    expect(_canonicalCycle(actual), _canonicalGolden(expected));
    expect(actual.weeks, hasLength(5));
    expect(
      actual.weeks
          .take(4)
          .map(
            (week) => week.sessions
                .map((session) => session.movementId.value)
                .toList(),
          ),
      [
        ['overhead_press', 'deadlift', 'bench_press'],
        ['squat', 'overhead_press', 'deadlift'],
        ['bench_press', 'squat', 'overhead_press'],
        ['deadlift', 'bench_press', 'squat'],
      ],
    );
  });

  test('Original applies independent 30% and 75% movement ratios', () {
    final cycle = _compile(
      template: template,
      variantId: 'original_5x10',
      scheduleId: _fourDayScheduleId,
      components: components,
      sourceSchedules: sourceSchedules,
      optionRecipes: optionRecipes,
      assistancePlan: assistancePlan,
      trainingDays: const [1, 2, 4, 5],
      bbbPercentages: const {
        'overhead_press': 7500,
        'deadlift': 3000,
        'bench_press': 7500,
        'squat': 3000,
      },
    );

    expect(
      {
        for (final session in cycle.weeks.first.sessions)
          session.movementId.value: session.blocks
              .singleWhere((block) => block.role == 'supplemental')
              .sets
              .map((set) => set.percentageBasisPoints)
              .toSet()
              .single,
      },
      {
        'overhead_press': 7500,
        'deadlift': 3000,
        'bench_press': 7500,
        'squat': 3000,
      },
    );
  });

  test('all fixed and waving supplemental prescriptions remain exact', () {
    const expected = {
      'original_5x10': [
        (repetitions: 10, percentage: 3000),
        (repetitions: 10, percentage: 3000),
        (repetitions: 10, percentage: 3000),
      ],
      'five_by_five_80': [
        (repetitions: 5, percentage: 8000),
        (repetitions: 5, percentage: 8000),
        (repetitions: 5, percentage: 8000),
      ],
      'five_by_three_90': [
        (repetitions: 3, percentage: 9000),
        (repetitions: 3, percentage: 9000),
        (repetitions: 3, percentage: 9000),
      ],
      'five_by_one_100': [
        (repetitions: 1, percentage: 10000),
        (repetitions: 1, percentage: 10000),
        (repetitions: 1, percentage: 10000),
      ],
      'beyond_variation_one': [
        (repetitions: 10, percentage: 6500),
        (repetitions: 10, percentage: 7000),
        (repetitions: 10, percentage: 7500),
      ],
      'beyond_variation_two': [
        (repetitions: 10, percentage: 6500),
        (repetitions: 8, percentage: 7000),
        (repetitions: 5, percentage: 7500),
      ],
    };

    for (final entry in expected.entries) {
      final cycle = _compile(
        template: template,
        variantId: entry.key,
        scheduleId: _fourDayScheduleId,
        components: components,
        sourceSchedules: sourceSchedules,
        optionRecipes: optionRecipes,
        assistancePlan: assistancePlan,
        trainingDays: const [1, 2, 4, 5],
      );
      final actual = [
        for (final week in cycle.weeks.take(3))
          (
            repetitions:
                week.sessions.first.blocks
                        .singleWhere((block) => block.role == 'supplemental')
                        .sets
                        .map((set) => set.repetitions['count'])
                        .toSet()
                        .single
                    as int,
            percentage: week.sessions.first.blocks
                .singleWhere((block) => block.role == 'supplemental')
                .sets
                .map((set) => set.percentageBasisPoints)
                .toSet()
                .single!,
          ),
      ];

      expect(actual, entry.value, reason: entry.key);
    }
  });

  test('exact BBB assistance remains present on the deload week', () {
    final cycle = _compile(
      template: template,
      variantId: 'beyond_variation_two',
      scheduleId: _fourDayScheduleId,
      components: components,
      sourceSchedules: sourceSchedules,
      optionRecipes: optionRecipes,
      assistancePlan: assistancePlan,
      trainingDays: const [1, 2, 4, 5],
    );
    final deload = cycle.weeks.last;

    expect(deload.number, 4);
    expect(
      deload.sessions
          .map(
            (session) => session.blocks
                .where((block) => block.role == 'assistance')
                .single
                .movementId
                .value,
          )
          .toList(),
      ['pull_up', 'hanging_leg_raise', 'dumbbell_row', 'hamstring_curl'],
    );
    expect(
      deload.sessions
          .map(
            (session) => session.blocks
                .where((block) => block.role == 'assistance')
                .single
                .sets
                .map((set) => set.repetitions['count'])
                .toList(),
          )
          .toList(),
      [
        [10, 10, 10, 10, 10],
        [15, 15, 15, 15, 15],
        [10, 10, 10, 10, 10],
        [10, 10, 10, 10, 10],
      ],
    );
  });
}

GeneratedCycle _compile({
  required SourceTemplate template,
  required String variantId,
  required String scheduleId,
  required List<SourceComponent> components,
  required List<SourceSchedule> sourceSchedules,
  required List<SourceCycleOptionRecipe> optionRecipes,
  required ResolvedAssistancePlan assistancePlan,
  required List<int> trainingDays,
  Map<String, int>? bbbPercentages,
}) {
  final variant = template.variants.singleWhere(
    (candidate) => candidate.id == variantId,
  );
  final sourceSchedule = sourceSchedules.singleWhere(
    (candidate) => candidate.reference.id == scheduleId,
  );
  final schedule = const CatalogScheduleDataResolver().resolve(sourceSchedule);
  final definition = const CatalogPlanResolver().resolve(
    const CatalogPlanDataResolver().resolve(
      catalogVersion: 2,
      template: template,
      variant: variant,
      scheduleReference: ComponentReference(scheduleId, 1),
      schedules: sourceSchedules,
      components: components,
      sourceReference: 'source-calculator-v1/exact-goldens.json',
      optionRecipes: optionRecipes,
    ),
  );
  final request = CycleRequest(
    cycleId: '$variantId-$scheduleId',
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
        if (bbbPercentages?.containsKey(id) ?? false)
          MovementId(id): {'bbb_percentage': Percentage(bbbPercentages![id]!)},
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
    assistancePlans: [assistancePlan],
  );
}

Map<String, Object?> _goldenScenario(Map<String, Object?> root, String id) =>
    (root['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((scenario) => scenario['id'] == id);

List<Object?> _canonicalGolden(Map<String, Object?> scenario) {
  final output = scenario['output']! as Map<String, Object?>;
  return (output['weeks']! as List<Object?>)
      .map((rawWeek) {
        final week = rawWeek! as Map<String, Object?>;
        return (week['sessions']! as List<Object?>)
            .map((rawSession) {
              final session = rawSession! as Map<String, Object?>;
              return (session['exercises']! as List<Object?>)
                  .map((rawExercise) {
                    final exercise = rawExercise! as Map<String, Object?>;
                    return <String, Object?>{
                      'movementId': _movementIdForSourceName(
                        exercise['name']! as String,
                      ),
                      'sets': (exercise['sets']! as List<Object?>)
                          .map(
                            (rawSet) => _sourceRepetitions(
                              (rawSet! as Map<String, Object?>)['work']!
                                  as String,
                            ),
                          )
                          .toList(growable: false),
                    };
                  })
                  .toList(growable: false);
            })
            .toList(growable: false);
      })
      .toList(growable: false);
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
    final sets = block.sets.map(_generatedRepetitions).toList(growable: false);
    if (result.isNotEmpty && result.last['movementId'] == movementId) {
      (result.last['sets']! as List<String>).addAll(sets);
    } else {
      result.add(<String, Object?>{
        'movementId': movementId,
        'sets': <String>[...sets],
      });
    }
  }
  return result;
}

// This canonical comparison freezes the exact exercise and repetition
// topology. Planned-load string parity is covered by the dedicated exact
// source golden tests.
String _generatedRepetitions(GeneratedSet set) =>
    switch (set.repetitions['type']) {
      'fixed' => '${set.repetitions['count']}',
      'amrap' => '${set.repetitions['minimum']}+',
      final type => throw StateError('Unsupported repetition type $type'),
    };

String _sourceRepetitions(String work) => work
    .replaceFirst(RegExp(r'\s+x\s+.*$'), '')
    .replaceFirst(RegExp(r'\s+reps$'), '');

String _movementIdForSourceName(String value) => switch (value) {
  'Overhead Press' => 'overhead_press',
  'Deadlift' => 'deadlift',
  'Bench Press' => 'bench_press',
  'Squat' => 'squat',
  'Pull Up' => 'pull_up',
  'Hanging Leg Raise' => 'hanging_leg_raise',
  'Dumbbell Row' => 'dumbbell_row',
  'Hamstring Curl' => 'hamstring_curl',
  _ => throw StateError('Unknown source exercise $value'),
};
