import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every Beyond template document declares its generation and provenance',
    () {
      final inventory =
          jsonDecode(
                File('catalog_src/beyond/inventory.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final knownRuleIds = (inventory['entries']! as List<Object?>)
          .map((entry) => (entry! as Map<String, Object?>)['id'])
          .toSet();
      final templateFiles = Directory('catalog_src/beyond/templates')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'));

      expect(templateFiles, isNotEmpty);
      for (final file in templateFiles) {
        final document =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        final generation = document['generation']! as Map<String, Object?>;
        expect(generation['id'], 'beyond', reason: file.path);

        for (final rawTemplate in document['templates']! as List<Object?>) {
          final template = rawTemplate! as Map<String, Object?>;
          expect(
            template['surface'],
            'cyclePublic',
            reason: '${file.path}: ${template['id']}',
          );
          final templateRuleIds = template['sourceRuleIds']! as List<Object?>;
          expect(
            templateRuleIds,
            isNotEmpty,
            reason: '${file.path}: ${template['id']}',
          );
          expect(
            templateRuleIds.every(knownRuleIds.contains),
            isTrue,
            reason: '${file.path}: ${template['id']}',
          );

          for (final rawVariant in template['variants']! as List<Object?>) {
            final variant = rawVariant! as Map<String, Object?>;
            final variantRuleIds = variant['sourceRuleIds']! as List<Object?>;
            expect(
              variantRuleIds,
              isNotEmpty,
              reason: '${template['id']}: ${variant['id']}',
            );
            expect(
              variantRuleIds.every(knownRuleIds.contains),
              isTrue,
              reason: '${template['id']}: ${variant['id']}',
            );
          }
        }
      }
    },
  );
}
