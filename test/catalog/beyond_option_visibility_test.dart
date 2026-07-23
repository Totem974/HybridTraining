import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final schemas = <Map<String, Object?>>[
    ..._schemas('catalog_src/beyond/option_schemas/bbb.v1.json'),
    ..._schemas('catalog_src/beyond/option_schemas/main_variations.v1.json'),
    ..._schemas('catalog_src/powerlifting/option_schemas.json'),
  ];

  test('fixed Beyond and Powerlifting values stay structural and hidden', () {
    final fixed = <String>{
      'beyond_bbb_same_lift_options.bbb_percentage',
      'beyond_bbb_same_lift_options.include_deload',
      'beyond_main_variation_options.include_deload',
      'powerlifting_classic_531_options.training_max_ratio',
      'powerlifting_classic_531_options.include_deload',
    };

    for (final schema in schemas) {
      for (final parameter in _parameters(schema)) {
        final key = '${schema['id']}.${parameter['id']}';
        if (!fixed.contains(key)) continue;
        expect(parameter['presentationGroup'], 'hidden', reason: key);
        final allowed = (parameter['allowedValues']! as List<Object?>);
        final minimum = parameter['minimum'];
        final maximum = parameter['maximum'];
        expect(
          allowed.length <= 1 || minimum == maximum,
          isTrue,
          reason: '$key must remain structural, not a fake choice',
        );
      }
    }
  });

  test('every visible option represents more than one executable value', () {
    for (final schema in schemas) {
      for (final parameter in _parameters(
        schema,
      ).where((item) => item['presentationGroup'] != 'hidden')) {
        final allowed = (parameter['allowedValues']! as List<Object?>);
        final minimum = parameter['minimum'];
        final maximum = parameter['maximum'];
        final hasRange = minimum is num && maximum is num && minimum < maximum;
        expect(
          allowed.length > 1 || hasRange,
          isTrue,
          reason: '${schema['id']}.${parameter['id']}',
        );
      }
    }
  });

  test('uncompiled transverse recipes are not advertised as controls', () {
    const canonicalPrefixes = ['warmUp.', 'joker.', 'deload.'];
    for (final schema in schemas) {
      for (final parameter in _parameters(schema)) {
        final id = parameter['id']! as String;
        if (!canonicalPrefixes.any(id.startsWith)) continue;
        fail('${schema['id']} exposes $id without a catalog recipe');
      }
    }
  });
}

List<Map<String, Object?>> _schemas(String path) =>
    (_read(path)['optionSchemas']! as List<Object?>)
        .cast<Map<String, Object?>>();

Iterable<Map<String, Object?>> _parameters(Map<String, Object?> schema) =>
    (schema['parameters']! as List<Object?>).cast<Map<String, Object?>>();

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
