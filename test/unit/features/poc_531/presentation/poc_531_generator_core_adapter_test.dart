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
    expect((macrocycles.first as Map)['preserved'], isTrue);
    expect((macrocycles.first as Map).containsKey('generatedProgram'), isFalse);
    expect((macrocycles.last as Map)['instanceId'], 'M2');
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
    {'slotId': 'leader-1'},
    {'slotId': 'leader-2'},
    {'slotId': 'anchor-1'},
  ],
  'protocols': [
    {'protocolTemplateRevisionId': 'forever-seventh-week-deload-v1'},
    {'protocolTemplateRevisionId': 'forever-seventh-week-tm-test-v1'},
  ],
  'trainingMaxStates': <String, Object?>{},
};
