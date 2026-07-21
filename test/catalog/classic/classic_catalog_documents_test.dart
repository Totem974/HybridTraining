import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Original inventory is exhaustive and every Cycle row resolves', () {
    final inventory = _read('catalog_src/classic/inventory.json');
    final sources = _read('catalog_src/classic/sources.json');
    final templates = _read('catalog_src/classic/templates.json');
    final extendedTemplates = _read(
      'catalog_src/classic/extended/templates.json',
    );
    final assistance = _read('catalog_src/assistance/plans.v1.json');
    final classicAssistance = _read(
      'catalog_src/classic/library/assistance_plans.v1.json',
    );
    final sharedComponents = _read(
      'catalog_src/shared/cycle_components_v1.json',
    );
    final classicComponents = _read(
      'catalog_src/classic/library/simplest_strength_components.v1.json',
    );

    expect(inventory.keys.toSet(), {'schemaVersion', 'kind', 'entries'});
    expect(inventory['schemaVersion'], 1);
    expect(inventory['kind'], 'inventory');
    final entries = (inventory['entries']! as List).cast<Map>();
    expect(entries, hasLength(40));
    expect(entries.map((entry) => entry['id']).toSet(), hasLength(40));
    expect(entries.map((entry) => entry['id']), containsAll([
      'OR-001',
      'OR-040',
    ]));

    final ruleIds = (sources['sources']! as List)
        .cast<Map>()
        .map((source) => source['ruleId'])
        .toSet();
    for (final entry in entries) {
      expect(
        ruleIds,
        containsAll((entry['sourceRuleIds']! as List).cast<String>()),
        reason: '${entry['id']} has complete provenance',
      );
    }

    final templateIds = (templates['templates']! as List)
        .cast<Map>()
        .map((template) => template['id'])
        .followedBy(
          (extendedTemplates['templates']! as List)
              .cast<Map>()
              .map((template) => template['id']),
        )
        .toSet();
    final assistancePlanIds = (assistance['assistancePlans']! as List)
        .cast<Map>()
        .map((plan) => plan['id'])
        .followedBy(
          (classicAssistance['assistancePlans']! as List)
              .cast<Map>()
              .map((plan) => plan['id']),
        )
        .toSet();
    final componentIds = (sharedComponents['components']! as List)
        .cast<Map>()
        .map((component) => component['id'])
        .followedBy(
          (classicComponents['components']! as List)
              .cast<Map>()
              .map((component) => component['id']),
        )
        .toSet();
    final cycleEntries = entries.where(
      (entry) => entry['classification'] == 'cycleTemplate',
    );
    for (final entry in cycleEntries) {
      expect(templateIds, contains(entry['cycleTemplateId']));
    }
    for (final template in (templates['templates']! as List).cast<Map>()) {
      for (final variant in (template['variants']! as List).cast<Map>()) {
        expect(variant, isNot(contains('componentIds')));
        expect(
          variant.containsKey('weekPlans') ^ variant.containsKey('phases'),
          isTrue,
        );
        for (final week in (variant['weekPlans']! as List).cast<Map>()) {
          expect(week.keys.toSet(), {'weekNumber', 'componentIds'});
          expect(week['componentIds'], isNotEmpty);
          for (final reference
              in (week['componentIds']! as List).cast<Map>()) {
            expect(componentIds, contains(reference['id']));
          }
          expect(
            (week['componentIds']! as List)
                .cast<Map>()
                .map((reference) => reference['id']),
            everyElement(isNot(startsWith('assistance_'))),
          );
        }
        for (final reference
            in (variant['assistancePlanIds']! as List).cast<Map>()) {
          expect(assistancePlanIds, contains(reference['id']));
        }
      }
    }
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
