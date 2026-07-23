import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

void main() {
  test('Bodyweight composes common controls before its own parameters', () {
    final service = _initializedService();
    final fieldIds = _fieldIds(
      service,
      templateId: 'classic_bodyweight',
      variantId: 'four_day',
    );

    expect(
      fieldIds,
      containsAll([
        'warmUp.enabled',
        'joker.enabled',
        'deload.enabled',
        'total_repetitions',
        'set_count',
      ]),
    );
    expect(
      fieldIds.indexOf('deload.enabled'),
      lessThan(fieldIds.indexOf('total_repetitions')),
    );
  });

  test('a composed Bodyweight Joker control changes generated blocks', () {
    final service = _initializedService();
    final withoutJoker = _generateBodyweight(service, jokerEnabled: false);
    final withJoker = _generateBodyweight(service, jokerEnabled: true);

    expect(_roles(withoutJoker), isNot(contains('joker')));
    expect(_roles(withJoker), contains('joker'));
  });

  test('every specialized schema exposes common and visible own fields', () {
    final service = _initializedService();
    const cases = [
      (
        templateId: 'classic_simplest_strength',
        variantId: 'original',
        specialized: <String>{},
      ),
      (
        templateId: 'classic_for_beginners',
        variantId: 'original_progression',
        specialized: {'supplemental_progression'},
      ),
      (
        templateId: 'classic_full_body',
        variantId: 'original',
        specialized: {'phase'},
      ),
      (
        templateId: 'classic_full_body',
        variantId: 'updated',
        specialized: {'squat_set_profile'},
      ),
      (
        templateId: 'classic_full_body',
        variantId: 'full_boring',
        specialized: {
          'squat_set_profile',
          'bench_set_profile',
          'deadlift_set_profile',
        },
      ),
    ];

    for (final item in cases) {
      final fieldIds = _fieldIds(
        service,
        templateId: item.templateId,
        variantId: item.variantId,
      );
      expect(
        fieldIds,
        containsAll({
          'warmUp.enabled',
          'joker.enabled',
          'deload.enabled',
          ...item.specialized,
        }),
        reason: '${item.templateId}/${item.variantId}',
      );
    }
  });

  test('FSL composes its conditional controls after common options', () {
    final service = _initializedService();
    final fields = _fields(
      service,
      templateId: 'source_calculator_first_set_last',
      variantId: 'standard',
    );
    final byId = {for (final field in fields) field['id']: field};

    expect(
      byId.keys,
      containsAll({
        'warmUp.enabled',
        'joker.enabled',
        'deload.enabled',
        'fsl_mode',
        'fsl_set_count',
        'fsl_repetitions',
      }),
    );
    expect(byId['fsl_mode']!['path'], 'options.fsl_mode');
    expect(byId['fsl_mode']!['value'], 'amrap');
    for (final id in const ['fsl_set_count', 'fsl_repetitions']) {
      expect(byId[id]!['visibleWhen'], [
        {'path': 'options.fsl_mode', 'operator': 'equals', 'value': 'multiple'},
      ]);
      expect(byId[id]!['enabledWhen'], byId[id]!['visibleWhen']);
    }
  });

  test('GVT exposes common and per-movement ratio modes conditionally', () {
    final service = _initializedService();
    final schema = _editorSchema(
      service,
      templateId: 'source_calculator_gvt',
      variantId: 'standard',
    );
    final fields = (schema['fields']! as List).cast<Map<String, Object?>>();
    final byId = {for (final field in fields) field['id']: field};
    final movements = (schema['movementIds']! as List).cast<String>();

    expect(
      byId.keys,
      containsAll({
        'warmUp.enabled',
        'joker.enabled',
        'deload.enabled',
        'gvt_use_same_ratio',
        'gvt_percentage',
        'gvt_alternate',
      }),
    );
    expect(byId['gvt_percentage']!['path'], 'options.gvt_percentage');
    expect(byId['gvt_percentage']!['visibleWhen'], [
      {
        'path': 'options.gvt_use_same_ratio',
        'operator': 'equals',
        'value': true,
      },
    ]);
    final perMovementFields = fields
        .where(
          (field) => (field['id']! as String).startsWith(
            'gvt_percentage_by_movement.',
          ),
        )
        .toList(growable: false);
    expect(perMovementFields, hasLength(movements.length));
    for (final movement in movements) {
      final field = byId['gvt_percentage_by_movement.$movement']!;
      expect(field['path'], 'options.gvt_percentage.$movement');
      expect(field['visibleWhen'], [
        {
          'path': 'options.gvt_use_same_ratio',
          'operator': 'equals',
          'value': false,
        },
      ]);
      expect(field['enabledWhen'], field['visibleWhen']);
    }
  });

  test('BBB Challenge composes its Less Boring switch with common options', () {
    final service = _initializedService();
    final fields = _fields(
      service,
      templateId: 'source_calculator_bbb_challenge',
      variantId: 'six_weeks',
    );
    final byId = {for (final field in fields) field['id']: field};

    expect(
      byId.keys,
      containsAll({
        'warmUp.enabled',
        'joker.enabled',
        'deload.enabled',
        'bbb_challenge_less_boring',
      }),
    );
    expect(byId['bbb_challenge_less_boring']!['kind'], 'boolean');
    expect(byId['bbb_challenge_less_boring']!['value'], true);
    expect(
      byId['bbb_challenge_less_boring']!['path'],
      'options.bbb_challenge_less_boring',
    );
  });

  test('2 Days variants compose common controls and Option Three profile', () {
    final service = _initializedService();
    for (final variantId in const [
      'option_one',
      'option_two',
      'option_three',
    ]) {
      final schema = _editorSchema(
        service,
        templateId: 'source_calculator_two_days_per_week',
        variantId: variantId,
      );
      final fields = (schema['fields']! as List).cast<Map<String, Object?>>();
      final byId = {for (final field in fields) field['id']: field};
      expect(
        byId.keys,
        containsAll({'warmUp.enabled', 'joker.enabled', 'deload.enabled'}),
        reason: variantId,
      );
      if (variantId == 'option_three') {
        final profile = byId['second_lift_profile']!;
        expect(profile['path'], 'options.second_lift_profile');
        expect(
          (profile['choices']! as List).cast<Map<String, Object?>>().map(
            (choice) => choice['value'],
          ),
          containsAll(['65_75_85', '70_80_90', '75_85_95', '80_90_100']),
        );
      } else {
        expect(byId, isNot(contains('second_lift_profile')));
      }
    }

    final optionOne = _editorSchema(
      service,
      templateId: 'source_calculator_two_days_per_week',
      variantId: 'option_one',
    );
    expect(optionOne['sessionIds'], [
      'deadlift_overhead_press',
      'squat_bench_press',
    ]);
  });

  const deloadOffCases = [
    (
      label: 'FSL',
      templateId: 'source_calculator_first_set_last',
      variantId: 'standard',
      scheduleId: 'schedule_four_day_fixed',
      expectedWeeks: 3,
      paired: false,
    ),
    (
      label: 'GVT',
      templateId: 'source_calculator_gvt',
      variantId: 'standard',
      scheduleId: 'schedule_four_day_fixed',
      expectedWeeks: 3,
      paired: false,
    ),
    (
      label: 'BBB Challenge',
      templateId: 'source_calculator_bbb_challenge',
      variantId: 'six_weeks',
      scheduleId: 'schedule_four_day_fixed',
      expectedWeeks: 6,
      paired: false,
    ),
    (
      label: '2 Days',
      templateId: 'source_calculator_two_days_per_week',
      variantId: 'option_one',
      scheduleId: 'schedule_two_day_paired_source_order',
      expectedWeeks: 3,
      paired: true,
    ),
  ];
  for (final item in deloadOffCases) {
    test('deload off removes the ${item.label} deload week', () {
      final service = _initializedService();
      final cycle = _generateSourceCycle(
        service,
        templateId: item.templateId,
        variantId: item.variantId,
        scheduleId: item.scheduleId,
        paired: item.paired,
      );
      expect(
        (cycle['weeks']! as List),
        hasLength(item.expectedWeeks),
        reason: item.label,
      );
      expect(_roles(cycle), isNot(contains('deload')), reason: item.label);
    });
  }

  test('Beginner preserves its per-movement training max ratio', () {
    final service = _initializedService();
    final fieldIds = _fieldIds(
      service,
      templateId: 'classic_for_beginners',
      variantId: 'original_progression',
    );

    expect(
      fieldIds.where((id) => id.startsWith('training_max_ratio.')),
      hasLength(4),
    );
    expect(fieldIds, isNot(contains('training_max_ratio')));
  });

  test('initialization rejects a missing included schema', () {
    final bundle = _catalogBundle();
    final bodyweight = _optionSchema(bundle, 'classic_bodyweight_options');
    (bodyweight['includeSchemaIds']! as List)[0] = <String, Object?>{
      'id': 'missing_options',
      'revision': 1,
    };

    expect(
      () => LocalTrainingEngineBindings().initialize(jsonEncode(bundle)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'message',
          contains('OPTION_SCHEMA_REFERENCE_NOT_FOUND:missing_options@1'),
        ),
      ),
    );
  });

  test('initialization rejects an included-schema cycle', () {
    final bundle = _catalogBundle();
    final common = _optionSchema(bundle, 'classic_crosscut_options');
    common['includeSchemaIds'] = [
      {'id': 'classic_bodyweight_options', 'revision': 1},
    ];

    expect(
      () => LocalTrainingEngineBindings().initialize(jsonEncode(bundle)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'message',
          contains('OPTION_SCHEMA_CYCLE:'),
        ),
      ),
    );
  });

  test('initialization rejects duplicate flattened parameter ids', () {
    final bundle = _catalogBundle();
    final common = _optionSchema(bundle, 'classic_crosscut_options');
    final bodyweight = _optionSchema(bundle, 'classic_bodyweight_options');
    final joker = (common['parameters']! as List)
        .cast<Map<String, Object?>>()
        .singleWhere((parameter) => parameter['id'] == 'joker.enabled');
    (bodyweight['parameters']! as List).add(
      jsonDecode(jsonEncode(joker)) as Map<String, Object?>,
    );

    expect(
      () => LocalTrainingEngineBindings().initialize(jsonEncode(bundle)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'message',
          contains('DUPLICATE_OPTION_PARAMETER_ID:joker.enabled'),
        ),
      ),
    );
  });
}

