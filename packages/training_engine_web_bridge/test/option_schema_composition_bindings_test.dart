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
  final bundle =
      jsonDecode(
            File(
              '../../apps/web_generator/public/catalog.bundle.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
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
  final schema =
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
  return (schema['fields']! as List)
      .cast<Map<String, Object?>>()
      .map((field) => field['id']! as String)
      .toList(growable: false);
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
