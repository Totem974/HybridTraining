import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final publicTemplates = <Map<String, Object?>>[
    ..._templates('catalog_src/beyond/templates/bbb.v1.json'),
    ..._templates('catalog_src/beyond/templates/main_variations.v1.json'),
    ..._templates('catalog_src/powerlifting/templates.json'),
  ];
  final foreverTemplates =
      _templates('catalog_src/forever/cycle_templates.json');

  test('Beyond and Powerlifting templates declare the public Cycle surface', () {
    expect(publicTemplates, isNotEmpty);
    for (final template in publicTemplates) {
      expect(
        template['surface'],
        'cyclePublic',
        reason: '${template['id']} must be selected declaratively',
      );
    }
  });

  test('Forever cycle recipes declare an internal-only surface', () {
    expect(foreverTemplates, isNotEmpty);
    for (final template in foreverTemplates) {
      expect(
        template['surface'],
        'foreverInternal',
        reason: '${template['id']} must not enter the public Cycle index',
      );
    }
  });

  test('surface uses only the two canonical stable values', () {
    final surfaces = [...publicTemplates, ...foreverTemplates]
        .map((template) => template['surface'])
        .toSet();
    expect(surfaces, {'cyclePublic', 'foreverInternal'});
  });
}

List<Map<String, Object?>> _templates(String path) {
  final document =
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
  return (document['templates']! as List<Object?>)
      .cast<Map<String, Object?>>();
}