BridgeService _initializedService() {
  final service = BridgeService(LocalTrainingEngineBindings());
  service.initialize(jsonEncode(_catalogBundle()));
  return service;
}

Map<String, Object?> _catalogBundle() {
  final catalogPath =
      Platform.environment['TRAINING_ENGINE_CATALOG_BUNDLE'] ??
      '../../apps/web_generator/public/catalog.bundle.json';
  final bundle =
      jsonDecode(File(catalogPath).readAsStringSync()) as Map<String, Object?>;
  for (final rawDocument in (bundle['documents']! as List).cast<Map>()) {
    final document = rawDocument.cast<String, Object?>();
    final content = (document['content']! as Map).cast<String, Object?>();
    final path = document['path']! as String;
    if (content['kind'] == 'assistancePlans' ||
        path == 'classic/option_schemas.json' ||
        path == 'classic/extended/option_schemas.json') {
      document['content'] = jsonDecode(
        File('../../catalog_src/$path').readAsStringSync(),
      );
    }
  }
  return bundle;
}

Map<String, Object?> _optionSchema(
  Map<String, Object?> bundle,
  String schemaId,
) {
  for (final rawDocument in (bundle['documents']! as List).cast<Map>()) {
    final content = (rawDocument['content']! as Map).cast<String, Object?>();
    if (content['kind'] != 'optionSchemas') continue;
    for (final rawSchema in (content['optionSchemas']! as List).cast<Map>()) {
      final schema = rawSchema.cast<String, Object?>();
      if (schema['id'] == schemaId) return schema;
    }
  }
  throw StateError('Missing fixture option schema $schemaId');
}

