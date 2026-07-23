import 'dart:convert';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _componentReference = ComponentReference('parameterized-component', 1);
const _scheduleReference = ComponentReference('schedule', 1);
const _movement = MovementId('squat');

void main() {
  group('catalog set parameter codec and resolution', () {
    test('fixed 10x10 expands before plan compilation', () {
      final component = _decodeComponent(
        repetitions: {'type': 'fixed', 'count': 10},
        multiplicity: {'type': 'fixed', 'count': 10},
      );

      final sourceSet = component.block.sets.single;
      expect(sourceSet.repetitions, isA<FixedRepetitions>());
      expect(sourceSet.multiplicity, isA<FixedSetMultiplicity>());
      expect((sourceSet.multiplicity as FixedSetMultiplicity).count, 10);

      final plan = _resolvePlan(component);
      expect(plan.components.single.block.sets, hasLength(10));
      expect(
        plan.components.single.block.sets,
        everyElement(
          isA<PrescribedSetDefinition>()
              .having(
                (set) => (set.repetitions as FixedRepetitions).count,
                'repetitions',
                10,
              )
              .having(
                (set) => (set.multiplicity as FixedSetMultiplicity).count,
                'resolved multiplicity',
                1,
              ),
        ),
      );

      final definition = const CatalogPlanResolver().resolve(plan);
      final generated = const CycleCompilerImpl().compile(
        definition,
        _request(),
      );
      final generatedSets =
          generated.weeks.single.sessions.single.blocks.single.sets;
      expect(generatedSets, hasLength(10));
      expect(
        generatedSets.map((set) => set.repetitions),
        everyElement({'type': 'fixed', 'count': 10}),
      );
      final responseJson = jsonEncode(generated.toJson());
      expect(responseJson, isNot(contains('"type":"parameterized_fixed"')));
      expect(responseJson, isNot(contains('"multiplicity"')));
    });

    test('parameterized prescriptions resolve as 3x5 and 5x8', () {
      final component = _decodeComponent(
        repetitions: {
          'type': 'parameterized_fixed',
          'parameterId': 'repetition_count',
          'default': 5,
          'minimum': 5,
          'maximum': 8,
        },
        multiplicity: {
          'type': 'parameterized',
          'parameterId': 'set_count',
          'default': 3,
          'minimum': 3,
          'maximum': 5,
        },
      );

      void expectVolume(
        CatalogPlan plan, {
        required int sets,
        required int repetitions,
      }) {
        final resolved = plan.components.single.block.sets;
        expect(resolved, hasLength(sets));
        expect(
          resolved.map((set) => (set.repetitions as FixedRepetitions).count),
          everyElement(repetitions),
        );
        expect(
          resolved.map(
            (set) => (set.multiplicity as FixedSetMultiplicity).count,
          ),
          everyElement(1),
        );
      }

      expectVolume(_resolvePlan(component), sets: 3, repetitions: 5);
      expectVolume(
        _resolvePlan(
          component,
          optionDefaults: const {'set_count': 5, 'repetition_count': 8},
        ),
        sets: 5,
        repetitions: 8,
      );
      expectVolume(
        _resolvePlan(
          component,
          optionValues: const {'set_count': 3, 'repetition_count': 5},
          optionDefaults: const {'set_count': 5, 'repetition_count': 8},
        ),
        sets: 3,
        repetitions: 5,
      );
    });

    test('codec rejects invalid parameter shapes, types, and bounds', () {
      Map<String, Object?> repetitions({
        Object defaultValue = 5,
        Object minimum = 3,
        Object maximum = 8,
        bool unknown = false,
      }) => {
        'type': 'parameterized_fixed',
        'parameterId': 'repetition_count',
        'default': defaultValue,
        'minimum': minimum,
        'maximum': maximum,
        if (unknown) 'unexpected': true,
      };
      Map<String, Object?> multiplicity({
        Object defaultValue = 3,
        Object minimum = 3,
        Object maximum = 5,
      }) => {
        'type': 'parameterized',
        'parameterId': 'set_count',
        'default': defaultValue,
        'minimum': minimum,
        'maximum': maximum,
      };

      for (final invalid in [
        () => _decodeComponent(
          repetitions: repetitions(defaultValue: 9),
          multiplicity: multiplicity(),
        ),
        () => _decodeComponent(
          repetitions: repetitions(defaultValue: '5'),
          multiplicity: multiplicity(),
        ),
        () => _decodeComponent(
          repetitions: repetitions(minimum: 0),
          multiplicity: multiplicity(),
        ),
        () => _decodeComponent(
          repetitions: repetitions(unknown: true),
          multiplicity: multiplicity(),
        ),
        () => _decodeComponent(
          repetitions: repetitions(),
          multiplicity: multiplicity(defaultValue: 2),
        ),
        () => _decodeComponent(
          repetitions: repetitions(),
          multiplicity: multiplicity(maximum: 2),
        ),
      ]) {
        expect(invalid, throwsFormatException);
      }
    });

    test('resolver rejects non-integer and out-of-bounds values', () {
      final component = _decodeComponent(
        repetitions: {
          'type': 'parameterized_fixed',
          'parameterId': 'repetition_count',
          'default': 5,
          'minimum': 5,
          'maximum': 8,
        },
        multiplicity: {
          'type': 'parameterized',
          'parameterId': 'set_count',
          'default': 3,
          'minimum': 3,
          'maximum': 5,
        },
      );

      for (final values in const <Map<String, Object?>>[
        {'set_count': 2},
        {'set_count': 6},
        {'set_count': '5'},
        {'set_count': 5.0},
        {'set_count': null},
        {'repetition_count': 4},
        {'repetition_count': 9},
        {'repetition_count': '8'},
        {'repetition_count': 8.0},
        {'repetition_count': null},
      ]) {
        expect(
          () => _resolvePlan(component, optionValues: values),
          throwsFormatException,
        );
      }
      expect(
        () =>
            _resolvePlan(component, optionDefaults: const {'set_count': false}),
        throwsFormatException,
      );
    });

    test('legacy sets without multiplicity remain one ordinary set', () {
      final component = _decodeComponent(
        repetitions: {'type': 'fixed', 'count': 5},
      );

      final sourceSet = component.block.sets.single;
      expect(sourceSet.multiplicity, isA<FixedSetMultiplicity>());
      expect((sourceSet.multiplicity as FixedSetMultiplicity).count, 1);
      final resolved = _resolvePlan(
        component,
      ).components.single.block.sets.single;
      expect((resolved.repetitions as FixedRepetitions).count, 5);
      expect((resolved.multiplicity as FixedSetMultiplicity).count, 1);
    });
  });

  group('compiler resolution boundary', () {
    test('rejects an unexpanded fixed multiplicity', () {
      expect(
        () => const CycleCompilerImpl().compile(
          _directDefinition(
            const PrescribedSetDefinition(
              repetitions: FixedRepetitions(10),
              load: Unloaded(),
              multiplicity: FixedSetMultiplicity(10),
            ),
          ),
          _request(),
        ),
        throwsA(
          isA<CycleGenerationException>().having(
            (error) => error.code,
            'code',
            CycleGenerationErrorCode.invalidCycleOptions,
          ),
        ),
      );
    });

    test('rejects an unresolved parameterized multiplicity', () {
      expect(
        () => const CycleCompilerImpl().compile(
          _directDefinition(
            const PrescribedSetDefinition(
              repetitions: FixedRepetitions(5),
              load: Unloaded(),
              multiplicity: ParameterizedSetMultiplicity(
                parameterId: 'set_count',
                defaultValue: 3,
                minimum: 3,
                maximum: 5,
              ),
            ),
          ),
          _request(),
        ),
        throwsA(
          isA<CycleGenerationException>().having(
            (error) => error.code,
            'code',
            CycleGenerationErrorCode.invalidCycleOptions,
          ),
        ),
      );
    });

    test('rejects unresolved parameterized repetitions', () {
      expect(
        () => const CycleCompilerImpl().compile(
          _directDefinition(
            const PrescribedSetDefinition(
              repetitions: ParameterizedFixedRepetitions(
                parameterId: 'repetition_count',
                defaultValue: 5,
                minimum: 5,
                maximum: 8,
              ),
              load: Unloaded(),
            ),
          ),
          _request(),
        ),
        throwsA(
          isA<CycleGenerationException>().having(
            (error) => error.code,
            'code',
            CycleGenerationErrorCode.invalidCycleOptions,
          ),
        ),
      );
    });
  });
}

