import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const codec = CatalogSourceDocumentCodec();
  const composer = OptionSchemaComposer();

  test('source Bodyweight expands common parameters before local ones', () {
    final schemas = [
      ...codec.decodeOptionSchemas(
        File(
          '../../catalog_src/classic/option_schemas.json',
        ).readAsStringSync(),
      ),
      ...codec.decodeOptionSchemas(
        File(
          '../../catalog_src/classic/extended/option_schemas.json',
        ).readAsStringSync(),
      ),
    ];
    final parameters = composer.compose(
      schemas: schemas,
      reference: const ComponentReference('classic_bodyweight_options', 1),
    );
    final ids = parameters
        .map((parameter) => parameter['id'])
        .toList(growable: false);

    expect(ids.take(3), [
      'warmUp.enabled',
      'warmUp.type',
      'warmUp.bases.lowerBody',
    ]);
    expect(ids.sublist(ids.length - 2), ['total_repetitions', 'set_count']);
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('composer expands transitively in include then local order', () {
    final parameters = composer.compose(
      schemas: [
        _schema('common', parameters: [_parameter('common')]),
        _schema(
          'middle',
          includes: [_reference('common')],
          parameters: [_parameter('middle')],
        ),
        _schema(
          'specialized',
          includes: [_reference('middle')],
          parameters: [_parameter('specialized')],
        ),
      ],
      reference: const ComponentReference('specialized', 1),
    );

    expect(parameters.map((parameter) => parameter['id']), [
      'common',
      'middle',
      'specialized',
    ]);
  });

  test('composer rejects missing references and cycles', () {
    expect(
      () => composer.compose(
        schemas: [
          _schema('a', includes: [_reference('missing')]),
        ],
        reference: const ComponentReference('a', 1),
      ),
      throwsA(_formatContaining('OPTION_SCHEMA_REFERENCE_NOT_FOUND:missing@1')),
    );
    expect(
      () => composer.composeAll([
        _schema('a', includes: [_reference('b')]),
        _schema('b', includes: [_reference('a')]),
      ]),
      throwsA(_formatContaining('OPTION_SCHEMA_CYCLE:')),
    );
  });

  test('composer rejects duplicate schemas, references and parameters', () {
    expect(
      () => composer.composeAll([_schema('a'), _schema('a')]),
      throwsA(_formatContaining('DUPLICATE_OPTION_SCHEMA:a@1')),
    );
    expect(
      () => composer.composeAll([
        _schema('a', includes: [_reference('common'), _reference('common')]),
        _schema('common'),
      ]),
      throwsA(_formatContaining('DUPLICATE_OPTION_SCHEMA_REFERENCE:common@1')),
    );
    expect(
      () => composer.composeAll([
        _schema('common', parameters: [_parameter('same')]),
        _schema(
          'specialized',
          includes: [_reference('common')],
          parameters: [_parameter('same')],
        ),
      ]),
      throwsA(_formatContaining('DUPLICATE_OPTION_PARAMETER_ID:same')),
    );
  });

  test('option-schema codec validates include references strictly', () {
    final valid = {
      'schemaVersion': 1,
      'kind': 'optionSchemas',
      'optionSchemas': [
        _codecSchema('specialized', includes: [_reference('common')]),
      ],
    };
    expect(codec.decodeOptionSchemas(jsonEncode(valid)), hasLength(1));

    for (final invalidIncludes in <Object?>[
      null,
      const <Object?>[],
      [
        {'id': '', 'revision': 1},
      ],
      [
        {'id': 'common', 'revision': 0},
      ],
      [
        {'id': 'common', 'revision': 1, 'extra': true},
      ],
      [_reference('common'), _reference('common')],
    ]) {
      final invalid = jsonDecode(jsonEncode(valid)) as Map<String, Object?>;
      final schema = ((invalid['optionSchemas']! as List).single as Map)
          .cast<String, Object?>();
      schema['includeSchemaIds'] = invalidIncludes;
      expect(
        () => codec.decodeOptionSchemas(jsonEncode(invalid)),
        throwsA(isA<FormatException>()),
        reason: jsonEncode(invalidIncludes),
      );
    }
  });
}

Map<String, Object?> _schema(
  String id, {
  List<Map<String, Object?>> includes = const [],
  List<Map<String, Object?>> parameters = const [],
}) => {
  'id': id,
  'revision': 1,
  if (includes.isNotEmpty) 'includeSchemaIds': includes,
  'parameters': parameters,
};

Map<String, Object?> _codecSchema(
  String id, {
  List<Map<String, Object?>> includes = const [],
}) => {
  'id': id,
  'revision': 1,
  'sourceRuleIds': <Object?>[],
  if (includes.isNotEmpty) 'includeSchemaIds': includes,
  'parameters': <Object?>[],
};

Map<String, Object?> _reference(String id) => {'id': id, 'revision': 1};

Map<String, Object?> _parameter(String id) => {'id': id};

Matcher _formatContaining(String message) => isA<FormatException>().having(
  (error) => error.toString(),
  'message',
  contains(message),
);
