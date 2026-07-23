import 'dart:convert';

import 'package:test/test.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

void main() {
  const codec = CycleConfigurationCodec();

  test('projects v1 configuration without template-specific branching', () {
    final request = codec.toCycleRequest(
      _configuration(),
      catalogVersion: 42,
      catalogHash: 'catalog-hash',
    );

    expect(request['cycleId'], 'cycle-classic_full_body-original-2026-07-27');
    expect(request['templateId'], 'classic_full_body');
    expect(request['variantId'], 'original');
    expect(request['scheduleId'], 'classic_full_body_three_day');
    expect(request['trainingDays'], [1, 3, 5]);
    expect(request['maxInputs'], {
      'back_squat': {
        'type': 'repMax',
        'weight': {'centiUnits': 12500, 'unit': 'kg'},
        'repetitions': 5,
        'formula': 'epley',
      },
    });
    expect(request['options'], {
      'fullBody': {'profile': 'original', 'phase': 'phase_two'},
      'warmUp': {'enabled': true, 'type': 'original'},
      'joker': {'enabled': true, 'ceilingBasisPoints': 1000},
      'deload': {'enabled': true, 'type': 'deload3', 'skipWarmUp': true},
    });
    expect(request['includeDeload'], true);
    expect(request['barProfile'], {
      'weight': {'centiUnits': 2000, 'unit': 'kg'},
      'platesPerSide': [
        {'centiUnits': 2000, 'unit': 'kg'},
        {'centiUnits': 125, 'unit': 'kg'},
      ],
    });
    expect(request['programTitle'], 'Mon cycle');
    expect(request['showPlating'], true);
  });

  test('projection is JSON round-trip stable', () {
    final first = codec.toCycleRequest(
      _configuration(),
      catalogVersion: 42,
      catalogHash: 'catalog-hash',
    );
    final second = codec.toCycleRequest(
      (jsonDecode(jsonEncode(_configuration())) as Map).cast<String, Object?>(),
      catalogVersion: 42,
      catalogHash: 'catalog-hash',
    );
    expect(second, first);
  });

  test('projects onePlusSet as a weight-only max input', () {
    final configuration = _configuration();
    configuration['maxes'] = {
      'mode': 'onePlusSet',
      'globalTrainingMaxRatioBasisPoints': 5000,
      'values': {
        'back_squat': {
          'weight': {'centiUnits': 9500, 'unit': 'kg'},
        },
      },
    };

    final request = codec.toCycleRequest(
      configuration,
      catalogVersion: 42,
      catalogHash: 'catalog-hash',
    );

    expect(request['maxInputs'], {
      'back_squat': {
        'type': 'onePlusSet',
        'weight': {'centiUnits': 9500, 'unit': 'kg'},
      },
    });
    expect(request['globalTrainingMaxRatioBasisPoints'], 5000);
  });

  test('rejects an unknown onePlusSet value key with its path', () {
    final configuration = _configuration();
    configuration['maxes'] = {
      'mode': 'onePlusSet',
      'globalTrainingMaxRatioBasisPoints': 9000,
      'values': {
        'back_squat': {
          'weight': {'centiUnits': 9500, 'unit': 'kg'},
          'repetitions': 1,
        },
      },
    };

    expect(
      () => codec.toCycleRequest(
        configuration,
        catalogVersion: 42,
        catalogHash: 'catalog-hash',
      ),
      throwsA(
        isA<CycleConfigurationFormatException>()
            .having((error) => error.code, 'code', 'UNKNOWN_KEY')
            .having(
              (error) => error.path,
              'path',
              r'$.maxes.values.back_squat.repetitions',
            ),
      ),
    );
  });

  test('rejects an unknown key with a structured path', () {
    final configuration = _configuration()..['unexpected'] = true;
    expect(
      () => codec.toCycleRequest(
        configuration,
        catalogVersion: 42,
        catalogHash: 'catalog-hash',
      ),
      throwsA(
        isA<CycleConfigurationFormatException>()
            .having((error) => error.code, 'code', 'UNKNOWN_KEY')
            .having((error) => error.path, 'path', r'$.unexpected')
            .having(
              (error) => error.toIssue()['severity'],
              'severity',
              'error',
            ),
      ),
    );
  });

  test('rejects unsupported versions and stale catalog identities', () {
    expect(
      () => codec.toCycleRequest(
        {..._configuration(), 'configurationVersion': 2},
        catalogVersion: 42,
        catalogHash: 'catalog-hash',
      ),
      throwsA(
        isA<CycleConfigurationFormatException>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_CONFIGURATION_VERSION',
        ),
      ),
    );
    expect(
      () => codec.toCycleRequest(
        {..._configuration(), 'catalogHash': 'stale'},
        catalogVersion: 42,
        catalogHash: 'catalog-hash',
      ),
      throwsA(
        isA<CycleConfigurationFormatException>()
            .having((error) => error.code, 'code', 'CATALOG_IDENTITY_MISMATCH')
            .having((error) => error.path, 'path', r'$'),
      ),
    );
  });

  test('requires inline equipment until a catalog profile resolver exists', () {
    final configuration = _configuration();
    configuration['equipment'] = {'unit': 'kg', 'barProfileId': 'default_kg'};
    expect(
      () => codec.toCycleRequest(
        configuration,
        catalogVersion: 42,
        catalogHash: 'catalog-hash',
      ),
      throwsA(
        isA<CycleConfigurationFormatException>()
            .having(
              (error) => error.code,
              'code',
              'BAR_PROFILE_RESOLUTION_REQUIRED',
            )
            .having((error) => error.path, 'path', r'$.equipment.barProfileId'),
      ),
    );
  });
}

Map<String, Object?> _configuration() => {
  'format': 'hybrid-training-cycle',
  'configurationVersion': 1,
  'catalogVersion': 42,
  'catalogHash': 'catalog-hash',
  'template': {
    'id': 'classic_full_body',
    'variantId': 'original',
    'options': {
      'fullBody': {'profile': 'original', 'phase': 'phase_two'},
    },
  },
  'commonOptions': {
    'warmUp': {'enabled': true, 'type': 'original'},
    'joker': {'enabled': true, 'ceilingBasisPoints': 1000},
    'deload': {'enabled': true, 'type': 'deload3', 'skipWarmUp': true},
  },
  'maxes': {
    'mode': 'repMax',
    'globalTrainingMaxRatioBasisPoints': 8500,
    'values': {
      'back_squat': {
        'weight': {'centiUnits': 12500, 'unit': 'kg'},
        'repetitions': 5,
        'formula': 'epley',
      },
    },
    'ratiosByMovement': {'back_squat': 9000},
  },
  'schedule': {
    'id': 'classic_full_body_three_day',
    'startDate': '2026-07-27T00:00:00.000Z',
    'sessionOrder': ['monday', 'wednesday', 'friday'],
    'trainingDays': [1, 3, 5],
  },
  'equipment': {
    'unit': 'kg',
    'bar': {
      'weight': {'centiUnits': 2000, 'unit': 'kg'},
      'platesPerSide': [
        {'centiUnits': 2000, 'unit': 'kg'},
        {'centiUnits': 125, 'unit': 'kg'},
      ],
    },
  },
  'output': {'title': 'Mon cycle', 'showPlating': true},
};