SourceComponent _decodeComponent({
  required Map<String, Object?> repetitions,
  Map<String, Object?>? multiplicity,
}) {
  final document = {
    'schemaVersion': 1,
    'kind': 'components',
    'components': [
      {
        'id': _componentReference.id,
        'revision': _componentReference.revision,
        'role': 'supplemental',
        'labels': {'en': 'Parameter test', 'fr': 'Test de paramètre'},
        'sourceRuleIds': ['test'],
        'parameterSchemaIds': <Object?>[],
        'constraints': <String, Object?>{},
        'compatibilities': <String, Object?>{},
        'block': {
          'id': 'set-block',
          'role': 'supplemental',
          'sets': [
            {
              'repetitions': repetitions,
              'load': {'type': 'unloaded'},
              'multiplicity': ?multiplicity,
            },
          ],
        },
      },
    ],
  };
  return const CatalogSourceDocumentCodec()
      .decodeComponents(jsonEncode(document))
      .single;
}

CatalogPlan _resolvePlan(
  SourceComponent component, {
  Map<String, Object?> optionValues = const {},
  Map<String, Object?> optionDefaults = const {},
}) => CatalogPlanDataResolver().resolve(
  catalogVersion: 1,
  template: _template(),
  variant: _variant(),
  scheduleReference: _scheduleReference,
  schedules: const [_schedule],
  components: [component],
  sourceReference: 'test',
  optionValues: optionValues,
  optionDefaults: optionDefaults,
);

