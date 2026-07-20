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
      forever: _validForever(),
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
          'forever': _validForever(recipeId: recipeId),
        }),
        throwsFormatException,
      );
    }
  });

  test('preserves unknown historical fields through canonical round-trip', () {
    final forever = _validForever();
    forever['legacyEnvelope'] = {'z': 1, 'a': true};
    final series = forever['series']! as Map<String, Object?>;
    series['legacySeriesFlag'] = 'kept';
    final macrocycle =
        (series['macrocycles']! as List).single as Map<String, Object?>;
    macrocycle['legacyNodeSnapshot'] = [
      {'nodeId': 'C1'},
    ];

    final decoded = codec.decodeMap({
      'schemaVersion': 4,
      'mode': 'forever',
      'common': {'legacyCommon': 7},
      'forever': forever,
    });
    final encoded = codec.encode(decoded);
    final restored = codec.decode(encoded);
    expect(restored.common['legacyCommon'], 7);
    expect(restored.forever?['legacyEnvelope'], {'z': 1, 'a': true});
    final restoredSeries = restored.forever?['series'] as Map;
    expect(restoredSeries['legacySeriesFlag'], 'kept');
    expect(
      ((restoredSeries['macrocycles'] as List).single
          as Map)['legacyNodeSnapshot'],
      [
        {'nodeId': 'C1'},
      ],
    );
  });

  test('rejects invalid intents, statuses and Training Max states', () {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (macrocycle) => macrocycle['intent'] = 'infinite',
      (macrocycle) => macrocycle['status'] = 'running',
      (macrocycle) => macrocycle['trainingMaxStates'] = {'squat': 'raised'},
      (macrocycle) =>
          macrocycle['trainingMaxStates'] = <String, Object?>{'squat': 1},
    ]) {
      final payload = _validPayload();
      mutation(_firstMacrocycle(payload));
      expect(() => codec.decodeMap(payload), throwsFormatException);
    }
  });

  test('rejects duplicate IDs and active macrocycles after projected ones', () {
    final duplicate = _validPayload();
    final duplicateSeries = _series(duplicate);
    duplicateSeries['macrocycles'] = [
      _validMacrocycle(),
      _validMacrocycle(intent: 'projected', status: 'planned'),
    ];
    expect(() => codec.decodeMap(duplicate), throwsFormatException);

    final wrongOrder = _validPayload();
    _series(wrongOrder)['macrocycles'] = [
      _validMacrocycle(
        instanceId: 'M1',
        intent: 'projected',
        status: 'planned',
      ),
      _validMacrocycle(instanceId: 'M2'),
    ];
    expect(() => codec.decodeMap(wrongOrder), throwsFormatException);
  });

  test('a terminated series cannot retain active or projected future work', () {
    for (final macrocycle in [
      _validMacrocycle(),
      _validMacrocycle(intent: 'projected', status: 'planned'),
    ]) {
      final payload = _validPayload();
      final series = _series(payload);
      series['terminated'] = true;
      series['macrocycles'] = [macrocycle];
      expect(() => codec.decodeMap(payload), throwsFormatException);
    }
  });

  test('enforces the exact sourced slots for the 2L/1A recipe', () {
    for (final mutation in <void Function(List)>[
      (slots) => slots.removeLast(),
      (slots) => (slots[0] as Map)['slotId'] = 'leader-x',
      (slots) => (slots[1] as Map)['role'] = 'anchor',
      (slots) => (slots[2] as Map)['cycleTemplateRevisionId'] =
          'forever-original-fsl-leader-v1',
      (slots) => slots[0] = <Object?, Object?>{
        ...(slots[0] as Map),
        'cycleTemplateRevisionId': 42,
      },
    ]) {
      final payload = _validPayload();
      mutation(_firstMacrocycle(payload)['slots'] as List);
      expect(() => codec.decodeMap(payload), throwsFormatException);
    }
  });

  test('mandatory protocols cannot be removed, replaced or made optional', () {
    for (final mutation in <void Function(List)>[
      (protocols) => protocols.removeLast(),
      (protocols) => (protocols[0] as Map)['required'] = false,
      (protocols) => (protocols[0] as Map)['boundaryId'] = 'other',
      (protocols) => (protocols[1] as Map)['protocolTemplateRevisionId'] =
          'forever-seventh-week-deload-v1',
    ]) {
      final payload = _validPayload();
      mutation(_firstMacrocycle(payload)['protocols'] as List);
      expect(() => codec.decodeMap(payload), throwsFormatException);
    }
  });

  test('rejects malformed v4 collection and scalar types', () {
    final cases = <Map<String, Object?>>[];
    final badTerminated = _validPayload();
    _series(badTerminated)['terminated'] = 'false';
    cases.add(badTerminated);
    final badMacrocycles = _validPayload();
    _series(badMacrocycles)['macrocycles'] = <String, Object?>{};
    cases.add(badMacrocycles);
    final badSlots = _validPayload();
    _firstMacrocycle(badSlots)['slots'] = 'slots';
    cases.add(badSlots);
    final badTm = _validPayload();
    _firstMacrocycle(badTm)['trainingMaxStates'] = [];
    cases.add(badTm);
    for (final payload in cases) {
      expect(() => codec.decodeMap(payload), throwsFormatException);
    }
  });

  test('rejects an unknown schema version', () {
    expect(
      () => codec.decodeMap(const {'schemaVersion': 99}),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _validPayload() => {
  'schemaVersion': 4,
  'mode': 'forever',
  'common': <String, Object?>{},
  'forever': _validForever(),
};

Map<String, Object?> _validForever({String recipeId = 'forever-2l1a-v2'}) => {
  'series': <String, Object?>{
    'id': 'series-42',
    'terminated': false,
    'macrocycles': <Object?>[_validMacrocycle(recipeId: recipeId)],
  },
};

Map<String, Object?> _validMacrocycle({
  String instanceId = 'M1',
  String intent = 'active',
  String status = 'active',
  String recipeId = 'forever-2l1a-v2',
}) => {
  'instanceId': instanceId,
  'intent': intent,
  'status': status,
  'recipeId': recipeId,
  'slots': <Object?>[
    {
      'slotId': 'leader-1',
      'role': 'leader',
      'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
    },
    {
      'slotId': 'leader-2',
      'role': 'leader',
      'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
    },
    {
      'slotId': 'anchor-1',
      'role': 'anchor',
      'cycleTemplateRevisionId': 'forever-original-pr-set-anchor-v1',
    },
  ],
  'protocols': <Object?>[
    {
      'boundaryId': 'leaders-to-anchor',
      'protocolTemplateRevisionId': 'forever-seventh-week-deload-v1',
      'required': true,
    },
    {
      'boundaryId': 'macrocycle-end',
      'protocolTemplateRevisionId': 'forever-seventh-week-tm-test-v1',
      'required': true,
    },
  ],
  'trainingMaxStates': <String, Object?>{'squat': 'confirmed'},
};

Map<String, Object?> _series(Map<String, Object?> payload) =>
    ((payload['forever'] as Map)['series'] as Map).cast<String, Object?>();

Map<String, Object?> _firstMacrocycle(Map<String, Object?> payload) =>
    ((_series(payload)['macrocycles'] as List).first as Map)
        .cast<String, Object?>();
