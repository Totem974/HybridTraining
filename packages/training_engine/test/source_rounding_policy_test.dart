import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _templateId = 'source_calculator_boring_but_big';
const _fourDayScheduleId = 'schedule_four_day_fixed';
const _threeDayScheduleId = 'schedule_three_day_rotating';
const _sessionOrder = ['overhead_press', 'deadlift', 'bench_press', 'squat'];

const _fourDayGoldenVariants = {
  'bbb-original-4-day': 'original_5x10',
  'bbb-5x5-4-day': 'five_by_five_80',
  'bbb-5x3-4-day': 'five_by_three_90',
  'bbb-5x1-4-day': 'five_by_one_100',
  'bbb-beyond-variation-1-4-day': 'beyond_variation_one',
  'bbb-beyond-variation-2-4-day': 'beyond_variation_two',
};

void main() {
  late SourceTemplate sourceTemplate;
  late List<SourceComponent> components;
  late List<SourceSchedule> schedules;
  late List<SourceCycleOptionRecipe> optionRecipes;
  late ResolvedAssistancePlan assistancePlan;
  late Map<String, Object?> exactGoldens;

  setUpAll(() {
    const codec = CatalogSourceDocumentCodec();
    sourceTemplate = codec
        .decodeTemplates(
          File(
            '../../catalog_src/source_parity/templates.json',
          ).readAsStringSync(),
        )
        .singleWhere((template) => template.id == _templateId);
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

  test(
    'LoadCalculator keeps nearest as default and exposes upward rounding',
    () {
      const calculator = LoadCalculator();
      const load = Weight(5100, WeightUnit.lb);
      const increment = Weight(500, WeightUnit.lb);

      expect(
        calculator.roundToIncrement(load, increment),
        isA<Weight>()
            .having((weight) => weight.centiUnits, 'centiUnits', 5000)
            .having((weight) => weight.unit, 'unit', WeightUnit.lb),
      );
      expect(
        calculator.roundToIncrement(
          load,
          increment,
          policy: LoadRoundingPolicy.up,
        ),
        isA<Weight>().having((weight) => weight.centiUnits, 'centiUnits', 5500),
      );
      expect(
        calculator
            .roundToIncrement(
              const Weight(5000, WeightUnit.lb),
              increment,
              policy: LoadRoundingPolicy.up,
            )
            .centiUnits,
        5000,
      );
    },
  );

  test(
    'catalog defaults historical variants to nearest and source variants up',
    () {
      const codec = CatalogSourceDocumentCodec();
      final classic = codec.decodeTemplates(
        File('../../catalog_src/classic/templates.json').readAsStringSync(),
      );

      expect(
        classic
            .expand((template) => template.variants)
            .every(
              (variant) =>
                  variant.loadRoundingPolicy == LoadRoundingPolicy.nearest,
            ),
        isTrue,
      );
      expect(
        sourceTemplate.variants.map((variant) => variant.loadRoundingPolicy),
        everyElement(LoadRoundingPolicy.up),
      );
    },
  );

  test('catalog codec rejects an unknown load rounding policy', () {
    final document =
        jsonDecode(
              File(
                '../../catalog_src/classic/templates.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final templates = (document['templates']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final variants = (templates.first['variants']! as List<Object?>)
        .cast<Map<String, Object?>>();
    variants.first['loadRoundingPolicy'] = 'sideways';

    expect(
      () => const CatalogSourceDocumentCodec().decodeTemplates(
        jsonEncode(document),
      ),
      throwsFormatException,
    );
  });

  for (final entry in _fourDayGoldenVariants.entries) {
    test('${entry.value} matches every literal source load on four days', () {
      final actual = _compile(
        template: sourceTemplate,
        variantId: entry.value,
        scheduleId: _fourDayScheduleId,
        components: components,
        schedules: schedules,
        optionRecipes: optionRecipes,
        assistancePlan: assistancePlan,
        trainingDays: const [1, 2, 4, 5],
      );

      expect(
        _actualWork(actual),
        _goldenWork(_goldenScenario(exactGoldens, entry.key)),
      );
    });
  }

  test('Original matches every literal source load on three rotating days', () {
    final actual = _compile(
      template: sourceTemplate,
      variantId: 'original_5x10',
      scheduleId: _threeDayScheduleId,
      components: components,
      schedules: schedules,
      optionRecipes: optionRecipes,
      assistancePlan: assistancePlan,
      trainingDays: const [1, 3, 5],
    );

    expect(
      _actualWork(actual),
      _goldenWork(_goldenScenario(exactGoldens, 'bbb-original-3-day')),
    );
  });
}

GeneratedCycle _compile({
  required SourceTemplate template,
  required String variantId,
  required String scheduleId,
  required List<SourceComponent> components,
  required List<SourceSchedule> schedules,
  required List<SourceCycleOptionRecipe> optionRecipes,
  required ResolvedAssistancePlan assistancePlan,
  required List<int> trainingDays,
}) {
  final variant = template.variants.singleWhere(
    (candidate) => candidate.id == variantId,
  );
  final definition = const CatalogPlanResolver().resolve(
    const CatalogPlanDataResolver().resolve(
      catalogVersion: 2,
      template: template,
      variant: variant,
      scheduleReference: ComponentReference(scheduleId, 1),
      schedules: schedules,
      components: components,
      sourceReference: 'source-calculator-v1/exact-goldens.json',
      optionRecipes: optionRecipes,
    ),
  );
  expect(definition.loadRoundingPolicy, LoadRoundingPolicy.up);

  final request = CycleRequest(
    cycleId: '$variantId-$scheduleId-rounding',
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
  final schedule = const CatalogScheduleDataResolver().resolve(
    schedules.singleWhere((candidate) => candidate.reference.id == scheduleId),
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

List<Object?> _goldenWork(Map<String, Object?> scenario) {
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
              _goldenExercise(rawExercise! as Map<String, Object?>),
          ],
      ],
  ];
}

Map<String, Object?> _goldenExercise(Map<String, Object?> exercise) => {
  'movementId': _movementIdForSourceName(exercise['name']! as String),
  'work': [
    for (final rawSet in exercise['sets']! as List<Object?>)
      (rawSet! as Map<String, Object?>)['work']! as String,
  ],
};

List<Object?> _actualWork(GeneratedCycle cycle) => [
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
    final work = block.sets.map(_workString).toList(growable: false);
    if (result.isNotEmpty && result.last['movementId'] == movementId) {
      (result.last['work']! as List<String>).addAll(work);
    } else {
      result.add({
        'movementId': movementId,
        'work': <String>[...work],
      });
    }
  }
  return result;
}

String _workString(GeneratedSet set) {
  final repetitions = switch (set.repetitions['type']) {
    'fixed' => '${set.repetitions['count']}',
    'amrap' => '${set.repetitions['minimum']}+',
    'plus_set' => '${set.repetitions['minimum']}+',
    final type => throw StateError('Unsupported repetition type $type'),
  };
  final load = set.plannedLoad;
  return load == null
      ? '$repetitions reps'
      : '$repetitions x ${_formatWeight(load)}';
}

String _formatWeight(Weight weight) {
  final whole = weight.centiUnits ~/ 100;
  final fraction = weight.centiUnits % 100;
  if (fraction == 0) return '$whole';
  if (fraction % 10 == 0) return '$whole.${fraction ~/ 10}';
  return '$whole.${fraction.toString().padLeft(2, '0')}';
}

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
