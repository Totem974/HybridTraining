import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final templatesDocument = _read('templates.json');
  final optionsDocument = _read('option_schemas.json');
  final schedulesDocument = _read('schedules.json');
  final componentsDocument = _read('components.json');
  final aliasesDocument = _read('template_aliases.json');

  final templates = _records(templatesDocument, 'templates');
  final schemas = _records(optionsDocument, 'optionSchemas');
  final schedules = _records(schedulesDocument, 'schedules');
  final components = _records(componentsDocument, 'components');

  Map<String, Object?> byId(List<Map<String, Object?>> records, String id) =>
      records.singleWhere((record) => record['id'] == id);

  final fullBody = byId(templates, 'classic_full_body');
  final variants = _maps(fullBody['variants']);
  Map<String, Object?> variant(String id) => byId(variants, id);

  test(
    'one public Full Body template owns exactly three observed variants',
    () {
      expect(
        templates.where(
          (template) =>
              (template['id'] as String).startsWith('classic_full_body'),
        ),
        hasLength(1),
      );
      expect(variants.map((item) => item['id']), [
        'original',
        'updated',
        'full_boring',
      ]);
      expect(variants.every((item) => item['phases'] == null), isTrue);
      expect(
        variants.every((item) => _maps(item['weekPlans']).length == 4),
        isTrue,
      );
    },
  );

  test('Original owns the phase choice and no other variant exposes it', () {
    final originalSchema = byId(
      schemas,
      _map(variant('original')['optionSchemaId'])['id'] as String,
    );
    final phase = byId(_maps(originalSchema['parameters']), 'phase');
    expect(phase['default'], 'phase_one');
    expect(phase['allowedValues'], ['phase_one', 'phase_two', 'phase_three']);
    for (final id in ['updated', 'full_boring']) {
      final schema = byId(
        schemas,
        _map(variant(id)['optionSchemaId'])['id'] as String,
      );
      expect(
        _maps(schema['parameters']).map((item) => item['id']),
        isNot(contains('phase')),
      );
    }
  });

  test('component selections are declarative and cover every option value', () {
    for (final recipe in variants) {
      final schema = byId(
        schemas,
        _map(recipe['optionSchemaId'])['id'] as String,
      );
      final parameters = {
        for (final parameter in _maps(schema['parameters']))
          parameter['id'] as String: parameter,
      };
      final referenced = _maps(recipe['weekPlans'])
          .expand((week) => _maps(week['componentIds']))
          .map((reference) => reference['id'])
          .toSet();
      for (final selection in _maps(recipe['componentSelections'])) {
        final parameter = parameters[selection['parameterId']]!;
        final target = _map(selection['targetComponentId']);
        expect(referenced, contains(target['id']), reason: '${recipe['id']}');
        expect(
          _maps(selection['choices']).map((choice) => choice['value']).toSet(),
          (parameter['allowedValues'] as List).toSet(),
          reason: '${recipe['id']}.${parameter['id']}',
        );
        for (final choice in _maps(selection['choices'])) {
          final reference = _map(choice['componentId']);
          expect(
            components.any(
              (component) =>
                  component['id'] == reference['id'] &&
                  component['revision'] == reference['revision'],
            ),
            isTrue,
            reason: '${recipe['id']}.${choice['value']}',
          );
        }
      }
    }
  });

  test(
    'Updated and Full Boring preserve the observed profile prescriptions',
    () {
      final updated = byId(schemas, 'classic_full_body_updated_options');
      expect(
        byId(
          _maps(updated['parameters']),
          'squat_set_profile',
        )['allowedValues'],
        [
          '65x5_75x5_85x5',
          '70x3_80x3_90x3',
          '75x5_85x3_95x1',
          '80x1_90x1_100x1',
        ],
      );
      final boring = byId(schemas, 'classic_full_body_full_boring_options');
      expect(
        byId(
          _maps(boring['parameters']),
          'deadlift_set_profile',
        )['allowedValues'],
        [
          '65x3_75x3_85x3',
          '70x3_80x3_90x3',
          '75x5_85x3_95x1',
          '80x1_90x1_100x1',
        ],
      );
      expect(
        _prescription(
          byId(components, 'classic_full_body_profile_squat_80x1_90x1_100x1'),
        ),
        ['1@8000', '1@9000', '1@10000'],
      );
      expect(
        _prescription(
          byId(components, 'classic_full_body_profile_deadlift_65x3_75x3_85x3'),
        ),
        ['3@6500', '3@7500', '3@8500'],
      );
    },
  );

  test('schedules expose program movements but no assistance exercises', () {
    const canonicalMovements = {
      'back_squat',
      'bench_press',
      'deadlift',
      'overhead_press',
    };
    for (final id in [
      'classic_for_beginners_three_day',
      'classic_full_body_three_day',
      'classic_full_body_full_boring_three_day',
    ]) {
      final schedule = byId(schedules, id);
      final movementIds = _maps(
        schedule['sessions'],
      ).expand((session) => (session['movementIds'] as List).cast<String>());
      expect(
        movementIds.toSet().difference(canonicalMovements),
        isEmpty,
        reason: id,
      );
      expect(movementIds, isNot(contains('dumbbell_press')), reason: id);
      expect(movementIds, isNot(contains('dumbbell_row')), reason: id);
      expect(movementIds, isNot(contains('chin_up')), reason: id);
    }
  });

  test(
    'Full Boring has profiles only and does not inject assistance components',
    () {
      final ids = _maps(variant('full_boring')['weekPlans'])
          .expand((week) => _maps(week['componentIds']))
          .map((reference) => reference['id'] as String)
          .toSet();
      expect(ids.where((id) => id.contains('assistance')), isEmpty);
      expect(
        ids,
        containsAll(<String>[
          'classic_full_body_profile_squat_65x5_75x5_85x5',
          'classic_full_body_profile_bench_65x5_75x5_85x5',
          'classic_full_body_profile_deadlift_65x3_75x3_85x3',
        ]),
      );
    },
  );

  test(
    'legacy identities migrate declaratively without public duplication',
    () {
      expect(aliasesDocument['kind'], 'templateAliases');
      final aliases = _records(aliasesDocument, 'templateAliases');
      expect(aliases, hasLength(3));
      for (var index = 1; index <= 3; index++) {
        final alias = aliases.singleWhere(
          (item) =>
              item['legacyTemplateId'] == 'classic_full_body_phase_$index',
        );
        expect(alias['legacyVariantId'], 'phase_$index');
        expect(alias['templateId'], 'classic_full_body');
        expect(alias['variantId'], 'original');
        expect(
          _map(alias['optionOverrides'])['phase'],
          ['phase_one', 'phase_two', 'phase_three'][index - 1],
        );
      }
    },
  );
}

Map<String, Object?> _read(String file) =>
    (jsonDecode(File('catalog_src/classic/extended/$file').readAsStringSync())
            as Map)
        .cast<String, Object?>();

List<Map<String, Object?>> _records(
  Map<String, Object?> document,
  String key,
) => _maps(document[key]);

List<Map<String, Object?>> _maps(Object? value) =>
    (value as List).map(_map).toList(growable: false);

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();

List<String> _prescription(
  Map<String, Object?> component,
) => _maps(_map(component['block'])['sets'])
    .map(
      (set) =>
          '${_map(set['repetitions'])['count']}@${_map(set['load'])['basisPoints']}',
    )
    .toList(growable: false);
