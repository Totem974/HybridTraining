import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Beyond main-work families use sourced reusable components', () {
    final document =
        jsonDecode(
              File(
                'catalog_src/beyond/templates/main_variations.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final templates = document['templates']! as List<Object?>;

    expect(
      templates.map((item) => (item! as Map<String, Object?>)['id']),
      containsAll({
        'beyond_pyramid',
        'beyond_first_set_last',
        'beyond_fives_progression',
      }),
    );
    for (final rawTemplate in templates) {
      final template = rawTemplate! as Map<String, Object?>;
      final variants = template['variants']! as List<Object?>;
      expect(
        variants
            .cast<Map<String, Object?>>()
            .map((variant) => variant['id'])
            .toSet(),
        hasLength(variants.length),
      );
      for (final rawVariant in variants) {
        final variant = rawVariant! as Map<String, Object?>;
        expect(variant['phases'], hasLength(3));
        expect(variant['validExample'], isNotEmpty);
        expect(variant.containsKey('componentIds'), isFalse);
      }
    }
  });
}
