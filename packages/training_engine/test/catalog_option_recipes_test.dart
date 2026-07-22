import 'dart:convert';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  test('source codec preserves fixed and parameterized load primitives', () {
    Map<String, Object?> component(String id, Map<String, Object?> load) => {
      'id': id,
      'revision': 1,
      'role': 'supplemental',
      'labels': {'en': id, 'fr': id},
      'sourceRuleIds': ['rule'],
      'parameterSchemaIds': <Object?>[],
      'constraints': <String, Object?>{},
      'compatibilities': <String, Object?>{},
      'block': {
        'id': id,
        'role': 'supplemental',
        'sets': [
          {
            'repetitions': {'type': 'fixed', 'count': 1},
            'load': load,
          },
        ],
      },
    };
    final decoded = const CatalogSourceDocumentCodec().decodeComponents(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'components',
        'components': [
          component('fixed', {
            'type': 'fixed',
            'centiUnits': 1250,
            'unit': 'kg',
          }),
          component('parameterized', {
            'type': 'parameterized_training_max_percentage',
            'parameterId': 'intensity',
            'defaultBasisPoints': 8000,
            'minimumBasisPoints': 5000,
            'maximumBasisPoints': 10000,
          }),
          component('main-plus', {
            'type': 'main_work_set_plus',
            'cumulativeIncreaseBasisPoints': 500,
          }),
        ],
      }),
    );
    expect(decoded[0].block.sets.single.load, isA<FixedLoad>());
    expect(
      decoded[1].block.sets.single.load,
      isA<ParameterizedTrainingMaxPercentageLoad>(),
    );
    expect(decoded[2].block.sets.single.load, isA<MainWorkSetPlusLoad>());
  });

  test('source recipes resolve and compile across weeks and sessions', () {
    const codec = CatalogSourceDocumentCodec();
    final components = codec.decodeComponents(jsonEncode(_componentsDocument));
    final schedules = codec.decodeSchedules(jsonEncode(_schedulesDocument));
    final template = codec
        .decodeTemplates(jsonEncode(_templatesDocument))
        .single;
    final recipes = codec.decodeCycleOptionRecipes(
      jsonEncode(_recipesDocument),
    );
    final variant = template.variants.single;
    final plan = const CatalogPlanDataResolver().resolve(
      catalogVersion: 1,
      template: template,
      variant: variant,
      scheduleReference: const ComponentReference('schedule', 1),
      schedules: schedules,
      components: components,
      sourceReference: 'test',
      optionRecipes: recipes,
    );
    final definition = const CatalogPlanResolver().resolve(plan);

    expect(definition.optionRecipes.warmUp, contains(WarmUpType.original));
    expect(definition.optionRecipes.deload, contains(DeloadType.type1));
    expect(definition.optionRecipes.joker!.steps, hasLength(6));
    expect(
      definition.optionRecipes.joker!.steps.first.repetitions,
      isA<JokerRepetitions>(),
    );

    final cycle = const CycleCompilerImpl().compile(
      definition,
      CycleRequest(
        cycleId: 'cycle',
        startDate: DateTime(2026, 1, 5),
        trainingDays: const [1, 3],
        sessionOrder: const [MovementId('upper'), MovementId('lower')],
        maxInputs: const {
          MovementId('upper'): DirectTrainingMaxInput(
            Weight(10000, WeightUnit.kg),
          ),
          MovementId('lower'): DirectTrainingMaxInput(
            Weight(15000, WeightUnit.kg),
          ),
        },
        globalTrainingMaxRatio: const Percentage(10000),
        unit: WeightUnit.kg,
        roundingIncrement: const Weight(100, WeightUnit.kg),
        barProfile: const BarProfile(
          weight: Weight(0, WeightUnit.kg),
          platesPerSide: [
            Weight(50, WeightUnit.kg),
            Weight(100, WeightUnit.kg),
            Weight(200, WeightUnit.kg),
            Weight(400, WeightUnit.kg),
            Weight(800, WeightUnit.kg),
            Weight(1600, WeightUnit.kg),
            Weight(3200, WeightUnit.kg),
            Weight(6400, WeightUnit.kg),
          ],
        ),
        cycleOptions: const CycleExecutionOptions(
          warmUp: WarmUpExecutionOptions(
            enabled: true,
            type: WarmUpType.original,
          ),
          joker: JokerExecutionOptions(enabled: true, ceilingBasisPoints: 500),
          deload: DeloadExecutionOptions(enabled: true, type: DeloadType.type1),
        ),
      ),
    );

    expect(cycle.weeks, hasLength(2));
    expect(cycle.weeks.every((week) => week.sessions.length == 2), isTrue);
    for (final session in cycle.weeks.first.sessions) {
      expect(
        session.blocks.where((block) => block.role == 'warm_up'),
        hasLength(1),
      );
      expect(
        session.blocks.where((block) => block.role == 'main_work'),
        hasLength(1),
      );
      expect(
        session.blocks.where((block) => block.role == 'joker'),
        hasLength(1),
      );
    }
    for (final session in cycle.weeks.last.sessions) {
      expect(
        session.blocks.where((block) => block.role == 'warm_up'),
        hasLength(1),
      );
      expect(
        session.blocks.where((block) => block.role == 'deload'),
        hasLength(1),
      );
      expect(session.blocks.where((block) => block.role == 'joker'), isEmpty);
    }
  });

  test('codec rejects unknown recipe enum keys and empty leaves', () {
    final invalid = Map<String, Object?>.from(_recipesDocument);
    invalid['cycleOptionRecipes'] = [
      {
        'id': 'options',
        'revision': 1,
        'warmUp': {
          'invented': {'componentIds': <Object?>[]},
        },
      },
    ];
    expect(
      () => const CatalogSourceDocumentCodec().decodeCycleOptionRecipes(
        jsonEncode(invalid),
      ),
      throwsFormatException,
    );
  });

  test('Beyond ramp is decoded from source and expanded before main work', () {
    final componentDocument =
        jsonDecode(jsonEncode(_componentsDocument)) as Map<String, Object?>;
    (componentDocument['components']! as List<Object?>).add({
      'id': 'beyond-upper',
      'revision': 1,
      'role': 'warm_up',
      'labels': {'en': 'Beyond', 'fr': 'Beyond'},
      'sourceRuleIds': ['rule'],
      'parameterSchemaIds': <Object?>[],
      'constraints': {'movementRelation': 'sameAsMain'},
      'compatibilities': {
        'movementIds': ['upper'],
      },
      'block': {
        'id': 'beyond-upper',
        'role': 'warm_up',
        'sets': [
          {
            'repetitions': {'type': 'fixed', 'count': 10},
            'load': {'type': 'unloaded'},
          },
          {
            'repetitions': {'type': 'fixed', 'count': 5},
            'load': {'type': 'warm_up_base', 'region': 'upperBody'},
          },
          {
            'repetitions': {
              'type': 'percentage_thresholds',
              'thresholds': [
                {'maximumBasisPoints': 5000, 'count': 5},
                {'maximumBasisPoints': 20000, 'count': 3},
              ],
            },
            'load': {
              'type': 'training_max_ramp',
              'anchor': 'before_main_work',
              'stepBasisPoints': 1000,
              'lowerBound': 'warm_up_base_plus_step_fraction',
              'lowerBoundStepFractionBasisPoints': 2500,
            },
          },
        ],
      },
    });
    final recipeDocument =
        jsonDecode(jsonEncode(_recipesDocument)) as Map<String, Object?>;
    final recipe =
        (recipeDocument['cycleOptionRecipes']! as List<Object?>).single
            as Map<String, Object?>;
    (recipe['warmUp']! as Map<String, Object?>)['beyond'] = {
      'componentIds': [
        {'id': 'beyond-upper', 'revision': 1},
      ],
    };
    const codec = CatalogSourceDocumentCodec();
    final components = codec.decodeComponents(jsonEncode(componentDocument));
    final schedules = codec.decodeSchedules(jsonEncode(_schedulesDocument));
    final template = codec
        .decodeTemplates(jsonEncode(_templatesDocument))
        .single;
    final definition = const CatalogPlanResolver().resolve(
      const CatalogPlanDataResolver().resolve(
        catalogVersion: 1,
        template: template,
        variant: template.variants.single,
        scheduleReference: const ComponentReference('schedule', 1),
        schedules: schedules,
        components: components,
        sourceReference: 'test',
        optionRecipes: codec.decodeCycleOptionRecipes(
          jsonEncode(recipeDocument),
        ),
      ),
    );
    final cycle = const CycleCompilerImpl().compile(
      definition,
      CycleRequest(
        cycleId: 'beyond',
        startDate: DateTime(2026, 1, 5),
        trainingDays: const [1, 3],
        sessionOrder: const [MovementId('upper'), MovementId('lower')],
        maxInputs: const {
          MovementId('upper'): DirectTrainingMaxInput(
            Weight(10000, WeightUnit.kg),
          ),
          MovementId('lower'): DirectTrainingMaxInput(
            Weight(15000, WeightUnit.kg),
          ),
        },
        globalTrainingMaxRatio: const Percentage(10000),
        unit: WeightUnit.kg,
        roundingIncrement: const Weight(100, WeightUnit.kg),
        barProfile: const BarProfile(
          weight: Weight(0, WeightUnit.kg),
          platesPerSide: [
            Weight(50, WeightUnit.kg),
            Weight(100, WeightUnit.kg),
            Weight(200, WeightUnit.kg),
            Weight(400, WeightUnit.kg),
            Weight(800, WeightUnit.kg),
            Weight(1600, WeightUnit.kg),
            Weight(3200, WeightUnit.kg),
          ],
        ),
        cycleOptions: const CycleExecutionOptions(
          warmUp: WarmUpExecutionOptions(
            enabled: true,
            type: WarmUpType.beyond,
            upperBodyBaseWeight: Weight(2000, WeightUnit.kg),
            lowerBodyBaseWeight: Weight(3000, WeightUnit.kg),
          ),
          deload: DeloadExecutionOptions(enabled: true, type: DeloadType.type1),
        ),
      ),
    );
    final warmUp = cycle.weeks.first.sessions.first.blocks.singleWhere(
      (block) => block.role == 'warm_up',
    );
    expect(warmUp.sets.map((set) => set.plannedLoad?.centiUnits), [
      null,
      2000,
      2500,
      3500,
      4500,
      5500,
      6500,
      7500,
    ]);
    expect(warmUp.sets.map((set) => set.repetitions['count']), [
      10,
      5,
      5,
      5,
      5,
      3,
      3,
      3,
    ]);
    expect(
      cycle.weeks.first.sessions.last.blocks.where(
        (block) => block.role == 'warm_up',
      ),
      isEmpty,
      reason: 'Explicit movement targets override sameAsMain expansion.',
    );
  });
}

