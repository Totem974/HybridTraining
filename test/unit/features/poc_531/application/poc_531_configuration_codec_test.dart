import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/application/poc_531_configuration_codec.dart';

void main() {
  const codec = Poc531ConfigurationCodec();

  test('v3 encoding is deterministic and round-trips', () {
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
      '{"common":{"lifts":{"Press":60.0,"Squat":120.0},"unit":"kg"},'
      '"cycle":{"templateId":"boringButBig","variantId":"fiveByTen"},'
      '"mode":"cycle","schemaVersion":3}',
    );
  });

  test('migrates a v2 classic calculator payload', () {
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
    expect(migrated.common['days'], 3);
    expect(migrated.cycle, containsPair('templateId', 'forBeginners'));
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

    expect(migrated.mode, 'forever');
    expect(
      migrated.forever?['programId'],
      Poc531ConfigurationCodec.beginnerPrepSchoolId,
    );
    expect(migrated.forever?['planKind'], 'standaloneProgram');
    expect(migrated.forever?['sourceAlias'], 'FV-141');
  });

  test('migrates both FV-236 aliases as the same Forever macrocycle', () {
    for (final id in const ['FV-236', 'forever-original-531-fsl-2l1a-v1']) {
      final migrated = codec.decodeMap({
        'schemaVersion': 2,
        'mode': 'forever',
        'foreverTemplateId': id,
        'unit': 'kg',
        'days': 4,
      });

      expect(migrated.mode, 'forever');
      expect(
        migrated.forever?['programId'],
        Poc531ConfigurationCodec.foreverOriginalFslId,
      );
      expect(migrated.forever?['planKind'], 'macrocycle');
      expect(migrated.forever?['recipeId'], 'forever-2l1a');
      expect(migrated.forever?['nodes'], hasLength(5));
    }
  });

  test('rejects an unknown schema version', () {
    expect(
      () => codec.decodeMap(const {'schemaVersion': 99}),
      throwsA(isA<FormatException>()),
    );
  });
}
