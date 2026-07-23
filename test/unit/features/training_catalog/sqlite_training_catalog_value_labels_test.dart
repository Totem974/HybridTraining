import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_option_schema.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('accepts valid value labels on enumeration options', () async {
    final option = await _loadOption(_parameter());

    expect(option.id, 'generation');
    expect(option.allowedValues, ['original', 'beyond']);
  });

  test('rejects value labels on non-enumeration options', () async {
    await expectLater(
      _loadOption(
        _parameter(
          type: 'boolean',
          allowedValues: const [true, false],
          valueLabels: const [
            {
              'value': true,
              'labels': {'en': 'Enabled', 'fr': 'Activé'},
            },
          ],
        ),
      ),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('rejects labels for values outside allowedValues', () async {
    await expectLater(
      _loadOption(
        _parameter(
          valueLabels: const [
            {
              'value': 'unknown',
              'labels': {'en': 'Unknown', 'fr': 'Inconnu'},
            },
          ],
        ),
      ),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('rejects duplicate labeled values', () async {
    await expectLater(
      _loadOption(
        _parameter(
          valueLabels: const [
            {
              'value': 'original',
              'labels': {'en': 'Original', 'fr': 'Original'},
            },
            {
              'value': 'original',
              'labels': {'en': 'Again', 'fr': 'Encore'},
            },
          ],
        ),
      ),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('rejects an omitted allowed value label', () async {
    await expectLater(
      _loadOption(
        _parameter(
          valueLabels: const [
            {
              'value': 'original',
              'labels': {'en': 'Original', 'fr': 'Original'},
            },
          ],
        ),
      ),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('rejects empty English or French value labels', () async {
    for (final labels in const [
      {'en': ' ', 'fr': 'Original'},
      {'en': 'Original', 'fr': ''},
    ]) {
      await expectLater(
        _loadOption(
          _parameter(
            valueLabels: [
              {'value': 'original', 'labels': labels},
            ],
          ),
        ),
        throwsA(isA<CatalogFormatException>()),
      );
    }
  });
}

Future<CycleOptionDefinition> _loadOption(
  Map<String, Object?> parameter,
) async {
  final database = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, _) => SqliteTrainingCatalog.createSchema(db),
      version: 1,
    ),
  );
  try {
    final repository = SqliteTrainingCatalog(database);
    final seed =
        jsonDecode(
              File('assets/catalog/standard_531_v1.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    seed['status'] = 'draft';
    await repository.installSeed(jsonEncode(seed));
    await database.insert('catalog_option_schemas', {
      'version': 1,
      'id': 'value_label_options',
      'revision': 1,
      'payload_json': jsonEncode({
        'parameters': [parameter],
      }),
    });
    await database.insert('catalog_variant_metadata', {
      'version': 1,
      'template_id': 'standard_531',
      'variant_id': 'four_day',
      'revision': 1,
      'labels_json': jsonEncode({
        'en': 'Standard 5/3/1',
        'fr': '5/3/1 standard',
      }),
      'source_rule_ids_json': '[]',
      'option_schema_id': 'value_label_options',
      'schedule_ids_json': '[]',
      'compatibility_json': '{}',
      'valid_example_json': '{}',
    });
    await repository.publishDraft(1);
    final schema = await repository.loadEditorSchema(
      catalogVersion: 1,
      templateId: 'standard_531',
      variantId: 'four_day',
    );
    return schema.options.single;
  } finally {
    await database.close();
  }
}

Map<String, Object?> _parameter({
  String type = 'enumeration',
  List<Object?> allowedValues = const ['original', 'beyond'],
  List<Object?> valueLabels = const [
    {
      'value': 'original',
      'labels': {'en': 'Original', 'fr': 'Original'},
    },
    {
      'value': 'beyond',
      'labels': {'en': 'Beyond', 'fr': 'Beyond'},
    },
  ],
}) => {
  'id': 'generation',
  'type': type,
  'scope': 'global',
  'default': allowedValues.first,
  'minimum': null,
  'maximum': null,
  'step': null,
  'allowedValues': allowedValues,
  'valueLabels': valueLabels,
  'visibleWhen': {'type': 'always'},
  'enabledWhen': {'type': 'always'},
  'requiredWhen': {'type': 'always'},
};
