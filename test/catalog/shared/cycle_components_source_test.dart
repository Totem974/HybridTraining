import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared Cycle components are strict, sourced and uniquely versioned', () {
    final root = jsonDecode(
      File('catalog_src/shared/cycle_components_v1.json').readAsStringSync(),
    )! as Map<String, Object?>;
    expect(root.keys.toSet(), {'schemaVersion', 'kind', 'components'});
    expect(root['schemaVersion'], 1);
    expect(root['kind'], 'components');
    final components = (root['components']! as List).cast<Map>();
    expect(components, isNotEmpty);
    expect(
      components.map((component) => component['id']).toSet(),
      hasLength(components.length),
    );
    const keys = {
      'id',
      'revision',
      'role',
      'labels',
      'sourceRuleIds',
      'parameterSchemaIds',
      'constraints',
      'compatibilities',
      'block',
    };
    for (final component in components) {
      expect(component.keys.toSet(), keys);
      expect(component['revision'], 1);
      expect(component['sourceRuleIds'], isNotEmpty);
      expect(component['id'], isNot(contains('placeholder')));
      final block = component['block']! as Map;
      expect(block.keys.toSet(), {'id', 'role', 'sets'});
      expect(block['sets'], isNotEmpty);
    }
  });

  test('canonical prescriptions retain reviewed set details', () {
    final components = _componentsById();
    expect(_percentages(components['warmup_original_40_50_60']!), [
      4000,
      5000,
      6000,
    ]);
    expect(_percentages(components['main_standard_5_week']!), [
      6500,
      7500,
      8500,
    ]);
    expect(_percentages(components['main_standard_3_week']!), [
      7000,
      8000,
      9000,
    ]);
    expect(_percentages(components['main_standard_531_week']!), [
      7500,
      8500,
      9500,
    ]);
    final bbbSets = _sets(components['supplemental_bbb_original_5x10_50']!);
    expect(bbbSets, hasLength(5));
    expect(
      bbbSets.map((set) => (set['repetitions'] as Map)['count']),
      everyElement(10),
    );
    expect(
      bbbSets.map((set) => (set['load'] as Map)['basisPoints']),
      everyElement(5000),
    );
  });
}

Map<String, Map> _componentsById() {
  final root = jsonDecode(
    File('catalog_src/shared/cycle_components_v1.json').readAsStringSync(),
  )! as Map<String, Object?>;
  return {
    for (final component in (root['components']! as List).cast<Map>())
      component['id']! as String: component,
  };
}

List<Map> _sets(Map component) =>
    ((component['block']! as Map)['sets']! as List).cast<Map>();

List<Object?> _percentages(Map component) => _sets(
  component,
).map((set) => (set['load']! as Map)['basisPoints']).toList();