List<String> _fieldIds(
  BridgeService service, {
  required String templateId,
  required String variantId,
}) {
  return _fields(service, templateId: templateId, variantId: variantId)
      .cast<Map<String, Object?>>()
      .map((field) => field['id']! as String)
      .toList(growable: false);
}

Map<String, Object?> _editorSchema(
  BridgeService service, {
  required String templateId,
  required String variantId,
}) =>
    jsonDecode(
          service.cycleEditorSchema(
            jsonEncode({
              'apiVersion': 'v1',
              'schemaVersion': 1,
              'templateId': templateId,
              'variantId': variantId,
            }),
          ),
        )
        as Map<String, Object?>;

List<Map<String, Object?>> _fields(
  BridgeService service, {
  required String templateId,
  required String variantId,
}) =>
    (_editorSchema(
              service,
              templateId: templateId,
              variantId: variantId,
            )['fields']!
            as List)
        .cast<Map<String, Object?>>();

Map<String, Object?> _generateSourceCycle(
  BridgeService service, {
  required String templateId,
  required String variantId,
  required String scheduleId,
  required bool paired,
}) {
  final response =
      jsonDecode(
            service.generateCycle(
              jsonEncode({
                'apiVersion': 'v1',
                'schemaVersion': 1,
                'cycleId': 'source-deload-off',
                'templateId': templateId,
                'variantId': variantId,
                'scheduleId': scheduleId,
                'startDate': '2026-07-27T00:00:00.000Z',
                'trainingDays': paired ? [1, 4] : [1, 2, 4, 5],
                'sessionOrder': paired
                    ? ['deadlift_overhead_press', 'squat_bench_press']
                    : ['overhead_press', 'deadlift', 'bench_press', 'squat'],
                'maxInputs': {
                  for (final movement in const [
                    'overhead_press',
                    'deadlift',
                    'bench_press',
                    'squat',
                  ])
                    movement: {
                      'type': 'oneRepMax',
                      'weight': {'centiUnits': 10000, 'unit': 'lb'},
                    },
                },
                'globalTrainingMaxRatioBasisPoints': 9000,
                'trainingMaxRatioByMovement': <String, Object?>{},
                'percentageParameters': <String, Object?>{},
                'percentageParametersByMovement': <String, Object?>{},
                'options': {
                  'warmUp': {'enabled': false},
                  'joker': {'enabled': false},
                  'deload': {'enabled': false},
                },
                'unit': 'lb',
                'roundingIncrement': {'centiUnits': 500, 'unit': 'lb'},
                'barProfile': {
                  'weight': {'centiUnits': 4500, 'unit': 'lb'},
                  'platesPerSide': [
                    {'centiUnits': 4500, 'unit': 'lb'},
                    {'centiUnits': 2500, 'unit': 'lb'},
                    {'centiUnits': 1000, 'unit': 'lb'},
                    {'centiUnits': 500, 'unit': 'lb'},
                    {'centiUnits': 250, 'unit': 'lb'},
                  ],
                },
                'includeDeload': false,
              }),
            ),
          )
          as Map<String, Object?>;
  return response['cycle']! as Map<String, Object?>;
}

