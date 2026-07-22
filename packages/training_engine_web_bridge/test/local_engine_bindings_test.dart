import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

void main() {
  BridgeService initializedService() {
    final service = BridgeService(LocalTrainingEngineBindings());
    final catalogPath =
        Platform.environment['TRAINING_ENGINE_CATALOG_BUNDLE'] ??
        '../../apps/web_generator/public/catalog.bundle.json';
    final bundle = jsonDecode(File(catalogPath).readAsStringSync()) as Map;
    for (final document in (bundle['documents'] as List).cast<Map>()) {
      final path = document['path'];
      if (path == 'classic/option_schemas.json' ||
          path == 'classic/extended/option_schemas.json') {
        document['content'] = jsonDecode(
          File('../../catalog_src/$path').readAsStringSync(),
        );
      }
      final content = document['content'] as Map;
      if (content['kind'] == 'templates') {
        for (final template in (content['templates'] as List).cast<Map>()) {
          if (template['id'] == 'classic_boring_but_big') {
            template['isDefault'] = true;
          }
        }
      }
    }
    service.initialize(jsonEncode(bundle));
    return service;
  }

  test('generateCycle returns the complete v1 response envelope', () {
    final service = initializedService();
    final response =
        jsonDecode(service.generateCycle(jsonEncode(_cycleRequest)))
            as Map<String, Object?>;
    expect(response['apiVersion'], 'v1');
    expect(response['cycle'], isA<Map<String, Object?>>());
    expect(response['warnings'], isEmpty);
    expect((response['snapshot'] as Map<String, Object?>)['kind'], 'cycle');
  });

  test('catalogIndex places the unique catalog default first', () {
    final service = initializedService();
    final index =
        jsonDecode(
              service.catalogIndex(
                jsonEncode({'apiVersion': 'v1', 'schemaVersion': 1}),
              ),
            )
            as Map<String, Object?>;
    final templates = (index['templates'] as List).cast<Map<String, Object?>>();
    expect(templates.first['id'], 'classic_boring_but_big');
  });

  test('generateCycle resolves and applies the catalog option recipe', () {
    final service = initializedService();
    final response =
        jsonDecode(
              service.generateCycle(
                jsonEncode({
                  ..._cycleRequest,
                  'includeDeload': false,
                  'options': {
                    'warmUp': {'enabled': false},
                    'joker': {'enabled': true, 'ceilingBasisPoints': 500},
                    'deload': {'enabled': false},
                  },
                }),
              ),
            )
            as Map<String, Object?>;
    expect(jsonEncode(response['cycle']), contains('"role":"joker"'));
  });

  test('Full Body editor uses requestPath while preserving parameter id', () {
    final service = initializedService();
    final schema =
        jsonDecode(
              service.cycleEditorSchema(
                jsonEncode({
                  'apiVersion': 'v1',
                  'schemaVersion': 1,
                  'templateId': 'classic_full_body',
                  'variantId': 'original',
                }),
              ),
            )
            as Map<String, Object?>;
    final fields = (schema['fields'] as List).cast<Map<String, Object?>>();
    expect((schema['movementIds'] as List).toSet(), {
      'back_squat',
      'bench_press',
      'deadlift',
      'overhead_press',
    });
    expect(schema['sessionIds'], ['monday', 'wednesday', 'friday']);
    final sessionOrder = fields.singleWhere(
      (field) => field['id'] == 'session-order',
    );
    expect(sessionOrder['value'], schema['sessionIds']);
    final phase = fields.singleWhere((field) => field['id'] == 'phase');
    expect(phase['path'], 'options.fullBody.phase');
    expect(phase['kind'], 'choice');
    expect(
      (phase['choices'] as List).cast<Map<String, Object?>>().map(
        (choice) => choice['value'],
      ),
      ['phase_one', 'phase_two', 'phase_three'],
    );
  });

  test('legacy Full Body editor applies catalog alias overrides', () {
    final service = initializedService();
    final schema =
        jsonDecode(
              service.cycleEditorSchema(
                jsonEncode({
                  'apiVersion': 'v1',
                  'schemaVersion': 1,
                  'templateId': 'classic_full_body_phase_2',
                  'variantId': 'phase_2',
                }),
              ),
            )
            as Map<String, Object?>;
    expect(schema['templateId'], 'classic_full_body');
    expect(schema['variantId'], 'original');
    final fields = (schema['fields'] as List).cast<Map<String, Object?>>();
    final phase = fields.singleWhere((field) => field['id'] == 'phase');
    expect(phase['path'], 'options.fullBody.phase');
    expect(phase['value'], 'phase_two');
  });

  test('legacy Full Body request validates and generates canonically', () {
    final service = initializedService();
    final legacyRequest = {
      ..._cycleRequest,
      'templateId': 'classic_full_body_phase_2',
      'variantId': 'phase_2',
      'scheduleId': 'classic_full_body_three_day',
      'trainingDays': [1, 3, 5],
      'sessionOrder': ['monday', 'wednesday', 'friday'],
      'maxInputs': {
        'back_squat': {'type': 'oneRepMax', 'weight': _weight},
        'bench_press': {'type': 'oneRepMax', 'weight': _weight},
        'deadlift': {'type': 'oneRepMax', 'weight': _weight},
        'overhead_press': {'type': 'oneRepMax', 'weight': _weight},
      },
      'options': <String, Object?>{},
      'includeDeload': false,
    };
    final validation =
        jsonDecode(service.validateCycle(jsonEncode(legacyRequest)))
            as Map<String, Object?>;
    expect(validation['valid'], true, reason: jsonEncode(validation['errors']));
    final response =
        jsonDecode(service.generateCycle(jsonEncode(legacyRequest)))
            as Map<String, Object?>;
    final cycle = response['cycle'] as Map<String, Object?>;
    expect(cycle['templateId'], 'classic_full_body');
    expect(cycle['variantId'], 'original');
  });

  test(
    'crosscut editor conditions use canonical request paths recursively',
    () {
      final service = initializedService();
      final schema =
          jsonDecode(
                service.cycleEditorSchema(
                  jsonEncode({
                    'apiVersion': 'v1',
                    'schemaVersion': 1,
                    'templateId': 'classic_531',
                    'variantId': 'four_day',
                  }),
                ),
              )
              as Map<String, Object?>;
      final fields = (schema['fields'] as List).cast<Map<String, Object?>>();
      final warmUpType = fields.singleWhere(
        (field) => field['id'] == 'warmUp.type',
      );
      expect(warmUpType['path'], 'options.warmUp.type');
      expect(warmUpType['visibleWhen'], [
        {'path': 'options.warmUp.enabled', 'operator': 'equals', 'value': true},
      ]);
      final lowerBase = fields.singleWhere(
        (field) => field['id'] == 'warmUp.bases.lowerBody',
      );
      expect(lowerBase['kind'], 'weight');
      expect(lowerBase['visibleWhen'], [
        {'path': 'options.warmUp.enabled', 'operator': 'equals', 'value': true},
        {
          'path': 'options.warmUp.type',
          'operator': 'equals',
          'value': 'beyond',
        },
      ]);
      expect(lowerBase['enabledWhen'], lowerBase['visibleWhen']);
    },
  );

  test(
    'generateMacrocycle resolves catalog definition and composes every node',
    () {
      final service = initializedService();
      final response =
          jsonDecode(service.generateMacrocycle(jsonEncode(_foreverRequest)))
              as Map<String, Object?>;
      final macrocycle = response['macrocycle'] as Map<String, Object?>;
      expect(response['apiVersion'], 'v1');
      expect(macrocycle['definitionId'], 'forever_bbb_2_leader_1_anchor');
      expect(macrocycle['nodes'], hasLength(5));
      expect(
        (response['snapshot'] as Map<String, Object?>)['kind'],
        'macrocycle',
      );
    },
  );

  test('generateMacrocycle rejects unknown public keys', () {
    final service = initializedService();
    expect(
      () => service.generateMacrocycle(
        jsonEncode({..._foreverRequest, 'unexpected': true}),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'normalizer migrates legacy option ids and removes inactive children',
    () {
      final normalized = normalizeCycleRequest({
        ..._cycleRequest,
        'options': {
          'warmup': 1,
          'lowerBase': 40,
          'upperBase': 20,
          'jokerMax': 0,
          'deload': 5,
          'deloadSkipWarmup': true,
        },
      });
      expect(normalized['options'], {
        'warmUp': {
          'enabled': true,
          'type': 'beyond',
          'bases': {
            'lowerBody': {'centiUnits': 4000, 'unit': 'lb'},
            'upperBody': {'centiUnits': 2000, 'unit': 'lb'},
          },
        },
        'joker': {'enabled': false},
        'deload': {'enabled': true, 'type': 'highIntensity'},
      });
      expect(normalized['includeDeload'], true);
    },
  );

  test('normalizer migrates legacy Full Body option ids and profiles', () {
    final normalized = normalizeCycleRequest({
      ..._cycleRequest,
      'templateId': 'fullBody',
      'variantId': 'legacy',
      'options': {
        'option': 0,
        'phase': 2,
        'ratios': [0, 0, 0],
      },
    });
    expect(normalized['templateId'], 'fullBody');
    expect(normalized['variantId'], 'legacy');
    expect((normalized['options'] as Map)['fullBody'], {
      'profile': 'original',
      'phase': 'phase_three',
    });
  });

  test('normalizer rejects unknown nested option keys', () {
    expect(
      () => normalizeCycleRequest({
        ..._cycleRequest,
        'options': {
          'joker': {
            'enabled': true,
            'ceilingBasisPoints': 500,
            'unexpected': true,
          },
        },
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

const _weight = {'centiUnits': 10000, 'unit': 'lb'};
const _cycleReferenceLeader = {
  'templateId': 'forever_bbb_leader',
  'variantId': 'fives_pro_5x10_50',
  'templateRevision': 1,
  'variantRevision': 1,
};
const _cycleRequest = {
  'apiVersion': 'v1',
  'schemaVersion': 1,
  'cycleId': 'bridge-cycle',
  'templateId': 'classic_531',
  'variantId': 'four_day',
  'scheduleId': 'schedule_four_day_fixed',
  'startDate': '2026-07-27T00:00:00.000Z',
  'trainingDays': [1, 2, 4, 5],
  'sessionOrder': ['overhead_press', 'deadlift', 'bench_press', 'squat'],
  'maxInputs': {
    'overhead_press': {'type': 'oneRepMax', 'weight': _weight},
    'deadlift': {'type': 'oneRepMax', 'weight': _weight},
    'bench_press': {'type': 'oneRepMax', 'weight': _weight},
    'squat': {'type': 'oneRepMax', 'weight': _weight},
  },
  'globalTrainingMaxRatioBasisPoints': 9000,
  'trainingMaxRatioByMovement': {},
  'percentageParameters': {},
  'percentageParametersByMovement': {},
  'options': {},
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
  'includeDeload': true,
};

Map<String, Object?> get _foreverRequest {
  Map<String, Object?> slot(String id, Map<String, Object?> cycle) => {
    'slotId': id,
    'cycle': cycle,
    'trainingDays': [1, 2, 4, 5],
    'sessionOrder': ['overhead_press', 'deadlift', 'bench_press', 'squat'],
    'enabled': true,
    'percentageParameters': <String, Object?>{},
    'percentageParametersByMovement': <String, Object?>{},
    'globalTrainingMaxRatioBasisPoints': 10000,
    'trainingMaxRatioByMovementBasisPoints': <String, Object?>{},
    'includeDeload': true,
  };

  return {
    'apiVersion': 'v1',
    'schemaVersion': 1,
    'macrocycleId': 'bridge-forever',
    'definitionId': 'forever_bbb_2_leader_1_anchor',
    'definitionRevision': 1,
    'startDate': '2026-07-27T00:00:00.000Z',
    'initialTrainingMaxes': {
      'overhead_press': _weight,
      'deadlift': _weight,
      'bench_press': _weight,
      'squat': _weight,
    },
    'slotRequests': {
      'leader': slot('leader', _cycleReferenceLeader),
      'leader_to_anchor_deload': slot('leader_to_anchor_deload', const {
        'templateId': 'forever_7th_week_protocol',
        'variantId': 'deload_four_day',
        'templateRevision': 1,
        'variantRevision': 1,
      }),
      'anchor': slot('anchor', const {
        'templateId': 'forever_original_531_anchor',
        'variantId': 'standard_531',
        'templateRevision': 1,
        'variantRevision': 1,
      }),
      'training_max_test': slot('training_max_test', const {
        'templateId': 'forever_7th_week_protocol',
        'variantId': 'tm_test_four_day',
        'templateRevision': 1,
        'variantRevision': 1,
      }),
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
  };
}
