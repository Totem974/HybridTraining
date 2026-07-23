import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const codec = CatalogSourceDocumentCodec();

  test('catalog enum value labels are preserved and bilingual', () {
    final schemas = <Map<String, Object?>>[
      for (final path in const [
        '../../catalog_src/classic/option_schemas.json',
        '../../catalog_src/classic/extended/option_schemas.json',
        '../../catalog_src/source_fsl_gvt/option_schemas.json',
        '../../catalog_src/source_two_day/option_schemas.json',
      ])
        ...codec.decodeOptionSchemas(File(path).readAsStringSync()),
    ];

    final cases = {
      ('classic_crosscut_options', 'warmUp.type'): 'Original 5/3/1',
      ('classic_crosscut_options', 'deload.type'): 'Option 1',
      ('classic_full_body_original_options', 'phase'): 'Phase 1',
      ('classic_full_body_updated_options', 'squat_set_profile'):
          '65% × 5 · 75% × 5 · 85% × 5',
      ('source_fsl_options', 'fsl_mode'): 'AMRAP',
      ('source_two_day_option_three_options', 'second_lift_profile'):
          '65% × 3 · 75% × 3 · 85% × 3',
    };

    for (final entry in cases.entries) {
      final schema = schemas.singleWhere(
        (schema) => schema['id'] == entry.key.$1,
      );
      final parameter = (schema['parameters']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((parameter) => parameter['id'] == entry.key.$2);
      final allowedValues = parameter['allowedValues']! as List<Object?>;
      final valueLabels = (parameter['valueLabels']! as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(valueLabels, hasLength(allowedValues.length));
      expect(
        (valueLabels.first['labels']! as Map<String, Object?>)['en'],
        entry.value,
        reason: '${entry.key.$1}.${entry.key.$2}',
      );
      for (final valueLabel in valueLabels) {
        expect(allowedValues, contains(valueLabel['value']));
        final labels = valueLabel['labels']! as Map<String, Object?>;
        expect(labels.keys, unorderedEquals(['en', 'fr']));
        expect(
          labels['en'],
          isA<String>().having((value) => value, 'en', isNotEmpty),
        );
        expect(
          labels['fr'],
          isA<String>().having((value) => value, 'fr', isNotEmpty),
        );
      }
    }
  });

  test('value labels remain optional for backward compatibility', () {
    final document = _document(_parameter()..remove('valueLabels'));

    final decoded = codec.decodeOptionSchemas(jsonEncode(document));

    expect(
      ((decoded.single['parameters']! as List<Object?>).single
          as Map<String, Object?>),
      isNot(contains('valueLabels')),
    );
  });

  test('codec rejects invalid enum value-label metadata', () {
    final invalidParameters = <Map<String, Object?>>[
      _parameter()..['type'] = 'integer',
      _parameter()..['valueLabels'] = <Object?>[],
      _parameter()
        ..['valueLabels'] = [_valueLabel('not_allowed', 'Other', 'Autre')],
      _parameter()
        ..['valueLabels'] = [
          _valueLabel('first', 'First', 'Premier'),
          _valueLabel('first', 'Again', 'Encore'),
        ],
      _parameter()
        ..['valueLabels'] = [
          {..._valueLabel('first', 'First', 'Premier'), 'unknown': true},
        ],
      _parameter()
        ..['valueLabels'] = [
          {
            'value': 'first',
            'labels': {'en': 'First'},
          },
        ],
      _parameter()..['valueLabels'] = [_valueLabel('first', ' ', 'Premier')],
    ];

    for (final parameter in invalidParameters) {
      expect(
        () => codec.decodeOptionSchemas(jsonEncode(_document(parameter))),
        throwsA(isA<FormatException>()),
        reason: jsonEncode(parameter['valueLabels']),
      );
    }
  });
}

Map<String, Object?> _document(Map<String, Object?> parameter) => {
  'schemaVersion': 1,
  'kind': 'optionSchemas',
  'optionSchemas': [
    {
      'id': 'localized_options',
      'revision': 1,
      'sourceRuleIds': <Object?>[],
      'parameters': [parameter],
    },
  ],
};

Map<String, Object?> _parameter() => {
  'id': 'mode',
  'type': 'enumeration',
  'scope': 'global',
  'default': 'first',
  'minimum': null,
  'maximum': null,
  'step': null,
  'allowedValues': ['first', 'second'],
  'valueLabels': [
    _valueLabel('first', 'First', 'Premier'),
    _valueLabel('second', 'Second', 'Deuxième'),
  ],
  'visibleWhen': {'type': 'always'},
  'enabledWhen': {'type': 'always'},
  'requiredWhen': {'type': 'always'},
};

Map<String, Object?> _valueLabel(
  Object value,
  String labelEn,
  String labelFr,
) => {
  'value': value,
  'labels': {'en': labelEn, 'fr': labelFr},
};
