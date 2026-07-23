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
    expect(schedules, hasLength(5));
    expect(
      schedules.map((schedule) => schedule['id']),
      containsAll([
        'classic_extended_two_day_option_one',
        'classic_extended_two_day_option_two',
        'classic_for_beginners_three_day',
        'classic_full_body_three_day',
        'classic_full_body_full_boring_three_day',
      ]),
    );
    for (final schedule in schedules) {
      expect(schedule['sessions'], isNotEmpty);
    }
    expect(
      (schedules.singleWhere(
            (schedule) => schedule['id'] == 'classic_full_body_three_day',
          )['sessions']!
          as List<Object?>),
      hasLength(3),
    );
  });

  test('extended options are closed and have complete conditions', () {
    final document = load('catalog_src/classic/extended/option_schemas.json');
    expect(document.keys.toSet(), {'schemaVersion', 'kind', 'optionSchemas'});
    final schemas = (document['optionSchemas']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(schemas, hasLength(5));
    for (final schema in schemas) {
      for (final parameter
          in (schema['parameters']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        final expectedKeys = {
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
        };
        if (parameter.containsKey('presentationGroup')) {
          expectedKeys.add('presentationGroup');
          expect(parameter['presentationGroup'], 'hidden');
        }
        if (parameter.containsKey('labelEn')) {
          expectedKeys.addAll({'labelEn', 'labelFr'});
          expect(parameter['labelEn'], isNotEmpty);
          expect(parameter['labelFr'], isNotEmpty);
        }
        if (parameter.containsKey('requestPath')) {
          expectedKeys.add('requestPath');
          expect(parameter['requestPath'], startsWith('fullBody.'));
        }
        if (parameter.containsKey('valueLabels')) {
          expectedKeys.add('valueLabels');
          expect(parameter['type'], 'enumeration');
          final allowedValues = parameter['allowedValues']! as List<Object?>;
          final valueLabels = (parameter['valueLabels']! as List<Object?>)
              .cast<Map<String, Object?>>();
          expect(valueLabels, hasLength(allowedValues.length));
          final labeledValues = <Object?>{};
          for (final valueLabel in valueLabels) {
            expect(valueLabel.keys.toSet(), {'value', 'labels'});
            expect(allowedValues, contains(valueLabel['value']));
            expect(
              labeledValues.add(valueLabel['value']),
              isTrue,
              reason: '${parameter['id']} has duplicate value labels',
            );
            final labels = valueLabel['labels']! as Map<String, Object?>;
            expect(labels.keys.toSet(), {'en', 'fr'});
            expect(labels['en'], isA<String>().having((value) => value, 'en', isNotEmpty));
            expect(labels['fr'], isA<String>().having((value) => value, 'fr', isNotEmpty));
          }
          expect(labeledValues, unorderedEquals(allowedValues));
        }
        expect(parameter.keys.toSet(), expectedKeys);
        expect(parameter['visibleWhen'], {'type': 'always'});
        expect(parameter['enabledWhen'], {'type': 'always'});
        expect(parameter['requiredWhen'], {'type': 'always'});
      }
    }
  });

  test('For Beginners routes every block to its documented session', () {
    final componentsDocument = load(
      'catalog_src/classic/extended/components.json',
    );
    final components = (componentsDocument['components']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(components, hasLength(44));
    for (final component in components) {
      final compatibility =
          component['compatibilities']! as Map<String, Object?>;
      expect(compatibility['sessionIds'], isNotEmpty);
      expect(compatibility['movementIds'], isNotEmpty);
    }

    final templatesDocument = load(
      'catalog_src/classic/extended/templates.json',
    );
    final templates = (templatesDocument['templates']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final template = templates.singleWhere(
      (value) => value['id'] == 'classic_for_beginners',
    );
    expect(template['id'], 'classic_for_beginners');
    final variant = (template['variants']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    expect(variant['weekPlans'], hasLength(4));
    expect((variant['scheduleIds']! as List<Object?>).single, {
      'id': 'classic_for_beginners_three_day',
      'revision': 1,
    });
  });

  test('Full Body is canonical with three four-week variants and aliases', () {
    final document = load('catalog_src/classic/extended/templates.json');
    final templates = (document['templates']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final template = templates.singleWhere(
      (value) => value['id'] == 'classic_full_body',
    );
    expect(template['surface'], 'cyclePublic');
    final variants = (template['variants']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(variants.map((variant) => variant['id']).toSet(), {
      'original',
      'updated',
      'full_boring',
    });
    for (final variant in variants) {
      expect(variant, isNot(contains('phases')));
      expect(variant['weekPlans'], hasLength(4));
      expect(variant['scheduleIds'], isNotEmpty);
    }

    final aliasDocument = load(
      'catalog_src/classic/extended/template_aliases.json',
    );
    final aliases = (aliasDocument['templateAliases']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(aliases, hasLength(3));
    expect(aliases.map((alias) => alias['legacyTemplateId']).toSet(), {
      'classic_full_body_phase_1',
      'classic_full_body_phase_2',
      'classic_full_body_phase_3',
    });
    expect(
      aliases.map((alias) => alias['templateId']),
      everyElement('classic_full_body'),
    );
    expect(
      aliases.map((alias) => alias['variantId']),
      everyElement('original'),
    );
  });
}