Map<String, Object?> _generateBodyweight(
  BridgeService service, {
  required bool jokerEnabled,
}) {
  final response =
      jsonDecode(
            service.generateCycle(
              jsonEncode({
                'apiVersion': 'v1',
                'schemaVersion': 1,
                'cycleId': 'composed-bodyweight',
                'templateId': 'classic_bodyweight',
                'variantId': 'four_day',
                'scheduleId': 'schedule_four_day_fixed',
                'startDate': '2026-07-27T00:00:00.000Z',
                'trainingDays': [1, 2, 4, 5],
                'sessionOrder': [
                  'overhead_press',
                  'deadlift',
                  'bench_press',
                  'squat',
                ],
                'maxInputs': {
                  for (final movement in const [
                    'overhead_press',
                    'deadlift',
                    'bench_press',
                    'squat',
                  ])
                    movement: {
                      'type': 'oneRepMax',
                      'weight': {'centiUnits': 10000, 'unit': 'lb'},
                    },
                },
                'globalTrainingMaxRatioBasisPoints': 9000,
                'trainingMaxRatioByMovement': <String, Object?>{},
                'percentageParameters': <String, Object?>{},
                'percentageParametersByMovement': <String, Object?>{},
                'options': {
                  'warmUp': {'enabled': false},
                  'joker': {
                    'enabled': jokerEnabled,
                    if (jokerEnabled) 'ceilingBasisPoints': 500,
                  },
                  'deload': {'enabled': false},
                  'total_repetitions': 80,
                  'set_count': 5,
                },
                'unit': 'lb',
                'roundingIncrement': {'centiUnits': 500, 'unit': 'lb'},
                'barProfile': {
                  'weight': {'centiUnits': 4500, 'unit': 'lb'},
                  'platesPerSide': [
                    {'centiUnits': 4500, 'unit': 'lb'},
                    {'centiUnits': 2500, 'unit': 'lb'},
                    {'centiUnits': 1000, 'unit': 'lb'},
                    {'centiUnits': 500, 'unit': 'lb'},
                    {'centiUnits': 250, 'unit': 'lb'},
                  ],
                },
                'includeDeload': false,
              }),
            ),
          )
          as Map<String, Object?>;
  return response['cycle']! as Map<String, Object?>;
}

Set<Object?> _roles(Map<String, Object?> cycle) => {
  for (final week in (cycle['weeks']! as List).cast<Map<String, Object?>>())
    for (final session
        in (week['sessions']! as List).cast<Map<String, Object?>>())
      for (final block
          in (session['blocks']! as List).cast<Map<String, Object?>>())
        block['role'],
};
