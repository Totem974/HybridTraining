import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 25 Powerlifting rows are classified without fake templates', () {
    final inventory = _read('catalog_src/powerlifting/inventory.json');
    final sources = _read('catalog_src/powerlifting/sources.json');
    final templates = _read('catalog_src/powerlifting/templates.json');

    expect(inventory.keys.toSet(), {'schemaVersion', 'kind', 'entries'});
    final entries = (inventory['entries']! as List).cast<Map>();
    expect(entries, hasLength(25));
    expect(
      entries.map((entry) => entry['id']),
      orderedEquals([
        for (var index = 1; index <= 25; index++)
          'PL-${index.toString().padLeft(3, '0')}',
      ]),
    );
    final cycleEntries = entries.where(
      (entry) => entry['classification'] == 'cycleTemplate',
    );
    expect(cycleEntries.map((entry) => entry['id']), ['PL-001']);
    expect(
      entries.where((entry) => entry['classification'] == 'documentation'),
      isNotEmpty,
      reason: 'insufficiently proven recipes stay outside the generator',
    );

    final ruleIds = (sources['sources']! as List)
        .cast<Map>()
        .map((source) => source['ruleId'])
        .toSet();
    for (final entry in entries) {
      expect(
        ruleIds,
        containsAll((entry['sourceRuleIds']! as List).cast<String>()),
        reason: '${entry['id']} has a reviewed page reference',
      );
    }
    final templateIds = (templates['templates']! as List)
        .cast<Map>()
        .map((template) => template['id'])
        .toSet();
    expect(templateIds, {'powerlifting_classic_531'});
    expect(templateIds, contains(cycleEntries.single['cycleTemplateId']));
    final variant =
        ((templates['templates']! as List).single as Map)['variants'] as List;
    final fourDay = variant.single as Map;
    expect(fourDay, isNot(contains('componentIds')));
    expect(
      (fourDay['weekPlans']! as List)
          .cast<Map>()
          .map((week) => week['weekNumber']),
      [1, 2, 3, 4],
    );
    expect(
      ((fourDay['scheduleIds']! as List).single as Map)['id'],
      'schedule_four_day_fixed',
    );
    _expectNoPlaceholder([inventory, sources, templates]);
  });
}

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void _expectNoPlaceholder(List<Map<String, Object?>> documents) {
  final text = jsonEncode(documents).toLowerCase();
  for (final forbidden in ['todo', 'placeholder', 'needs_review', 'blocked']) {
    expect(text, isNot(contains(forbidden)));
  }
}