SourceTemplate _template() => SourceTemplate(
  id: 'template',
  revision: 1,
  surface: TemplateSurface.cyclePublic,
  generation: const SourceTemplateGeneration(
    id: 'test',
    labels: {'en': 'Test', 'fr': 'Test'},
  ),
  variants: [_variant()],
);

SourceVariant _variant() => const SourceVariant(
  id: 'variant',
  revision: 1,
  scheduleIds: [_scheduleReference],
  weekPlans: [
    CatalogWeekPlan(weekNumber: 1, components: [_componentReference]),
  ],
  phases: [],
  compatibilities: {},
  optionSchemaId: ComponentReference('options', 1),
);

const _schedule = SourceSchedule(
  reference: _scheduleReference,
  sessions: [
    SourceSession(id: 'squat', movementIds: ['squat']),
  ],
);

ResolvedCycleDefinition _directDefinition(PrescribedSetDefinition set) =>
    ResolvedCycleDefinition(
      catalogVersion: 1,
      templateId: 'template',
      variantId: 'variant',
      sessionMovementIds: const [_movement],
      weeks: [
        WeekDefinition(
          number: 1,
          blocks: [
            BlockDefinition(id: 'block', role: 'supplemental', sets: [set]),
          ],
        ),
      ],
      sourceReference: 'test',
    );

CycleRequest _request() => CycleRequest(
  cycleId: 'cycle',
  startDate: DateTime(2026, 1, 5),
  trainingDays: const [DateTime.monday],
  sessionOrder: const [_movement],
  maxInputs: const {},
  globalTrainingMaxRatio: const Percentage(9000),
  unit: WeightUnit.kg,
  roundingIncrement: const Weight(100, WeightUnit.kg),
  barProfile: const BarProfile(
    weight: Weight(0, WeightUnit.kg),
    platesPerSide: [Weight(100, WeightUnit.kg)],
  ),
);
