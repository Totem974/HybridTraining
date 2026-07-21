import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies every Beyond inventory entry with a precise source', () {
    final inventory =
        jsonDecode(File('catalog_src/beyond/inventory.json').readAsStringSync())
            as Map<String, Object?>;
    final sources =
        jsonDecode(File('catalog_src/beyond/sources.json').readAsStringSync())
            as Map<String, Object?>;
    final entries = inventory['entries']! as List<Object?>;
    final rules = sources['sources']! as List<Object?>;
    final ruleIds = rules
        .map((rule) => (rule! as Map<String, Object?>)['ruleId'])
        .toSet();

    expect(entries, hasLength(107));
    expect(rules, hasLength(107));
    expect(
      entries.every((entry) {
        final map = entry! as Map<String, Object?>;
        final ids = map['sourceRuleIds']! as List<Object?>;
        return ids.isNotEmpty && ids.every(ruleIds.contains);
      }),
      isTrue,
    );
    final byId = {
      for (final entry in entries)
        (entry! as Map<String, Object?>)['id']! as String: entry,
    };
    expect(
      {
        for (final id in const [
          'beyond_004',
          'beyond_005',
          'beyond_015',
          'beyond_063',
        ])
          id: (byId[id]!['cycleTemplateId']),
      },
      {
        'beyond_004': 'beyond_pyramid',
        'beyond_005': 'beyond_first_set_last',
        'beyond_015': 'beyond_boring_but_big',
        'beyond_063': 'beyond_fives_progression',
      },
    );
    expect(byId['beyond_016']!['classification'], 'sharedComponent');
  });
}
