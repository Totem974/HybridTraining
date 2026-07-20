import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/application/poc_531_configuration_codec.dart';

void main() {
  const codec = Poc531ConfigurationCodec();

  test('v4 encoding is deterministic and round-trips byte exactly', () {
    final configuration = Poc531Configuration.cycle(
      common: const {
        'unit': 'kg',
        'lifts': {'Squat': 120.0, 'Press': 60.0},
      },
      cycle: const {'variantId': 'fiveByTen', 'templateId': 'boringButBig'},
    );
    final encoded = codec.encode(configuration);
    expect(codec.encode(codec.decode(encoded)), encoded);
    expect(
      encoded,
      '{"common":{"lifts":{"Press":60.0,"Squat":120.0},"unit":"kg"},"cycle":{"templateId":"boringButBig","variantId":"fiveByTen"},"mode":"cycle","schemaVersion":4}',
    );
  });

  test('migrates a v2 classic calculator payload through v3 to v4', () {
    final migrated = codec.decodeMap(const {
      'schemaVersion': 2,
      'mode': 'classic',
      'unit': 'lb',
      'days': 3,
      'templateId': 'forBeginners',
      'variantId': 'standard',
      'beginnerIntermediate': true,
      'lifts': {'Squat': 300.0},
    });
    expect(migrated.mode, 'cycle');
    expect(migrated.common['unit'], 'lb');
    expect(migrated.cycle, containsPair('beginnerIntermediate', true));
  });

  test('restores Beginner Prep School as a standalone Forever program', () {
    final migrated = codec.decodeMap(const {
      'schemaVersion': 2,
      'mode': 'forever',
      'foreverTemplateId': 'FV-141',
      'unit': 'kg',
      'days': 3,
    });
    expect(
      migrated.forever?['standaloneProgramId'],
      Poc531ConfigurationCodec.beginnerPrepSchoolId,
    );
    expect(migrated.forever, isNot(contains('series')));
    expect(migrated.forever?['sourceAlias'], 'FV-141');
  });

  test('migrates historical FV-236 aliases to an M1 2L/1A series', () {
    for (final id in const ['FV-236', 'forever-original-531-fsl-2l1a-v1']) {
      final migrated = codec.decodeMap({
        'schemaVersion': 2,
        'mode': 'forever',
        'foreverTemplateId': id,
        'unit': 'kg',
        'days': 4,
      });
      final series = migrated.forever?['series'] as Map;
      final macrocycle = (series['macrocycles'] as List).single as Map;
      expect(macrocycle['instanceId'], 'M1');
      expect(macrocycle['recipeId'], 'forever-2l1a-v2');
      expect(macrocycle['slots'], hasLength(3));
      expect(macrocycle['protocols'], hasLength(2));
      expect(macrocycle['trainingMaxStates'], isEmpty);
    }
  });

  test('migrates v3 node aliases to slots and protocols', () {
    final migrated = codec.decodeMap(const {
      'schemaVersion': 3,
      'mode': 'forever',
      'common': {'unit': 'kg'},
      'forever': {
        'programId': 'forever-original-531-fsl-2l1a-v1',
        'planKind': 'macrocycle',
        'nodes': [
          {'nodeId': 'C1', 'kind': 'cycle'},
          {'nodeId': 'C2', 'kind': 'cycle'},
          {'nodeId': 'P1', 'kind': 'protocol'},
          {'nodeId': 'C3', 'kind': 'cycle'},
          {'nodeId': 'P2', 'kind': 'protocol'},
        ],
      },
    });
    final macrocycle =
        (((migrated.forever!['series'] as Map)['macrocycles'] as List).single
            as Map);
    expect(
      (macrocycle['slots'] as List).map((v) => (v as Map)['sourceNodeId']),
      ['C1', 'C2', 'C3'],
    );
    expect(
      (macrocycle['protocols'] as List).map((v) => (v as Map)['sourceNodeId']),
      ['P1', 'P2'],
    );
  });

  test('round-trips finite series and per-lift TM states', () {
    final configuration = Poc531Configuration.forever(
      common: const {'unit': 'kg'},
      forever: const {
        'series': {
          'id': 'series-42',
          'terminated': false,
          'macrocycles': [
            {
              'instanceId': 'M1',
              'intent': 'active',
              'status': 'active',
              'recipeId': 'forever-2l1a-v2',
              'slots': [
                {
                  'slotId': 'leader-1',
                  'role': 'leader',
                  'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
                },
              ],
              'protocols': [
                {
                  'boundaryId': 'leaders-to-anchor',
                  'protocolTemplateRevisionId':
                      'forever-seventh-week-deload-v1',
                  'required': true,
                },
              ],
              'trainingMaxStates': {'squat': 'confirmed'},
            },
          ],
        },
      },
    );
    final encoded = codec.encode(configuration);
    expect(codec.encode(codec.decode(encoded)), encoded);
    expect(encoded, contains('"squat":"confirmed"'));
  });

  test('requires standaloneProgramId xor series', () {
    expect(
      () => codec.decodeMap(const {
        'schemaVersion': 4,
        'mode': 'forever',
        'common': {},
        'forever': {
          'standaloneProgramId': 'forever-beginner-prep-school-v1',
          'series': {'macrocycles': []},
        },
      }),
      throwsFormatException,
    );
  });

  test('rejects recipes awaiting source review', () {
    for (final recipeId in const ['forever-2l2a-v1', 'forever-3l2a-v1']) {
      expect(
        () => codec.decodeMap({
          'schemaVersion': 4,
          'mode': 'forever',
          'common': {},
          'forever': {
            'series': {
              'macrocycles': [
                {
                  'recipeId': recipeId,
                  'slots': [],
                  'protocols': [],
                  'trainingMaxStates': {},
                },
              ],
            },
          },
        }),
        throwsFormatException,
      );
    }
  });

  test('rejects an unknown schema version', () {
    expect(
      () => codec.decodeMap(const {'schemaVersion': 99}),
      throwsFormatException,
    );
  });
}
