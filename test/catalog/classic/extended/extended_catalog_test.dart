import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> load(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  test('extended Classic schedules preserve sourced day structures', () {
    final document = load('catalog_src/classic/extended/schedules.json');
    expect(document.keys.toSet(), {'schemaVersion', 'kind', 'schedules'});
    final schedules = (document['schedules']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(schedules, hasLength(3));
    expect(
      schedules.map((schedule) => schedule['id']),
      containsAll([
        'classic_extended_three_day_full_body',
        'classic_extended_two_day_option_one',
        'classic_extended_two_day_option_two',
      ]),
    );
    expect(
      (schedules.first['sessions']! as List<Object?>),
      hasLength(3),
    );
  });

  test('extended options are closed and have complete conditions', () {
    final document = load('catalog_src/classic/extended/option_schemas.json');
    expect(
      document.keys.toSet(),
      {'schemaVersion', 'kind', 'optionSchemas'},
    );
    final schemas = (document['optionSchemas']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(schemas, hasLength(3));
    for (final schema in schemas) {
      for (final parameter in (schema['parameters']! as List<Object?>)
          .cast<Map<String, Object?>>()) {
        expect(parameter.keys.toSet(), {
          'id',
          'type',
          'scope',
          'default',
          'minimum',
          'maximum',
          'step',
          'allowedValues',
          'visibleWhen',
          'enabledWhen',
          'requiredWhen',
        });
        expect(parameter['visibleWhen'], {'type': 'always'});
        expect(parameter['enabledWhen'], {'type': 'always'});
        expect(parameter['requiredWhen'], {'type': 'always'});
      }
    }
  });

  test('For Beginners routes every block to its documented session', () {
    final componentsDocument =
        load('catalog_src/classic/extended/components.json');
    final components = (componentsDocument['components']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(components, hasLength(32));
    for (final component in components) {
      final compatibility =
          component['compatibilities']! as Map<String, Object?>;
      expect(compatibility['sessionIds'], isNotEmpty);
      expect(compatibility['movementIds'], isNotEmpty);
    }

    final templatesDocument =
        load('catalog_src/classic/extended/templates.json');
    final templates = (templatesDocument['templates']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final template = templates
        .singleWhere((value) => value['id'] == 'classic_for_beginners');
    expect(template['id'], 'classic_for_beginners');
    final variant = (template['variants']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    expect(variant['weekPlans'], hasLength(4));
    expect(
      (variant['scheduleIds']! as List<Object?>).single,
      {'id': 'classic_extended_three_day_full_body', 'revision': 1},
    );
  });

  test('Full Body phases one to three preserve two four-week cycles', () {
    final document = load('catalog_src/classic/extended/templates.json');
    final templates = (document['templates']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (var phaseNumber = 1; phaseNumber <= 3; phaseNumber++) {
      final template = templates.singleWhere(
        (value) => value['id'] == 'classic_full_body_phase_$phaseNumber',
      );
      final variant = (template['variants']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .single;
      final phase = (variant['phases']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .single;
      expect(phase['repeatCount'], 2);
      expect(phase['weekPlans'], hasLength(4));
    }
  });
}
