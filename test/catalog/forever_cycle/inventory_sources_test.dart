import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final inventory =
      jsonDecode(
            File('catalog_src/forever_cycle/inventory.json').readAsStringSync(),
          )
          as Map<String, Object?>;
  final sourceDocument =
      jsonDecode(
            File(
              'catalog_src/forever_cycle/inventory_sources.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final entries = (inventory['entries']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final sources = (sourceDocument['sources']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('historical Forever inventory has one precise source per entry', () {
    expect(sourceDocument.keys.toSet(), {'schemaVersion', 'kind', 'sources'});
    expect(sourceDocument['schemaVersion'], 1);
    expect(sourceDocument['kind'], 'sources');
    expect(sources, hasLength(182));

    final referencedRuleIds = entries
        .expand((entry) => entry['sourceRuleIds']! as List<Object?>)
        .cast<String>()
        .toSet();
    final publishedRuleIds = sources
        .map((source) => source['ruleId']! as String)
        .toSet();
    expect(publishedRuleIds, hasLength(182));
    expect(publishedRuleIds, referencedRuleIds);
  });

  test('sources identify the primary work, edition and page section', () {
    for (final source in sources) {
      expect(source.keys.toSet(), {
        'ruleId',
        'work',
        'edition',
        'section',
        'reviewStatus',
      });
      expect(source['ruleId'], matches(RegExp(r'^fv\.entry\.\d{3}$')));
      expect(source['work'], '5/3/1 Forever');
      expect(source['edition'], 'First edition (2017)');
      expect(source['section'], matches(RegExp(r'^pp\. [0-9]')));
      expect(source['reviewStatus'], 'reviewed');
    }
  });

  test('historical sources do not promote Forever into Cycle templates', () {
    expect(
      entries.where((entry) => entry['classification'] == 'cycleTemplate'),
      isEmpty,
    );
    expect(
      entries.any((entry) => entry.containsKey('cycleTemplateId')),
      isFalse,
    );
  });
}
