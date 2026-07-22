import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/data/runtime_catalog_builder.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late SqliteTrainingCatalog repository;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => SqliteTrainingCatalog.createSchema(db),
      ),
    );
    repository = SqliteTrainingCatalog(database);
  });
  tearDown(() => database.close());

  test(
    'publisher persists aliases and option recipes as exact payloads',
    () async {
      final alias = {
        'legacyTemplateId': 'legacy',
        'legacyVariantId': 'phase_1',
        'templateId': 'canonical',
        'variantId': 'original',
        'optionOverrides': {'phase': 'phase_one'},
      };
      final recipe = {
        'id': 'classic_additional_options',
        'revision': 1,
        'warmUp': <String, Object?>{},
        'joker': <String, Object?>{},
        'deload': <String, Object?>{},
      };
      await const RuntimeCatalogPublisher().publish(
        aggregate: {
          'schemaVersion': 1,
          'catalogVersion': 1,
          'status': 'published',
          'documents': [
            {
              'content': {
                'schemaVersion': 1,
                'kind': 'templateAliases',
                'templateAliases': [alias],
              },
            },
            {
              'content': {
                'schemaVersion': 1,
                'kind': 'cycleOptionRecipes',
                'cycleOptionRecipes': [recipe],
              },
            },
          ],
        },
        database: database,
      );
      final rows = await database.query(
        'catalog_library_entries',
        orderBy: 'kind',
      );
      expect(rows.map((row) => row['kind']), [
        'cycle_option_recipe',
        'template_alias',
      ]);
      expect(jsonDecode(rows[0]['payload_json']! as String), recipe);
      expect(jsonDecode(rows[1]['payload_json']! as String), alias);
    },
  );

  test(
    'index excludes internal templates from persisted surface payload',
    () async {
      await database.insert('catalog_versions', {
        'version': 1,
        'status': 'draft',
        'source_reference': 'test',
      });
      for (final entry in const {
        'public': 'cyclePublic',
        'internal': 'foreverInternal',
      }.entries) {
        await database.insert('catalog_templates', {
          'version': 1,
          'id': entry.key,
          'name': entry.key,
        });
        await database.insert('catalog_variants', {
          'version': 1,
          'template_id': entry.key,
          'id': 'v',
          'name': 'v',
        });
        await database.insert('catalog_library_entries', {
          'version': 1,
          'kind': 'template_definition',
          'id': entry.key,
          'revision': 1,
          'payload_json': jsonEncode({'id': entry.key, 'surface': entry.value}),
        });
      }
      await database.update(
        'catalog_versions',
        {'status': 'published'},
        where: 'version=?',
        whereArgs: [1],
      );
      final index = await repository.loadIndex(catalogVersion: 1);
      expect(index.templates.map((item) => item.id), ['public']);
    },
  );

  test(
    'editor lookup applies persisted aliases before metadata lookup',
    () async {
      await database.insert('catalog_versions', {
        'version': 1,
        'status': 'draft',
        'source_reference': 'test',
      });
      await database.insert('catalog_templates', {
        'version': 1,
        'id': 'canonical',
        'name': 'Canonical',
      });
      await database.insert('catalog_variants', {
        'version': 1,
        'template_id': 'canonical',
        'id': 'original',
        'name': 'Original',
      });
      await database.insert('catalog_option_schemas', {
        'version': 1,
        'id': 'options',
        'revision': 1,
        'payload_json': jsonEncode({'parameters': <Object?>[]}),
      });
      await database.insert('catalog_variant_metadata', {
        'version': 1,
        'template_id': 'canonical',
        'variant_id': 'original',
        'revision': 1,
        'labels_json': '{}',
        'source_rule_ids_json': '[]',
        'option_schema_id': 'options',
        'schedule_ids_json': '[]',
        'compatibility_json': '{}',
        'valid_example_json': '{}',
      });
      await database.insert('catalog_library_entries', {
        'version': 1,
        'kind': 'template_alias',
        'id': 'legacy/phase_1',
        'revision': 1,
        'payload_json': jsonEncode({
          'legacyTemplateId': 'legacy',
          'legacyVariantId': 'phase_1',
          'templateId': 'canonical',
          'variantId': 'original',
          'optionOverrides': {'phase': 'phase_one'},
        }),
      });
      await database.update(
        'catalog_versions',
        {'status': 'published'},
        where: 'version=?',
        whereArgs: [1],
      );
      final schema = await repository.loadEditorSchema(
        catalogVersion: 1,
        templateId: 'legacy',
        variantId: 'phase_1',
      );
      expect(schema.templateId, 'canonical');
      expect(schema.variantId, 'original');
    },
  );
}