final _componentsDocument = <String, Object?>{
  'schemaVersion': 1,
  'kind': 'components',
  'components': [
    ...[
      ('main', 'main_work', 'training_max_percentage', 8500),
      ('base-deload', 'deload', 'training_max_percentage', 6000),
      ('selected-deload', 'deload', 'training_max_percentage', 4000),
    ].map(
      (item) => {
        'id': item.$1,
        'revision': 1,
        'role': item.$2,
        'labels': {'en': item.$1, 'fr': item.$1},
        'sourceRuleIds': ['rule'],
        'parameterSchemaIds': <Object?>[],
        'constraints': {'movementRelation': 'sameAsMain'},
        'compatibilities': <String, Object?>{},
        'block': {
          'id': item.$1,
          'role': item.$2,
          'sets': [
            {
              'repetitions': {'type': 'fixed', 'count': 5},
              'load': {'type': item.$3, 'basisPoints': item.$4},
            },
          ],
        },
      },
    ),
    {
      'id': 'warm',
      'revision': 1,
      'role': 'warm_up',
      'labels': {'en': 'Warm', 'fr': 'Warm'},
      'sourceRuleIds': ['rule'],
      'parameterSchemaIds': <Object?>[],
      'constraints': {'movementRelation': 'sameAsMain'},
      'compatibilities': <String, Object?>{},
      'block': {
        'id': 'warm',
        'role': 'warm_up',
        'sets': [
          {
            'repetitions': {'type': 'fixed', 'count': 10},
            'load': {'type': 'unloaded'},
          },
        ],
      },
    },
  ],
};

