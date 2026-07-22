import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final classic = _read('catalog_src/classic/option_schemas.json');
  final extended = _read('catalog_src/classic/extended/option_schemas.json');
  final aliases = _read('catalog_src/classic/extended/template_aliases.json');

  Map schema(Map<String, Object?> document, String id) =>
      (document['optionSchemas']! as List).cast<Map>().singleWhere(
        (item) => item['id'] == id,
      );

  Map option(Map optionSchema, String id) =>
      (optionSchema['parameters']! as List).cast<Map>().singleWhere(
        (item) => item['id'] == id,
      );

  test('Full Body variants own non-overlapping option surfaces', () {
    final original = schema(extended, 'classic_full_body_original_options');
    final updated = schema(extended, 'classic_full_body_updated_options');
    final fullBoring = schema(
      extended,
      'classic_full_body_full_boring_options',
    );

    expect(option(original, 'phase')['allowedValues'], [
      'phase_one',
      'phase_two',
      'phase_three',
    ]);
    expect(
      (updated['parameters']! as List).cast<Map>().map((item) => item['id']),
      isNot(contains('phase')),
    );
    expect(
      (fullBoring['parameters']! as List)
          .cast<Map>()
          .map((item) => item['id']),
      containsAll([
        'squat_set_profile',
        'bench_set_profile',
        'deadlift_set_profile',
      ]),
    );
    expect(
      (fullBoring['parameters']! as List).cast<Map>().map((item) => item['id']),
      isNot(contains('phase')),
    );
  });

  test('legacy Full Body IDs migrate deterministically to phase options', () {
    final entries = (aliases['templateAliases']! as List).cast<Map>();
    expect(entries, hasLength(3));
    for (var index = 0; index < entries.length; index++) {
      final alias = entries[index];
      expect(alias['legacyTemplateId'], 'classic_full_body_phase_${index + 1}');
      expect(alias['legacyVariantId'], 'phase_${index + 1}');
      expect(alias['templateId'], 'classic_full_body');
      expect(alias['variantId'], 'original');
      expect((alias['optionOverrides']! as Map)['phase'], 'phase_${[
        'one',
        'two',
        'three',
      ][index]}');
    }
  });

  test('warm-up option tree is typed and conditionally complete', () {
    final options = schema(classic, 'classic_531_options');
    expect(option(options, 'warmUp.enabled')['default'], isTrue);
    expect(option(options, 'warmUp.type')['allowedValues'], [
      'original',
      'beyond',
    ]);
    for (final id in [
      'warmUp.bases.lowerBody',
      'warmUp.bases.upperBody',
    ]) {
      final base = option(options, id);
      expect(base['type'], 'weight');
      expect((base['default']! as Map).keys.toSet(), {'centiUnits', 'unit'});
      expect(_conditionReferences(base['visibleWhen']), {
        'warmUp.enabled',
        'warmUp.type',
      });
    }
  });

  test('Joker exposes off plus all six source ceilings', () {
    final options = schema(classic, 'classic_531_options');
    expect(option(options, 'joker.enabled')['default'], isFalse);
    expect(option(options, 'joker.ceilingBasisPoints')['allowedValues'], [
      500,
      1000,
      1500,
      2000,
      2500,
      3000,
    ]);
    expect(
      _conditionReferences(
        option(options, 'joker.ceilingBasisPoints')['visibleWhen'],
      ),
      {
      'joker.enabled',
      },
    );
  });

  test('deload options encode off, six types and skip exclusion', () {
    final options = schema(classic, 'classic_531_options');
    expect(option(options, 'deload.enabled')['default'], isTrue);
    expect(option(options, 'deload.type')['allowedValues'], [
      'deload1',
      'deload2',
      'deload3',
      'deload4',
      'deload5',
      'highIntensity',
    ]);
    final skip = option(options, 'deload.skipWarmUp');
    expect(skip['default'], isFalse);
    expect(_conditionReferences(skip['visibleWhen']), {
      'deload.enabled',
      'deload.type',
    });
    expect(jsonEncode(skip['visibleWhen']), isNot(contains('highIntensity')));
  });
}

Set<Object?> _conditionReferences(Object? value) {
  if (value is Map) {
    return {
      if (value['parameterId'] != null) value['parameterId'],
      for (final child in value.values) ..._conditionReferences(child),
    };
  }
  if (value is List) {
    return {for (final child in value) ..._conditionReferences(child)};
  }
  return {};
}

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
