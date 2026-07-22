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
    service.initialize(File(catalogPath).readAsStringSync());
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
