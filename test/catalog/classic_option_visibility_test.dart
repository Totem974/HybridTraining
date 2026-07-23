import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = _read('catalog_src/classic/option_schemas.json');
  final schemas = (document['optionSchemas']! as List).cast<Map>();

  Map schema(String id) => schemas.singleWhere((item) => item['id'] == id);
  Map parameter(String schemaId, String parameterId) =>
      (schema(schemaId)['parameters']! as List).cast<Map>().singleWhere(
        (item) => item['id'] == parameterId,
      );

  test(
    'fixed values are retained for the engine but hidden from presentation',
    () {
      for (final item
          in (schema('classic_simplest_strength_options')['parameters']!
                  as List)
              .cast<Map>()) {
        expect(item['allowedValues'], hasLength(1), reason: '${item['id']}');
        expect(item['presentationGroup'], 'hidden', reason: '${item['id']}');
        expect(item['default'], (item['allowedValues']! as List).single);
      }
      final ratio = parameter('classic_531_options', 'training_max_ratio');
      expect(ratio['minimum'], ratio['maximum']);
      expect(ratio['presentationGroup'], 'hidden');
    },
  );

  test('every visible classic option represents a real user choice', () {
    for (final optionSchema in schemas) {
      for (final item
          in (optionSchema['parameters']! as List).cast<Map>().where(
            (parameter) => parameter['presentationGroup'] != 'hidden',
          )) {
        final allowed = (item['allowedValues']! as List);
        final hasRange =
            item['minimum'] is num &&
            item['maximum'] is num &&
            (item['minimum']! as num) < (item['maximum']! as num);
        final isTypedWeight =
            item['type'] == 'weight' && item['default'] is Map;
        expect(
          allowed.length > 1 || hasRange || isTypedWeight,
          isTrue,
          reason: '${optionSchema['id']}.${item['id']}',
        );
      }
    }
  });

  test('Bodyweight matches the observed defaults and bounded controls', () {
    final total = parameter('classic_bodyweight_options', 'total_repetitions');
    expect(total, containsPair('presentationGroup', 'assistance'));
    expect(total['default'], 75);
    expect(total['minimum'], 75);
    expect(total['maximum'], 150);
    expect(total['step'], 5);

    final sets = parameter('classic_bodyweight_options', 'set_count');
    expect(sets['default'], 5);
    expect(sets['minimum'], 1);
    expect(sets['maximum'], 10);
    expect(sets['step'], 1);
  });

  test('classic warm-up and deload use canonical conditional trees', () {
    final warmup = parameter('classic_531_options', 'warmUp.enabled');
    final deload = parameter('classic_531_options', 'deload.enabled');
    expect(warmup['default'], isTrue);
    expect(warmup['allowedValues'], [true, false]);
    expect(deload['default'], isTrue);
    expect(deload['allowedValues'], [true, false]);
    expect(warmup['labelFr'], 'Échauffement');
    expect(deload['labelFr'], 'Deload après le cycle');

    final warmupType = parameter('classic_531_options', 'warmUp.type');
    expect(warmupType['allowedValues'], ['original', 'beyond']);
    expect(
      (warmupType['visibleWhen']! as Map)['parameterId'],
      'warmUp.enabled',
    );

    final skip = parameter('classic_531_options', 'deload.skipWarmUp');
    expect(jsonEncode(skip['visibleWhen']), contains('deload.type'));
    expect(jsonEncode(skip['visibleWhen']), isNot(contains('highIntensity')));
  });
}

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
