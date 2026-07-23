import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _templateId = 'source_calculator_boring_but_big';
const _fourDayScheduleId = 'schedule_four_day_fixed';
const _twoDayScheduleId = 'schedule_two_day_rotating_four_lifts';
const _sessionOrder = ['overhead_press', 'deadlift', 'bench_press', 'squat'];
const _oppositeMovement = {
  'overhead_press': 'bench_press',
  'deadlift': 'squat',
  'bench_press': 'overhead_press',
  'squat': 'deadlift',
};

void main() {
  late SourceTemplate template;
  late List<SourceComponent> components;
  late List<SourceSchedule> schedules;
  late List<SourceCycleOptionRecipe> optionRecipes;
  late Map<String, ResolvedAssistancePlan> assistancePlans;
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
    assistancePlans = {
      for (final plan in [
        ...const AssistancePlanResolver().decodeDocument(
          File(
            '../../catalog_src/source_parity/assistance_plans.json',
          ).readAsStringSync(),
        ),
        ...const AssistancePlanResolver().decodeDocument(
          File(
            '../../catalog_src/source_parity/assistance_plans_two_day.json',
          ).readAsStringSync(),
        ),
      ])
        plan.id: plan,
    };
    exactGoldens =
        jsonDecode(
              File(
                '../../test/fixtures/source-calculator-v1/exact-goldens.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  test('codec accepts one strict movement binding per source session', () {
    final component = components.singleWhere(
      (candidate) =>
          candidate.reference.id == 'source_bbb_less_boring_5x10_variable',
    );

    expect({
      for (final binding in component.sessionMovementBindings)
        binding.sessionId: binding.movementId,
    }, _oppositeMovement);
    expect(component.block.movementId, isNull);
    expect(component.constraints, isNot(contains('movementRelation')));
    expect(component.compatibilities, isNot(contains('sessionIds')));
    expect(component.compatibilities, isNot(contains('movementIds')));
  });

  test('codec rejects empty, duplicate, and ambiguous bindings', () {
    Map<String, Object?> component({
      Object? bindings = const [
        {'sessionId': 'overhead_press', 'movementId': 'bench_press'},
      ],
      Map<String, Object?> constraints = const {},
      Map<String, Object?> compatibilities = const {},
      String? blockMovementId,
    }) => {
      'schemaVersion': 1,
      'kind': 'components',
      'components': [
        {
          'id': 'cross',
          'revision': 1,
          'role': 'supplemental',
          'labels': {'en': 'Cross', 'fr': 'Croisé'},
          'sourceRuleIds': <Object?>[],
          'parameterSchemaIds': <Object?>[],
          'constraints': constraints,
          'compatibilities': compatibilities,
          'sessionMovementBindings': bindings,
          'block': {
            'id': 'supplemental',
            'role': 'supplemental',
            'movementId': ?blockMovementId,
            'sets': [
              {
                'repetitions': {'type': 'fixed', 'count': 10},
                'load': {
                  'type': 'training_max_percentage',
                  'basisPoints': 5000,
                },
              },
            ],
          },
        },
      ],
    };

    final invalid = [
      component(bindings: const []),
      component(
        bindings: const [
          {'sessionId': 'overhead_press', 'movementId': 'bench_press'},
          {'sessionId': 'overhead_press', 'movementId': 'deadlift'},
        ],
      ),
      component(constraints: const {'movementRelation': 'sameAsMain'}),
      component(
        compatibilities: const {
          'sessionIds': ['overhead_press'],
        },
      ),
      component(blockMovementId: 'bench_press'),
    ];
    for (final document in invalid) {
      expect(
        () => const CatalogSourceDocumentCodec().decodeComponents(
          jsonEncode(document),
        ),
        throwsFormatException,
      );
    }
  });

  test('Less Boring matches every captured exercise, repetition, and load', () {
    final cycle = _compile(
      template: template,
      variantId: 'less_boring_5x10',
      scheduleId: _fourDayScheduleId,
      trainingDays: const [1, 2, 4, 5],
      components: components,
      schedules: schedules,
      optionRecipes: optionRecipes,
      assistancePlans: assistancePlans,
      bbbPercentages: const {
        'overhead_press': 3000,
        'deadlift': 3000,
        'bench_press': 3000,
        'squat': 3000,
      },
    );
    final expected = _goldenScenario(exactGoldens, 'bbb-less-boring-4-day');

    expect(_canonicalCycle(cycle), _canonicalGolden(expected));
    expect(cycle.weeks, hasLength(4));
    const assistanceByMain = {
      'overhead_press': 'pull_up',
      'deadlift': 'hanging_leg_raise',
      'bench_press': 'dumbbell_row',
      'squat': 'hamstring_curl',
    };
    for (final week in cycle.weeks.take(3)) {
      expect({
        for (final session in week.sessions)
          session.movementId.value: session.blocks
              .singleWhere((block) => block.role == 'supplemental')
              .movementId
              .value,
      }, _oppositeMovement);
      for (final session in week.sessions) {
        expect(
          session.blocks.where((block) => block.role == 'warm_up'),
          hasLength(1),
          reason: 'Warm-up must remain attached only to the main lift.',
        );
      }
    }
    for (final week in cycle.weeks) {
      expect(
        {
          for (final session in week.sessions)
            session.movementId.value: session.blocks
                .singleWhere((block) => block.role == 'assistance')
                .movementId
                .value,
        },
        assistanceByMain,
        reason: 'Assistance stays indexed by the main lift.',
      );
    }
    expect(
      cycle.weeks.last.sessions
          .expand((session) => session.blocks)
          .where((block) => block.role == 'supplemental'),
      isEmpty,
    );
  });

  test('BBB two-day matches the exact rotating seven-week source cycle', () {
    final cycle = _compile(
      template: template,
      variantId: 'two_days_per_week',
      scheduleId: _twoDayScheduleId,
      trainingDays: const [1, 4],
      components: components,
      schedules: schedules,
      optionRecipes: optionRecipes,
      assistancePlans: assistancePlans,
    );
    final expected = _goldenScenario(exactGoldens, 'bbb-2-day');

    expect(_canonicalCycle(cycle), _canonicalGolden(expected));
    expect(cycle.weeks, hasLength(7));
    expect(
      cycle.weeks
          .take(6)
          .map(
            (week) => week.sessions
                .map((session) => session.movementId.value)
                .toList(),
          ),
      [
        ['overhead_press', 'deadlift'],
        ['bench_press', 'squat'],
        ['overhead_press', 'deadlift'],
        ['bench_press', 'squat'],
        ['overhead_press', 'deadlift'],
        ['bench_press', 'squat'],
      ],
    );
    expect(
      cycle.weeks
          .take(6)
          .map(
            (week) => week.sessions.first.blocks
                .singleWhere((block) => block.role == 'supplemental')
                .sets
                .first
                .percentageBasisPoints,
          ),
      [5000, 5000, 6000, 6000, 7000, 7000],
    );
    expect(
      cycle.weeks.last.sessions.map(
        (session) => session.blocks
            .where((block) => block.role == 'assistance')
            .map((block) => block.movementId.value)
            .toList(),
      ),
      [
        ['pull_up', 'good_morning'],
        ['dumbbell_row', 'good_morning'],
      ],
    );
    expect(
      cycle.weeks.last.sessions
          .expand((session) => session.blocks)
          .where((block) => block.role == 'supplemental'),
      isEmpty,
    );
  });

  test('active bindings reject movements outside the selected schedule', () {
    final invalidComponents = [
      for (final component in components)
        if (component.reference.id == 'source_bbb_less_boring_5x10_variable')
          SourceComponent(
            reference: component.reference,
            block: component.block,
            constraints: component.constraints,
            compatibilities: component.compatibilities,
            sessionMovementBindings: const [
              SourceSessionMovementBinding(
                sessionId: 'overhead_press',
                movementId: 'front_squat',
              ),
            ],
          )
        else
          component,
    ];
    final variant = template.variants.singleWhere(
      (candidate) => candidate.id == 'less_boring_5x10',
    );

    expect(
      () => const CatalogPlanDataResolver().resolve(
        catalogVersion: 2,
        template: template,
        variant: variant,
        scheduleReference: const ComponentReference(_fourDayScheduleId, 1),
        schedules: schedules,
        components: invalidComponents,
        sourceReference: 'test',
        optionRecipes: optionRecipes,
      ),
      throwsFormatException,
    );
  });
}