const _schedulesDocument = {
  'schemaVersion': 1,
  'kind': 'schedules',
  'schedules': [
    {
      'id': 'schedule',
      'revision': 1,
      'labels': {'en': 'Schedule', 'fr': 'Schedule'},
      'sourceRuleIds': ['rule'],
      'type': 'weekly',
      'sessions': [
        {
          'id': 'upper',
          'role': 'main',
          'movementIds': ['upper'],
        },
        {
          'id': 'lower',
          'role': 'main',
          'movementIds': ['lower'],
        },
      ],
    },
  ],
};

const _templatesDocument = {
  'schemaVersion': 1,
  'kind': 'templates',
  'templates': [
    {
      'id': 'template',
      'revision': 1,
      'labels': {'en': 'Template', 'fr': 'Template'},
      'sourceRuleIds': ['rule'],
      'surface': 'cyclePublic',
      'variants': [
        {
          'id': 'variant',
          'revision': 1,
          'labels': {'en': 'Variant', 'fr': 'Variant'},
          'sourceRuleIds': ['rule'],
          'optionSchemaId': {'id': 'schema', 'revision': 1},
          'optionRecipeId': {'id': 'options', 'revision': 1},
          'scheduleIds': [
            {'id': 'schedule', 'revision': 1},
          ],
          'compatibilities': <String, Object?>{},
          'validExample': <String, Object?>{},
          'weekPlans': [
            {
              'weekNumber': 1,
              'componentIds': [
                {'id': 'main', 'revision': 1},
              ],
            },
            {
              'weekNumber': 2,
              'componentIds': [
                {'id': 'base-deload', 'revision': 1},
              ],
            },
          ],
          'assistancePlanIds': <Object?>[],
          'conditioningDefinitionIds': <Object?>[],
        },
      ],
    },
  ],
};

final _recipesDocument = <String, Object?>{
  'schemaVersion': 1,
  'kind': 'cycleOptionRecipes',
  'cycleOptionRecipes': [
    {
      'id': 'options',
      'revision': 1,
      'warmUp': {
        'original': {
          'componentIds': [
            {'id': 'warm', 'revision': 1},
          ],
        },
      },
      'joker': {
        'blockId': 'joker',
        'steps': [
          for (var rank = 1; rank <= 6; rank++)
            {
              'cumulativeIncreaseBasisPoints': rank * 500,
              'repetitions': {'type': 'joker'},
            },
        ],
      },
      'deload': {
        'type1': {
          'byUnit': {
            'kg': [
              {'id': 'selected-deload', 'revision': 1},
            ],
          },
        },
      },
    },
  ],
};
