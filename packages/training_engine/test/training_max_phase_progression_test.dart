import 'dart:convert';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _movements = [
  MovementId('overhead_press'),
  MovementId('deadlift'),
  MovementId('bench_press'),
  MovementId('squat'),
];
const _componentReference = ComponentReference('main', 1);
const _scheduleReference = ComponentReference('schedule', 1);
const _progression = LinearPhaseStepTrainingMaxProgression(
  incrementCentiUnitsByUnit: {
    WeightUnit.lb: {
      MovementId('overhead_press'): 500,
      MovementId('bench_press'): 500,
      MovementId('squat'): 1000,
      MovementId('deadlift'): 1000,
    },
    WeightUnit.kg: {
      MovementId('overhead_press'): 250,
      MovementId('bench_press'): 250,
      MovementId('squat'): 500,
      MovementId('deadlift'): 500,
    },
  },
);

void main() {
  group('phase Training Max progression', () {
    for (final unit in WeightUnit.values) {
      test(
        '${unit.name} applies absolute movement increments at steps 0/1/2/3',
        () {
          final cycle = _compileFixed(
            _definition(steps: const [0, 1, 2, 3], progression: _progression),
            unit,
          );

          for (var step = 0; step < 4; step++) {
            final loads = {
              for (final session in cycle.weeks[step].sessions)
                session.movementId.value:
                    session.blocks.single.sets.single.plannedLoad!.centiUnits,
            };
            final upperIncrement = unit == WeightUnit.lb ? 500 : 250;
            final lowerIncrement = unit == WeightUnit.lb ? 1000 : 500;
            expect(loads, {
              'overhead_press': 10000 + step * upperIncrement,
              'deadlift': 10000 + step * lowerIncrement,
              'bench_press': 10000 + step * upperIncrement,
              'squat': 10000 + step * lowerIncrement,
            });
          }
          expect(
            cycle.effectiveTrainingMaxes.values
                .map((weight) => weight.centiUnits)
                .toSet(),
            {10000},
            reason: 'the public effective Training Maxes remain initial',
          );
          expect(
            cycle.toJson().toString(),
            isNot(contains('trainingMaxProgression')),
          );
        },
      );
    }

    test('scheduled compilation uses each source week progression step', () {
      final definition = _definition(
        steps: const [0, 1, 2],
        progression: _progression,
        scheduleMode: CycleScheduleMode.rotating,
      );
      final cycle = const CycleCompilerImpl().compileScheduled(
        definition: definition,
        schedule: _schedule(CycleScheduleMode.rotating, const {3}),
        selection: const CycleScheduleSelection(
          trainingDays: [1, 3, 5],
          sessionOrder: [
            SessionId('overhead_press'),
            SessionId('deadlift'),
            SessionId('bench_press'),
            SessionId('squat'),
          ],
        ),
        request: _request(WeightUnit.lb, const [1, 3, 5]),
      );

      expect(
        [
          for (final session in cycle.weeks[1].sessions)
            (
              movement: session.movementId.value,
              load: session.blocks.single.sets.single.plannedLoad!.centiUnits,
            ),
        ],
        [
          (movement: 'squat', load: 10000),
          (movement: 'overhead_press', load: 10500),
          (movement: 'deadlift', load: 11000),
        ],
        reason: 'displayed week 2 aggregates source week 1 and source week 2',
      );
    });

    test('3/5/1 reordering keeps the target phase progression step', () {
      final definition = _definition(
        steps: const [2, 2, 2],
        progression: _progression,
        percentages: const [6000, 7000, 8000],
        waveRoles: const [
          MainWorkWaveRole.five,
          MainWorkWaveRole.three,
          MainWorkWaveRole.fiveThreeOne,
        ],
      );
      final cycle = _compileFixed(
        definition,
        WeightUnit.kg,
        mainWork: const MainWorkExecutionOptions(
          weekOrder: WorkWeekOrder.threeFiveOne,
        ),
      );

      expect(
        [
          for (final week in cycle.weeks)
            week
                .sessions
                .first
                .blocks
                .single
                .sets
                .single
                .plannedLoad!
                .centiUnits,
        ],
        [7350, 6300, 8400],
        reason:
            '105 kg is retained while the 70/60/80 percent donor waves move',
      );
    });

    test(
      'multi-phase definitions without a policy never progress implicitly',
      () {
        final withSteps = _definition(steps: const [0, 2, 3]);
        final withoutSteps = _definition(steps: const [0, 0, 0]);

        expect(
          _compileFixed(withSteps, WeightUnit.kg).toJson(),
          _compileFixed(withoutSteps, WeightUnit.kg).toJson(),
        );
      },
    );

    test('catalog data resolution preserves policy and phase origin step', () {
      const variant = SourceVariant(
        id: 'progressing',
        revision: 1,
        scheduleIds: [_scheduleReference],
        weekPlans: [],
        phases: [
          CatalogPhase(
            id: 'base',
            repeatCount: 1,
            trainingMaxProgressionStep: 0,
            weekPlans: [
              CatalogWeekPlan(weekNumber: 1, components: [_componentReference]),
            ],
          ),
          CatalogPhase(
            id: 'build',
            repeatCount: 1,
            trainingMaxProgressionStep: 2,
            weekPlans: [
              CatalogWeekPlan(weekNumber: 1, components: [_componentReference]),
            ],
          ),
        ],
        compatibilities: {},
        optionSchemaId: ComponentReference('options', 1),
        trainingMaxProgression: _progression,
      );
      const template = SourceTemplate(
        id: 'template',
        revision: 1,
        variants: [variant],
        surface: TemplateSurface.cyclePublic,
        generation: SourceTemplateGeneration(
          id: 'test',
          labels: {'en': 'Test', 'fr': 'Test'},
        ),
      );
      const sourceSchedule = SourceSchedule(
        reference: _scheduleReference,
        sessions: [
          SourceSession(id: 'overhead_press', movementIds: ['overhead_press']),
        ],
      );
      const sourceComponent = SourceComponent(
        reference: _componentReference,
        block: BlockDefinition(
          id: 'main',
          role: 'main_work',
          movementId: MovementId('overhead_press'),
          sets: [
            PrescribedSetDefinition(
              repetitions: FixedRepetitions(5),
              load: TrainingMaxPercentageLoad(Percentage(10000)),
            ),
          ],
        ),
        constraints: {},
        compatibilities: {},
      );

      final plan = const CatalogPlanDataResolver().resolve(
        catalogVersion: 2,
        template: template,
        variant: variant,
        scheduleReference: _scheduleReference,
        schedules: const [sourceSchedule],
        components: const [sourceComponent],
        sourceReference: 'test',
      );
      final resolved = const CatalogPlanResolver().resolve(plan);

      expect(plan.trainingMaxProgression, same(_progression));
      expect(resolved.trainingMaxProgression, same(_progression));
      expect(
        resolved.weeks.map((week) => week.origin!.trainingMaxProgressionStep),
        [0, 2],
      );
    });
  });

  group('catalog progression codec', () {
    const codec = CatalogSourceDocumentCodec();

    test('decodes the strict optional policy and phase step', () {
      final variant = codec
          .decodeTemplates(jsonEncode(_templateDocument()))
          .single
          .variants
          .single;
      final progression =
          variant.trainingMaxProgression
              as LinearPhaseStepTrainingMaxProgression;

      expect(variant.phases.single.trainingMaxProgressionStep, 2);
      expect(
        progression.incrementFor(
          WeightUnit.lb,
          const MovementId('overhead_press'),
        ),
        500,
      );
      expect(
        progression.incrementFor(WeightUnit.kg, const MovementId('deadlift')),
        500,
      );
    });

    test('defaults a missing phase step to zero', () {
      final document = _mutableTemplateDocument();
      _phase(document).remove('trainingMaxProgressionStep');

      expect(
        codec
            .decodeTemplates(jsonEncode(document))
            .single
            .variants
            .single
            .phases
            .single
            .trainingMaxProgressionStep,
        0,
      );
    });

    test('rejects invalid phase step types and bounds', () {
      for (final invalid in <Object>[-1, 1.5, '1']) {
        final document = _mutableTemplateDocument();
        _phase(document)['trainingMaxProgressionStep'] = invalid;
        expect(
          () => codec.decodeTemplates(jsonEncode(document)),
          throwsFormatException,
          reason: 'invalid step $invalid',
        );
      }
    });

    test('rejects unknown policy types and keys', () {
      final unknownType = _mutableTemplateDocument();
      _policy(unknownType)['type'] = 'compound';
      expect(
        () => codec.decodeTemplates(jsonEncode(unknownType)),
        throwsFormatException,
      );

      final unknownKey = _mutableTemplateDocument();
      _policy(unknownKey)['unexpected'] = true;
      expect(
        () => codec.decodeTemplates(jsonEncode(unknownKey)),
        throwsFormatException,
      );
    });

    test('requires exact unit and movement maps', () {
      final missingUnit = _mutableTemplateDocument();
      _increments(missingUnit).remove('kg');
      expect(
        () => codec.decodeTemplates(jsonEncode(missingUnit)),
        throwsFormatException,
      );

      final unknownMovement = _mutableTemplateDocument();
      (_increments(unknownMovement)['lb']! as Map<String, Object?>)['row'] =
          500;
      expect(
        () => codec.decodeTemplates(jsonEncode(unknownMovement)),
        throwsFormatException,
      );
    });

    test('requires positive integer centi-unit increments', () {
      for (final invalid in <Object>[0, -1, 2.5, '500']) {
        final document = _mutableTemplateDocument();
        final pounds = _increments(document)['lb']! as Map<String, Object?>;
        pounds['overhead_press'] = invalid;
        expect(
          () => codec.decodeTemplates(jsonEncode(document)),
          throwsFormatException,
          reason: 'invalid increment $invalid',
        );
      }
    });
  });
}

