import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_codec.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_models.dart';

void main() {
  late Map<String, Object?> seed;

  setUp(() {
    seed =
        jsonDecode(
              File('assets/catalog/standard_531_v1.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  test('decodes the canonical Standard 5/3/1 seed', () {
    final catalog = const CatalogCodec().decode(jsonEncode(seed));
    final variant = catalog.templates.single.variants.single;
    expect(catalog.catalogVersion, 1);
    expect(catalog.movements, hasLength(4));
    expect(variant.sessionMovementIds, [
      'overhead_press',
      'deadlift',
      'bench_press',
      'squat',
    ]);
    expect(variant.weeks, hasLength(4));
    expect(variant.weeks.last.blocks.single.role, 'deload');
  });

  test('rejects an unsupported schema version', () {
    seed['schemaVersion'] = 2;
    expect(
      () => const CatalogCodec().decode(jsonEncode(seed)),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('rejects unknown payload keys', () {
    final templates = seed['templates']! as List<Object?>;
    final template = templates.single as Map<String, Object?>;
    final variants = template['variants']! as List<Object?>;
    final variant = variants.single as Map<String, Object?>;
    final weeks = variant['weeks']! as List<Object?>;
    final week = weeks.first as Map<String, Object?>;
    final blocks = week['blocks']! as List<Object?>;
    final block = blocks.first as Map<String, Object?>;
    final sets = block['sets']! as List<Object?>;
    final set = sets.first as Map<String, Object?>;
    final load = set['load']! as Map<String, Object?>;
    load['surprise'] = true;
    expect(
      () => const CatalogCodec().decode(jsonEncode(seed)),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('rejects unknown primitive types', () {
    final templates = seed['templates']! as List<Object?>;
    final variant =
        ((templates.single as Map<String, Object?>)['variants']!
                    as List<Object?>)
                .single
            as Map<String, Object?>;
    final week =
        (variant['weeks']! as List<Object?>).first as Map<String, Object?>;
    final block =
        (week['blocks']! as List<Object?>).first as Map<String, Object?>;
    final set = (block['sets']! as List<Object?>).first as Map<String, Object?>;
    (set['repetitions']! as Map<String, Object?>)['type'] = 'mystery';
    expect(
      () => const CatalogCodec().decode(jsonEncode(seed)),
      throwsA(isA<CatalogFormatException>()),
    );
  });
}
