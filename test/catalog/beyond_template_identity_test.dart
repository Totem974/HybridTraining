import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final beyondTemplates = <Map<String, Object?>>[
    ..._templates('catalog_src/beyond/templates/bbb.v1.json'),
    ..._templates('catalog_src/beyond/templates/main_variations.v1.json'),
  ];
  final powerliftingTemplates =
      _templates('catalog_src/powerlifting/templates.json');

  test('public template IDs and labels are unique and non-contradictory', () {
    final templates = [...beyondTemplates, ...powerliftingTemplates];
    final ids = templates.map((item) => item['id']).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final template in templates) {
      final labels = template['labels']! as Map<String, Object?>;
      expect((labels['en']! as String).trim(), isNotEmpty, reason: '${template['id']}');
      expect((labels['fr']! as String).trim(), isNotEmpty, reason: '${template['id']}');
      final variantIds = (template['variants']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((item) => item['id'])
          .toList();
      expect(variantIds.toSet(), hasLength(variantIds.length));
      for (final variant in (template['variants']! as List<Object?>)
          .cast<Map<String, Object?>>()) {
        final id = variant['id']! as String;
        final schedules = (variant['scheduleIds']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map((reference) => reference['id']! as String)
            .toList();
        if (id.contains('four_day')) {
          expect(schedules, everyElement(contains('four_day')), reason: id);
        }
      }
    }
  });

  test('inventory cycle template IDs resolve exactly to declared templates', () {
    final beyondInventory = _inventory('catalog_src/beyond/inventory.json');
    final powerliftingInventory =
        _inventory('catalog_src/powerlifting/inventory.json');
    final declared = {
      for (final template in [...beyondTemplates, ...powerliftingTemplates])
        template['id']! as String,
    };
    final inventoryIds = {
      for (final entry in [...beyondInventory, ...powerliftingInventory])
        if (entry['classification'] == 'cycleTemplate')
          entry['cycleTemplateId']! as String,
    };
    expect(inventoryIds, containsAll(declared));
    expect(declared, containsAll(inventoryIds));
  });
}

List<Map<String, Object?>> _templates(String path) =>
    (_read(path)['templates']! as List<Object?>).cast<Map<String, Object?>>();

List<Map<String, Object?>> _inventory(String path) =>
    (_read(path)['entries']! as List<Object?>).cast<Map<String, Object?>>();

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