ResolvedCycleDefinition _definition({
  required List<int> steps,
  TrainingMaxProgression? progression,
  CycleScheduleMode scheduleMode = CycleScheduleMode.fixed,
  List<int>? percentages,
  List<MainWorkWaveRole>? waveRoles,
}) => ResolvedCycleDefinition(
  catalogVersion: 2,
  templateId: 'progression',
  variantId: 'test',
  sessionMovementIds: _movements,
  sourceReference: 'test',
  scheduleReference: _scheduleReference,
  scheduleMode: scheduleMode,
  trainingMaxProgression: progression,
  weeks: [
    for (var weekIndex = 0; weekIndex < steps.length; weekIndex++)
      WeekDefinition(
        number: weekIndex + 1,
        origin: CatalogWeekOrigin(
          phaseId: 'phase',
          phaseIteration: 1,
          sourceWeekNumber: weekIndex + 1,
          trainingMaxProgressionStep: steps[weekIndex],
        ),
        sessions: [
          for (final movement in _movements)
            SessionDefinition(
              id: movement,
              role: movement.value,
              blocks: [
                BlockDefinition(
                  id: 'main-${movement.value}',
                  role: 'main_work',
                  movementId: movement,
                  mainWorkSemantics: waveRoles == null
                      ? null
                      : MainWorkSemantics(
                          waveRole: waveRoles[weekIndex],
                          lastSetPolicy: MainWorkLastSetPolicy.fixed,
                          setRoles: const [MainWorkSetRole.top],
                        ),
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: const FixedRepetitions(5),
                      load: TrainingMaxPercentageLoad(
                        Percentage(percentages?[weekIndex] ?? 10000),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
  ],
);

GeneratedCycle _compileFixed(
  ResolvedCycleDefinition definition,
  WeightUnit unit, {
  MainWorkExecutionOptions mainWork = const MainWorkExecutionOptions(),
}) => const CycleCompilerImpl().compileScheduled(
  definition: definition,
  schedule: _schedule(CycleScheduleMode.fixed, const {4}),
  selection: const CycleScheduleSelection(
    trainingDays: [1, 2, 4, 5],
    sessionOrder: [
      SessionId('overhead_press'),
      SessionId('deadlift'),
      SessionId('bench_press'),
      SessionId('squat'),
    ],
  ),
  request: _request(unit, const [1, 2, 4, 5], mainWork: mainWork),
);

ResolvedCycleSchedule _schedule(CycleScheduleMode mode, Set<int> frequencies) =>
    ResolvedCycleSchedule(
      id: 'schedule',
      mode: mode,
      sessions: [
        for (final movement in _movements)
          ScheduleSessionTemplate(
            id: SessionId(movement.value),
            role: 'mainLift',
            movementIds: [movement],
          ),
      ],
      allowedFrequencies: frequencies,
    );

CycleRequest _request(
  WeightUnit unit,
  List<int> trainingDays, {
  MainWorkExecutionOptions mainWork = const MainWorkExecutionOptions(),
}) => CycleRequest(
  cycleId: 'progression',
  startDate: DateTime(2026, 1, 5),
  trainingDays: trainingDays,
  sessionOrder: _movements,
  maxInputs: {
    for (final movement in _movements)
      movement: DirectTrainingMaxInput(Weight(10000, unit)),
  },
  globalTrainingMaxRatio: const Percentage(10000),
  unit: unit,
  roundingIncrement: Weight(50, unit),
  barProfile: BarProfile(
    weight: Weight(0, unit),
    platesPerSide: [
      for (final value in const [25, 50, 100, 200, 400, 800, 1600, 3200, 6400])
        Weight(value, unit),
    ],
  ),
  includeDeload: true,
  cycleOptions: CycleExecutionOptions(mainWork: mainWork),
);

Map<String, Object?> _templateDocument() => {
  'schemaVersion': 1,
  'kind': 'templates',
  'templates': [
    {
      'id': 'template',
      'revision': 1,
      'labels': {'en': 'Template', 'fr': 'Modèle'},
      'sourceRuleIds': ['test'],
      'surface': 'cyclePublic',
      'variants': [
        {
          'id': 'variant',
          'revision': 1,
          'labels': {'en': 'Variant', 'fr': 'Variante'},
          'sourceRuleIds': ['test'],
          'optionSchemaId': {'id': 'options', 'revision': 1},
          'scheduleIds': [
            {'id': 'schedule', 'revision': 1},
          ],
          'compatibilities': <String, Object?>{},
          'validExample': <String, Object?>{},
          'trainingMaxProgression': {
            'type': 'linear_phase_step',
            'incrementCentiUnitsByUnit': {
              'lb': {
                'overhead_press': 500,
                'bench_press': 500,
                'squat': 1000,
                'deadlift': 1000,
              },
              'kg': {
                'overhead_press': 250,
                'bench_press': 250,
                'squat': 500,
                'deadlift': 500,
              },
            },
          },
          'phases': [
            {
              'id': 'phase',
              'repeatCount': 1,
              'trainingMaxProgressionStep': 2,
              'weekPlans': [
                {
                  'weekNumber': 1,
                  'componentIds': [
                    {'id': 'main', 'revision': 1},
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
  ],
};

Map<String, Object?> _mutableTemplateDocument() =>
    jsonDecode(jsonEncode(_templateDocument()))! as Map<String, Object?>;

Map<String, Object?> _variant(Map<String, Object?> document) {
  final template =
      (document['templates']! as List<Object?>).single! as Map<String, Object?>;
  return (template['variants']! as List<Object?>).single!
      as Map<String, Object?>;
}

Map<String, Object?> _phase(Map<String, Object?> document) =>
    (_variant(document)['phases']! as List<Object?>).single!
        as Map<String, Object?>;

Map<String, Object?> _policy(Map<String, Object?> document) =>
    _variant(document)['trainingMaxProgression']! as Map<String, Object?>;

Map<String, Object?> _increments(Map<String, Object?> document) =>
    _policy(document)['incrementCentiUnitsByUnit']! as Map<String, Object?>;
