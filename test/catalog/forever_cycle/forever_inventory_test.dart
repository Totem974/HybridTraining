import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final document =
      jsonDecode(
            File('catalog_src/forever_cycle/inventory.json').readAsStringSync(),
          )
          as Map<String, Object?>;
  final entries = (document['entries']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('Forever inventory preserves all 182 historical identities', () {
    expect(document.keys.toSet(), {'schemaVersion', 'kind', 'entries'});
    expect(document['schemaVersion'], 1);
    expect(document['kind'], 'inventory');
    expect(entries, hasLength(182));
    expect(entries.map((entry) => entry['id']).toSet(), hasLength(182));
    expect(entries.first['id'], 'FV-133');
    expect(entries.last['id'], 'FV-314');
    for (var suffix = 133; suffix <= 314; suffix++) {
      expect(
        entries.map((entry) => entry['id']),
        contains('FV-${suffix.toString().padLeft(3, '0')}'),
      );
    }
  });

  test('Forever macrocycles are excluded from the Cycle generator', () {
    final byId = {for (final entry in entries) entry['id']: entry};
    for (final id in [
      'FV-141', // Beginner Prep School
      'FV-142', // BBB base
      'FV-154', // FSL base
      'FV-167', // 1000% Awesome
      'FV-208', // Supplemental Heaven
      'FV-209', // Full Body 1
      'FV-236', // Original 5/3/1 + FSL
      'FV-281', // Runnin' with the Devil
    ]) {
      expect(byId[id]!['classification'], 'documentation', reason: id);
      expect(byId[id]!.containsKey('cycleTemplateId'), isFalse, reason: id);
    }
    expect(
      entries.where((entry) => entry['classification'] == 'cycleTemplate'),
      isEmpty,
    );
    expect(
      entries.any((entry) => entry.containsKey('cycleTemplateId')),
      isFalse,
    );
  });

  test('protocols, rules and transitions retain honest classifications', () {
    final byId = {for (final entry in entries) entry['id']: entry};
    expect(byId['FV-133']!['classification'], 'transition');
    expect(byId['FV-136']!['classification'], 'protocol');
    expect(byId['FV-282']!['classification'], 'documentation');
    expect(byId['FV-285']!['classification'], 'rule');
    expect(byId['FV-294']!['classification'], 'documentation');
    expect(byId['FV-299']!['classification'], 'documentation');
    expect(byId['FV-301']!['classification'], 'protocol');
    expect(byId['FV-306']!['classification'], 'transition');
  });

  test('records have source rules and contain no placeholder status', () {
    const classifications = {'documentation', 'rule', 'protocol', 'transition'};
    for (final entry in entries) {
      expect(entry['generation'], 'forever');
      expect(classifications, contains(entry['classification']));
      final title = entry['title']! as Map<String, Object?>;
      expect(title.keys.toSet(), {'en', 'fr'});
      expect(title['en'], isNotEmpty);
      expect(title['fr'], isNotEmpty);
      expect(
        (entry['sourceRuleIds']! as List<Object?>).single,
        matches(RegExp(r'^fv\.entry\.\d{3}$')),
      );
      final encoded = jsonEncode(entry).toLowerCase();
      expect(encoded, isNot(contains('needs_review')));
      expect(encoded, isNot(contains('placeholder')));
      expect(encoded, isNot(contains('todo')));
    }
  });
}
