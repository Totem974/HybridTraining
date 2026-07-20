import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';

void main() {
  const core = DomainPoc531GeneratorCore();

  test(
    'v4 generation consumes every finite future macrocycle in order',
    () async {
      final result = await core.generate(
        _seriesConfiguration([
          _macrocycle('M1', intent: 'active', status: 'active'),
          _macrocycle('M2', intent: 'projected', status: 'planned'),
        ]),
      );

      final export = jsonDecode(result.exportJson) as Map<String, Object?>;
      final macrocycles = export['macrocycles']! as List;
      expect(export['schemaVersion'], 4);
      expect(export['seriesId'], 'series-test');
      expect(macrocycles.map((value) => (value as Map)['instanceId']), [
        'M1',
        'M2',
      ]);
      expect((macrocycles[1] as Map)['intent'], 'projected');
      final firstGenerated =
          (macrocycles.first as Map)['generatedProgram'] as Map;
      final firstPayload = firstGenerated['payload'] as Map;
      final compiledBlockIds = (firstPayload['blocks'] as List)
          .map((block) => (block as Map)['id'])
          .toList();
      expect(compiledBlockIds, ['M1-C1', 'M1-C2', 'M1-P1', 'M1-C3', 'M1-P2']);
      expect(((firstPayload['blocks'] as List)[3] as Map)['role'], 'anchor');
      expect(result.blocks.first.name, startsWith('M1 ·'));
      expect(
        result.blocks.any((block) => block.name.startsWith('M2 ·')),
        isTrue,
      );
    },
  );

  test('v4 generation never regenerates completed history', () async {
    final result = await core.generate(
      _seriesConfiguration([
        _macrocycle('M1', intent: 'active', status: 'completed'),
        _macrocycle('M2', intent: 'projected', status: 'planned'),
      ]),
    );
    final export = jsonDecode(result.exportJson) as Map<String, Object?>;
    final macrocycles = export['macrocycles']! as List;
    expect(macrocycles, hasLength(2));
    expect((macrocycles.first as Map)['instanceId'], 'M1');
    expect((macrocycles.first as Map).containsKey('generatedProgram'), isFalse);
    expect((macrocycles.last as Map)['instanceId'], 'M2');
  });

  test('planned M2 starts after the complete immutable M1 timeline', () async {
    final configuration = _seriesConfiguration([
      _macrocycle('M1', intent: 'active', status: 'completed'),
      _macrocycle('M2', intent: 'projected', status: 'planned'),
    ]);
    (configuration['common'] as Map<String, Object?>)['startDate'] =
        '2027-02-01T00:00:00.000Z';

    final result = await core.generate(configuration);
    final export = jsonDecode(result.exportJson) as Map<String, Object?>;
    final generatedM2 =
        ((export['macrocycles'] as List).last as Map)['generatedProgram']
            as Map;

    expect(jsonEncode(generatedM2), contains('2027-04-19'));
  });

  test(
    'a fully historical terminated series exports without generation',
    () async {
      final configuration = _seriesConfiguration([
        _macrocycle('M1', intent: 'active', status: 'completed'),
      ]);
      final forever = configuration['forever'] as Map<String, Object?>;
      final series = forever['series'] as Map<String, Object?>;
      series['terminated'] = true;

      final result = await core.generate(configuration);
      final export = jsonDecode(result.exportJson) as Map<String, Object?>;

      expect(result.blocks, isEmpty);
      expect(export['terminated'], isTrue);
      expect((export['macrocycles'] as List), hasLength(1));
    },
  );

  test(
    'completed macrocycle is exported without losing any nested field',
    () async {
      final completed = _macrocycle('M1', intent: 'active', status: 'completed')
        ..['unknownFutureField'] = {
          'snapshot': [
            1,
            {'opaque': true},
          ],
        }
        ..['generatedProgram'] = {'immutable': 'snapshot'};
      final result = await core.generate(
        _seriesConfiguration([
          completed,
          _macrocycle('M2', intent: 'projected', status: 'planned'),
        ]),
      );
      final export = jsonDecode(result.exportJson) as Map<String, Object?>;
      expect((export['macrocycles'] as List).first, completed);
    },
  );

  test('uses 2027 start date and macrocycle-specific Training Maxes', () async {
    final second = _macrocycle('M2', intent: 'projected', status: 'planned');
    second['trainingMaxStates'] = {
      'squat': {'state': 'projected', 'trainingMax': 110},
    };
    final configuration = _seriesConfiguration([
      _macrocycle('M1', intent: 'active', status: 'active'),
      second,
    ]);
    (configuration['common'] as Map<String, Object?>)['startDate'] =
        '2027-02-01T00:00:00.000Z';
    final result = await core.generate(configuration);
    final export = jsonDecode(result.exportJson) as Map<String, Object?>;
    final encoded = jsonEncode(export['macrocycles']);
    expect(encoded, contains('2027-02-01'));
    expect(encoded, contains('110'));
  });

  test('refuses invalid intent, status, role, revision and protocol', () async {
    Future<void> rejected(Map<String, Object?> macrocycle) async {
      await expectLater(
        core.generate(_seriesConfiguration([macrocycle])),
        throwsA(anyOf(isA<FormatException>(), isA<Exception>())),
      );
    }

    await rejected(_macrocycle('M1', intent: 'invalid', status: 'active'));
    await rejected(_macrocycle('M1', intent: 'active', status: 'invalid'));
    final wrongRole = _macrocycle('M1', intent: 'active', status: 'active');
    ((wrongRole['slots'] as List).first as Map)['role'] = 'anchor';
    await rejected(wrongRole);
    final wrongRevision = _macrocycle('M1', intent: 'active', status: 'active');
    ((wrongRevision['slots'] as List).first as Map)['cycleTemplateRevisionId'] =
        'unknown-v1';
    await rejected(wrongRevision);
    final missingProtocol = _macrocycle(
      'M1',
      intent: 'active',
      status: 'active',
    );
    (missingProtocol['protocols'] as List).removeLast();
    await rejected(missingProtocol);
  });

  test('v4 generation refuses a non executable recipe', () async {
    expect(
      () => core.generate(
        _seriesConfiguration([
          _macrocycle(
            'M1',
            intent: 'active',
            status: 'active',
            recipeId: 'forever-2l2a-v1',
          ),
        ]),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, Object?> _seriesConfiguration(
  List<Map<String, Object?>> macrocycles,
) => {
  'schemaVersion': 4,
  'mode': 'forever',
  'common': {
    'days': 4,
    'unit': 'kg',
    'trainingMaxRatio': 90,
    'lifts': {
      'Press': 60.0,
      'Bench Press': 90.0,
      'Squat': 120.0,
      'Deadlift': 150.0,
    },
  },
  'forever': {
    'series': {
      'id': 'series-test',
      'terminated': false,
      'macrocycles': macrocycles,
    },
  },
};

Map<String, Object?> _macrocycle(
  String id, {
  required String intent,
  required String status,
  String recipeId = 'forever-2l1a-v2',
}) => {
  'instanceId': id,
  'intent': intent,
  'status': status,
  'recipeId': recipeId,
  'slots': [
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
  'protocols': [
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
  'trainingMaxStates': <String, Object?>{},
};