GeneratedCycle _compile({
  required SourceTemplate template,
  required String variantId,
  required String scheduleId,
  required List<int> trainingDays,
  required List<SourceComponent> components,
  required List<SourceSchedule> schedules,
  required List<SourceCycleOptionRecipe> optionRecipes,
  required Map<String, ResolvedAssistancePlan> assistancePlans,
  Map<String, int> bbbPercentages = const {},
}) {
  final variant = template.variants.singleWhere(
    (candidate) => candidate.id == variantId,
  );
  final sourceSchedule = schedules.singleWhere(
    (candidate) => candidate.reference.id == scheduleId,
  );
  final schedule = const CatalogScheduleDataResolver().resolve(sourceSchedule);
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
      for (final entry in bbbPercentages.entries)
        MovementId(entry.key): {'bbb_percentage': Percentage(entry.value)},
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
    assistancePlans: [
      for (final reference in variant.assistancePlanIds)
        assistancePlans[reference.id]!,
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
  'Pull Up' => 'pull_up',
  'Hanging Leg Raise' => 'hanging_leg_raise',
  'Dumbbell Row' => 'dumbbell_row',
  'Hamstring Curl' => 'hamstring_curl',
  'Good Morning' => 'good_morning',
  _ => throw StateError('Unknown source exercise $value'),
};
