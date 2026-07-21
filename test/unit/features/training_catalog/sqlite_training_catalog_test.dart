import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late SqliteTrainingCatalog repository;
  late String seed;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, _) => SqliteTrainingCatalog.createSchema(db),
        version: 1,
      ),
    );
    repository = SqliteTrainingCatalog(database);
    seed = File('assets/catalog/standard_531_v1.json').readAsStringSync();
  });
  tearDown(() => database.close());

  test('installs and resolves the published four-day definition', () async {
    await repository.installSeed(seed);
    final definition = await repository.resolve(
      catalogVersion: 1,
      templateId: 'standard_531',
      variantId: 'four_day',
    );
    expect(definition.sessionMovementIds.map((id) => id.value), [
      'overhead_press',
      'deadlift',
      'bench_press',
      'squat',
    ]);
    expect(definition.weeks, hasLength(4));
    expect(definition.weeks[2].blocks.last.sets.last.repetitions.toJson(), {
      'type': 'amrap',
      'minimum': 1,
    });
    expect(definition.sourceReference, contains('2nd edition'));
  });

  test('schema exposes the stable catalog vocabulary', () async {
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = rows.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll(<String>{
        'catalog_versions',
        'sources',
        'movements',
        'components',
        'component_versions',
        'templates',
        'variants',
        'variant_components',
        'schedules',
        'schedule_sessions',
        'schedule_blocks',
        'prescriptions',
        'option_schemas',
        'assistance_plans',
        'assistance_slots',
        'conditioning_definitions',
        'forever_definitions',
      }),
    );
  });

  test('published catalog exposes a dynamic index and editor schema', () async {
    await repository.installSeed(seed.replaceFirst('"published"', '"draft"'));
    await database.insert('catalog_option_schemas', {
      'version': 1,
      'id': 'standard_options',
      'revision': 1,
      'payload_json': jsonEncode({
        'parameters': [
          {
            'id': 'include_deload',
            'type': 'boolean',
            'scope': 'global',
            'default': true,
            'minimum': null,
            'maximum': null,
            'step': null,
            'allowedValues': [true, false],
            'visibleWhen': {'type': 'always'},
            'enabledWhen': {'type': 'always'},
            'requiredWhen': {'type': 'always'},
          },
        ],
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
      'option_schema_id': 'standard_options',
      'schedule_ids_json': '[]',
      'compatibility_json': '{}',
      'valid_example_json': '{}',
    });
    await repository.publishDraft(1);
    final index = await repository.loadIndex(catalogVersion: 1);
    expect(index.templates.single.id, 'standard_531');
    expect(index.templates.single.labelFr, '5/3/1 standard');
    final editor = await repository.loadEditorSchema(
      catalogVersion: 1,
      templateId: 'standard_531',
      variantId: 'four_day',
    );
    expect(editor.options.single.id, 'include_deload');
    expect(editor.options.single.defaultValue, isTrue);
  });

  test('opens and seeds a real catalog.db file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hybrid_catalog_test_',
    );
    final path = '${directory.path}${Platform.pathSeparator}catalog.db';
    try {
      final fileRepository = await openCatalogDatabase(
        factory: databaseFactoryFfi,
        path: path,
        seedJson: seed,
      );
      final definition = await fileRepository.resolve(
        catalogVersion: 1,
        templateId: 'standard_531',
        variantId: 'four_day',
      );
      expect(definition.weeks, hasLength(4));
      await fileRepository.database.close();
      expect(File(path).existsSync(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('migrates catalog.db v1 with complete catalogue tables', () async {
    final directory = await Directory.systemTemp.createTemp(
      'catalog-db-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/catalog.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''CREATE TABLE catalog_versions(
          version INTEGER PRIMARY KEY, status TEXT NOT NULL,
          source_reference TEXT NOT NULL)'''),
      ),
    );
    await legacy.close();
    final migrated = await openCatalogDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(() => migrated.database.close());
    final tables = (await migrated.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((row) => row['name']);
    expect(
      tables,
      containsAll([
        'catalog_inventory',
        'catalog_option_schemas',
        'catalog_schedules_v2',
        'catalog_variant_metadata',
        'catalog_library_entries',
      ]),
    );
  });

  test('rejects unknown template or variant', () async {
    await repository.installSeed(seed);
    expect(
      repository.resolve(
        catalogVersion: 1,
        templateId: 'unknown',
        variantId: 'four_day',
      ),
      throwsA(isA<CatalogNotFoundException>()),
    );
    expect(
      repository.resolve(
        catalogVersion: 1,
        templateId: 'standard_531',
        variantId: 'unknown',
      ),
      throwsA(isA<CatalogNotFoundException>()),
    );
  });

  test('refuses resolution of a draft', () async {
    final json = jsonDecode(seed) as Map<String, Object?>;
    json['status'] = 'draft';
    await repository.installSeed(jsonEncode(json));
    expect(
      repository.resolve(
        catalogVersion: 1,
        templateId: 'standard_531',
        variantId: 'four_day',
      ),
      throwsA(isA<CatalogNotPublishedException>()),
    );
  });

  test('rejects an unknown movement reference before writing', () async {
    final json = jsonDecode(seed) as Map<String, Object?>;
    final template =
        (json['templates']! as List<Object?>).single as Map<String, Object?>;
    final variant =
        (template['variants']! as List<Object?>).single as Map<String, Object?>;
    final schedule = variant['schedule']! as Map<String, Object?>;
    schedule['movementIds'] = ['missing'];
    expect(
      repository.installSeed(jsonEncode(json)),
      throwsA(isA<CatalogFormatException>()),
    );
    expect(await database.query('catalog_versions'), isEmpty);
  });

  test('published versions are immutable', () async {
    await repository.installSeed(seed);
    expect(
      () => database.update(
        'catalog_movements',
        {'name': 'Changed'},
        where: 'version=?',
        whereArgs: [1],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => database.update(
        'catalog_versions',
        {'source_reference': 'Changed'},
        where: 'version=?',
        whereArgs: [1],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => database.insert('catalog_movements', {
        'version': 1,
        'id': 'row',
        'name': 'Row',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects orphaned catalog hierarchy rows', () async {
    expect(
      () => database.insert('catalog_weeks', {
        'version': 99,
        'template_id': 'missing',
        'variant_id': 'missing',
        'week_number': 1,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects an unsupported database schema version', () async {
    await repository.installSeed(seed);
    await database.update('catalog_metadata', {'schema_version': 2});
    expect(
      repository.resolve(
        catalogVersion: 1,
        templateId: 'standard_531',
        variantId: 'four_day',
      ),
      throwsA(isA<CatalogFormatException>()),
    );
  });

  test('publishes v2 while keeping published v1 intact and readable', () async {
    await repository.installSeed(seed);
    final v2Json =
        jsonDecode(
              File(
                'assets/catalog/standard_531_bbb_v2.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    v2Json['status'] = 'draft';
    await repository.installSeed(jsonEncode(v2Json));

    expect(
      repository.resolve(
        catalogVersion: 2,
        templateId: 'bbb_original',
        variantId: 'four_day_same_lift_50',
      ),
      throwsA(isA<CatalogNotPublishedException>()),
    );
    await repository.validateDraft(2);
    await repository.publishDraft(2);

    final v1 = await repository.resolve(
      catalogVersion: 1,
      templateId: 'standard_531',
      variantId: 'four_day',
    );
    final bbb = await repository.resolve(
      catalogVersion: 2,
      templateId: 'bbb_original',
      variantId: 'four_day_same_lift_50',
    );
    expect(v1.weeks, hasLength(4));
    expect(bbb.weeks.first.blocks.last.role, 'supplemental');
    expect(bbb.weeks.first.blocks.last.sets, hasLength(5));
    expect(
      () => database.update(
        'catalog_components',
        {'block_json': '{}'},
        where: 'version=?',
        whereArgs: [2],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'clones a published version as an independently publishable draft',
    () async {
      await repository.installSeed(seed);
      await repository.createDraftFromPublished(
        sourceVersion: 1,
        draftVersion: 2,
      );
      expect(
        repository.resolve(
          catalogVersion: 2,
          templateId: 'standard_531',
          variantId: 'four_day',
        ),
        throwsA(isA<CatalogNotPublishedException>()),
      );
      await database.update(
        'catalog_templates',
        {'name': 'Standard copied draft'},
        where: 'version=? AND id=?',
        whereArgs: [2, 'standard_531'],
      );
      await repository.publishDraft(2);
      final original = await database.query(
        'catalog_templates',
        columns: ['name'],
        where: 'version=? AND id=?',
        whereArgs: [1, 'standard_531'],
      );
      expect(original.single['name'], 'Standard 5/3/1');
    },
  );
}
