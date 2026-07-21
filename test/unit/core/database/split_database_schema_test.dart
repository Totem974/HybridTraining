import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/catalog/catalog_administration_database.dart';
import 'package:hybrid_training/core/database/catalog/catalog_database_schema.dart';
import 'package:hybrid_training/core/database/catalog/catalog_publication_service.dart';
import 'package:hybrid_training/core/database/split_local_databases.dart';
import 'package:hybrid_training/core/database/training/training_plan_snapshot_repository.dart';
import 'package:hybrid_training/core/database/training/training_plan_status_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('canonical catalog hashing is SHA-256', () {
    expect(
      CatalogCanonicalHasher.sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test(
    'creates three physical databases with disjoint responsibilities',
    () async {
      final root = await Directory.systemTemp.createTemp('split-db-');
      addTearDown(() => root.delete(recursive: true));
      final databases = SplitLocalDatabases(
        rootPath: root.path,
        factory: databaseFactoryFfi,
      );
      await CatalogAdministrationDatabase(
        path: '${root.path}/catalog.db',
        publicationService: const CatalogPublicationService(),
        factory: databaseFactoryFfi,
      ).initialize();
      final catalog = await databases.openCatalog();
      final workspace = await databases.openWorkspace();
      final training = await databases.openTraining();
      addTearDown(() async {
        await catalog.close();
        await workspace.close();
        await training.close();
      });

      expect(
        await _tables(catalog),
        containsAll({
          'catalog_versions',
          'catalog_entries',
          'sources',
          'templates',
          'modules',
          'movements',
          'policies',
        }),
      );
      expect(
        await _tables(workspace),
        containsAll({
          'athlete_profiles',
          'weight_profiles',
          'gyms',
          'bars',
          'plates',
          'workspace_drafts',
          'custom_definitions',
        }),
      );
      expect(
        await _tables(training),
        containsAll({
          'plans',
          'sessions',
          'session_blocks',
          'set_prescriptions',
          'set_results',
          'training_events',
          'plan_statistics',
        }),
      );
      expect(await _tables(catalog), isNot(contains('athlete_profiles')));
      expect(await _tables(workspace), isNot(contains('plans')));
      expect(await _tables(training), isNot(contains('catalog_versions')));
    },
  );

  test(
    'published catalog content is immutable and a child draft is editable',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'hash-1');
      await db.insert('catalog_entries', _documentaryEntry());
      await db.insert('catalog_import_blockers', {
        'id': 'retained-warning',
        'catalog_version_id': 'v1',
        'catalog_entry_key': null,
        'issue_code': 'historical_warning',
        'severity': 'warning',
        'message': 'Retained non-blocking administration history.',
      });
      await db.insert('movement_categories', {
        'id': 'category-1',
        'catalog_version_id': 'v1',
        'stable_key': 'push',
      });
      await _publish(db, 'v1');
      await expectLater(
        db.update(
          'catalog_versions',
          {'signature_verified': 1},
          where: 'id=?',
          whereArgs: ['v1'],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.update(
          'catalog_publication_validations',
          {'validated_at': 'changed'},
          where: 'catalog_version_id=?',
          whereArgs: ['v1'],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.delete(
          'catalog_publication_validations',
          where: 'catalog_version_id=?',
          whereArgs: ['v1'],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.delete(
          'catalog_import_blockers',
          where: 'catalog_version_id=?',
          whereArgs: ['v1'],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.update(
          'movement_categories',
          {'stable_key': 'pull'},
          where: 'id=?',
          whereArgs: ['category-1'],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.insert('movement_categories', {
          'id': 'category-2',
          'catalog_version_id': 'v1',
          'stable_key': 'pull',
        }),
        throwsA(anything),
      );

      await _version(db, id: 'v2', ordinal: 2, hash: 'hash-2', parent: 'v1');
      await db.insert('movement_categories', {
        'id': 'category-2',
        'catalog_version_id': 'v2',
        'stable_key': 'pull',
      });
      expect(
        await db.query(
          'movement_categories',
          where: 'catalog_version_id=?',
          whereArgs: ['v2'],
        ),
        hasLength(1),
      );
    },
  );

  test('runtime catalog facade is physically read-only', () async {
    final root = await Directory.systemTemp.createTemp('catalog-read-only-');
    addTearDown(() => root.delete(recursive: true));
    final path = '${root.path}/catalog.db';
    await CatalogAdministrationDatabase(
      path: path,
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    ).initialize();
    final runtime = await SplitLocalDatabases(
      rootPath: root.path,
      factory: databaseFactoryFfi,
    ).openCatalog();
    addTearDown(runtime.close);

    expect(await _tables(runtime), contains('catalog_versions'));
    await expectLater(
      runtime.insert('catalog_versions', {
        'id': 'forbidden',
        'ordinal': 1,
        'status': 'draft',
        'content_hash': 'h',
        'canonicalization_version': 1,
        'trust_channel': 'localReview',
        'created_at': '2026-07-21',
      }),
      throwsA(anything),
    );
  });

  test(
    'catalog schema v1 migration adds isolated staging without data loss',
    () async {
      final root = await Directory.systemTemp.createTemp('catalog-migration-');
      addTearDown(() => root.delete(recursive: true));
      final path = '${root.path}/catalog.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) async {
            await db.execute('''CREATE TABLE catalog_versions (
            id TEXT PRIMARY KEY, status TEXT NOT NULL, content_hash TEXT NOT NULL
          )''');
            await db.execute('''CREATE TABLE catalog_publication_validations (
            catalog_version_id TEXT PRIMARY KEY
          )''');
            await db.execute('''CREATE TABLE catalog_entries (
            id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL,
            catalog_entry_key TEXT NOT NULL, stable_domain_id TEXT NOT NULL,
            authority TEXT NOT NULL
          )''');
          },
        ),
      );
      await legacy.insert('catalog_versions', {
        'id': 'legacy-v1',
        'status': 'draft',
        'content_hash': 'legacy-hash',
      });
      await legacy.insert('catalog_entries', {
        'id': 'legacy-entry',
        'catalog_version_id': 'legacy-v1',
        'catalog_entry_key': 'OR-001',
        'stable_domain_id': 'legacy-entry',
        'authority': 'canonical',
      });
      await legacy.close();

      final migrated = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: CatalogDatabaseSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onUpgrade: CatalogDatabaseSchema.migrate,
        ),
      );
      addTearDown(migrated.close);

      expect(await _tables(migrated), contains('catalog_staging_entries'));
      expect(await _tables(migrated), contains('catalog_import_blockers'));
      expect(
        (await migrated.query('catalog_entries')).single['id'],
        'legacy-entry',
      );
      expect(
        (await migrated.rawQuery('PRAGMA user_version')).single['user_version'],
        CatalogDatabaseSchema.version,
      );
    },
  );

  test('staged versions cannot bypass governed promotion gates', () async {
    final root = await Directory.systemTemp.createTemp('catalog-gates-');
    addTearDown(() => root.delete(recursive: true));
    final path = '${root.path}/catalog.db';
    final administration = CatalogAdministrationDatabase(
      path: path,
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    );
    await administration.transaction((transaction) async {
      await transaction.insertDraftVersion(
        const CatalogDraftVersion(
          id: 'staging-v1',
          ordinal: 1,
          status: 'inReview',
          contentHash: 'manifest-hash',
          canonicalizationVersion: 1,
          signatureVerified: false,
          trustChannel: 'localReview',
          createdAt: '2026-07-21T00:00:00Z',
        ),
      );
      await transaction.insertEntry(
        const CatalogEntryWrite(
          catalogVersionId: 'staging-v1',
          catalogEntryKey: 'OR-001',
          canonicalRecordJson: '{"catalogEntryKey":"OR-001"}',
          recordHash: 'record-hash',
          manifestHash: 'manifest-hash',
          stableDomainId: null,
          authority: null,
          reviewStatus: 'needsReview',
          visibility: 'hidden',
          executionStatus: 'blocked',
        ),
      );
    });

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(database.close);
    await expectLater(
      database.update(
        'catalog_versions',
        {'status': 'approved'},
        where: 'id=?',
        whereArgs: ['staging-v1'],
      ),
      throwsA(anything),
    );
    await expectLater(
      database.insert('catalog_publication_validations', {
        'catalog_version_id': 'staging-v1',
        'validated_content_hash': 'manifest-hash',
        'evidence_valid': 1,
        'licences_valid': 1,
        'dependencies_valid': 1,
        'children_valid': 1,
        'blockers_clear': 1,
        'signature_valid': 0,
        'validated_at': '2026-07-21T01:00:00Z',
      }),
      throwsA(anything),
    );
    expect(await database.query('catalog_publication_validations'), isEmpty);
    expect(
      (await database.query('catalog_versions')).single['status'],
      'inReview',
    );
  });

  test('global import blockers prevent approval and validation', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: CatalogDatabaseSchema.version,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
    addTearDown(db.close);
    await _version(db, id: 'blocked-v1', ordinal: 1, hash: 'manifest-hash');
    await db.insert('catalog_import_blockers', {
      'id': 'global-blocker',
      'catalog_version_id': 'blocked-v1',
      'catalog_entry_key': null,
      'issue_code': 'manifest_authority_missing',
      'severity': 'publishBlocker',
      'message': 'Global reviewed authority is missing.',
    });
    await db.update(
      'catalog_versions',
      {'status': 'inReview'},
      where: 'id=?',
      whereArgs: ['blocked-v1'],
    );

    await expectLater(
      db.update(
        'catalog_versions',
        {'status': 'approved'},
        where: 'id=?',
        whereArgs: ['blocked-v1'],
      ),
      throwsA(anything),
    );
    await expectLater(
      db.insert('catalog_publication_validations', {
        'catalog_version_id': 'blocked-v1',
        'validated_content_hash': 'manifest-hash',
        'evidence_valid': 1,
        'licences_valid': 1,
        'dependencies_valid': 1,
        'children_valid': 1,
        'blockers_clear': 1,
        'signature_valid': 0,
        'validated_at': '2026-07-21T01:00:00Z',
      }),
      throwsA(anything),
    );
    expect(await db.query('catalog_publication_validations'), isEmpty);
  });

  test(
    'administration staging and blockers are excluded from governed hash',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: CatalogDatabaseSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'hash-v1', ordinal: 1, hash: 'manifest-hash');
      const service = CatalogPublicationService();
      final before = await service.computeContentHash(
        db,
        catalogVersionId: 'hash-v1',
      );
      await db.insert('catalog_staging_entries', {
        'catalog_version_id': 'hash-v1',
        'catalog_entry_key': 'OR-001',
        'canonical_record_json': '{"catalogEntryKey":"OR-001"}',
        'record_hash': 'record-hash',
        'manifest_hash': 'manifest-hash',
        'stable_domain_id': null,
        'authority': null,
        'review_status': 'needsReview',
        'visibility': 'hidden',
        'execution_status': 'blocked',
      });
      await db.insert('catalog_import_blockers', {
        'id': 'hash-global-warning',
        'catalog_version_id': 'hash-v1',
        'catalog_entry_key': null,
        'issue_code': 'warning_only',
        'severity': 'warning',
        'message': 'Administrative warning.',
      });

      expect(
        await service.computeContentHash(db, catalogVersionId: 'hash-v1'),
        before,
      );
    },
  );

  test(
    'publication service fails closed on persisted blocking issues',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: CatalogDatabaseSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'service-v1', ordinal: 1, hash: 'placeholder');
      await db.insert(
        'catalog_entries',
        _documentaryEntry()..['catalog_version_id'] = 'service-v1',
      );
      await db.insert('catalog_import_blockers', {
        'id': 'service-global-blocker',
        'catalog_version_id': 'service-v1',
        'catalog_entry_key': null,
        'issue_code': 'global_review_missing',
        'severity': 'error',
        'message': 'Global review failed.',
      });
      const service = CatalogPublicationService();
      await db.update('catalog_versions', {
        'content_hash': await service.computeContentHash(
          db,
          catalogVersionId: 'service-v1',
        ),
      });
      await db.update('catalog_versions', {'status': 'inReview'});
      // Simulate a legacy/corrupt database that bypassed the schema transition
      // gate. The publication service must still fail closed independently.
      await db.execute('DROP TRIGGER catalog_staging_promotion_gate');
      await db.update('catalog_versions', {'status': 'approved'});

      await expectLater(
        service.publish(
          db,
          catalogVersionId: 'service-v1',
          publishedAt: '2026-07-21T02:00:00Z',
        ),
        throwsA(
          isA<CatalogPublicationException>().having(
            (error) => error.issues,
            'issues',
            containsAll([
              'blockers.not_clear',
              'blocker.global_review_missing',
            ]),
          ),
        ),
      );
      expect(await db.query('catalog_publication_validations'), isEmpty);
      expect((await db.query('catalog_versions')).single['status'], 'approved');
    },
  );

  test(
    'catalog constraints reject invalid blocked variants and prescriptions',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'hash');
      await expectLater(
        db.insert('variants', {
          'id': 'orphan',
          'catalog_version_id': 'v1',
          'template_id': 'missing',
          'stable_key': 'x',
          'status': 'blocked',
        }),
        throwsA(anything),
      );
      await expectLater(
        db.insert('prescriptions', {
          'id': 'p',
          'catalog_version_id': 'v1',
          'block_id': 'missing',
          'movement_id': 'missing',
          'sequence': -1,
          'kind': 'magic',
          'repetition_target_kind': 'zero',
          'load_kind': 'unknown',
          'prescription_json': '{}',
        }),
        throwsA(anything),
      );
    },
  );

  test('runtime view admits only governed executable entries', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
    addTearDown(db.close);
    await _version(db, id: 'v1', ordinal: 1, hash: 'hash');
    await db.insert(
      'catalog_entries',
      _entry('entry-standard', 'OR-001', 'standard-531'),
    );
    await _runtimeGraph(db);
    await db.insert(
      'catalog_entries',
      _entry(
        'entry-hidden',
        'FV-142',
        'forever-bbb',
        visibility: 'hidden',
        execution: 'supported',
      ),
    );
    await db.insert(
      'catalog_entries',
      _entry(
        'entry-restricted',
        'FV-143',
        'forever-bbb-3-day',
        visibility: 'internal',
        license: 'restricted',
        execution: 'supported',
      ),
    );
    await _publish(db, 'v1');

    expect(
      (await db.query('runtime_catalog_entries')).map((row) => row['id']),
      ['entry-standard'],
    );
  });

  test(
    'historical keys stay uppercase while stable IDs reject uppercase',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'hash');
      await db.insert(
        'catalog_entries',
        _entry('entry-valid', 'OR-001', 'standard-531'),
      );
      await expectLater(
        db.insert(
          'catalog_entries',
          _entry('entry-bad', 'OR-002', 'Standard-531'),
        ),
        throwsA(anything),
      );
      expect(
        (await db.query('catalog_entries')).single['catalog_entry_key'],
        'OR-001',
      );
      await expectLater(
        db.insert('templates', {
          'id': 'bad-template',
          'catalog_version_id': 'v1',
          'catalog_entry_id': 'entry-valid',
          'stable_key': 'Bad_ID',
          'revision': 1,
          'kind': 'cycle',
          'name_key': 'bad',
        }),
        throwsA(anything),
      );
    },
  );

  test('P0 catalog graph round-trips without semantic side channels', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
    addTearDown(db.close);
    await _version(db, id: 'v1', ordinal: 1, hash: 'hash');
    await db.insert(
      'catalog_entries',
      _entry('entry-standard', 'OR-001', 'standard-531'),
    );
    await db.insert(
      'catalog_entries',
      _entry('entry-assistance', 'OR-002', 'standard-assistance'),
    );
    await _runtimeGraph(db);
    final hashBefore = await const CatalogPublicationService()
        .computeContentHash(db, catalogVersionId: 'v1');
    await _p0Graph(db);
    final hashAfter = await const CatalogPublicationService()
        .computeContentHash(db, catalogVersionId: 'v1');

    expect(hashBefore, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(hashAfter, isNot(hashBefore));
    expect(
      await const CatalogPublicationService().computeContentHash(
        db,
        catalogVersionId: 'v1',
      ),
      hashAfter,
    );
    expect(
      (await db.query('catalog_entry_relations')).single['kind'],
      'dependency',
    );
    expect(
      (await db.query('engine_binding_migration_aliases')).single['alias'],
      'standard-531-v1',
    );
    expect(
      (await db.query('schedule_segments')).single,
      containsPair('kind', 'training'),
    );
    expect(
      (await db.query('finite_program_transitions')).single,
      containsPair('kind', 'add'),
    );
    expect(
      (await db.query('assistance_slots')).single,
      allOf(
        containsPair('minimum_selections', 1),
        containsPair('maximum_selections', 2),
      ),
    );
    expect(
      (await db.query('conditioning_modalities')).single['modality'],
      'intervals',
    );
    expect(
      (await db.query('movement_capabilities')).single['capability_id'],
      'barbell-load',
    );
  });

  test(
    'same-version guards reject cross-version references and identity moves',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'hash-1');
      await _version(db, id: 'v2', ordinal: 2, hash: 'hash-2', parent: 'v1');
      await db.insert(
        'catalog_entries',
        _entry('entry-a', 'OR-001', 'entry-a'),
      );
      await db.insert('movement_categories', {
        'id': 'category-v2',
        'catalog_version_id': 'v2',
        'stable_key': 'push',
      });
      await expectLater(
        db.insert('movements', {
          'id': 'movement-bad',
          'catalog_version_id': 'v1',
          'catalog_entry_id': 'entry-a',
          'stable_key': 'press',
          'category_id': 'category-v2',
          'kind': 'mainLift',
          'body_region': 'upper',
        }),
        throwsA(anything),
      );
      await db.insert('movement_categories', {
        'id': 'category-v1',
        'catalog_version_id': 'v1',
        'stable_key': 'pull',
      });
      await expectLater(
        db.update(
          'movement_categories',
          {'catalog_version_id': 'v2'},
          where: 'id=?',
          whereArgs: ['category-v1'],
        ),
        throwsA(anything),
      );
      await db.insert(
        'catalog_entries',
        _entry('entry-v2', 'OR-002', 'entry-v2', versionId: 'v2'),
      );
      await db.insert('templates', {
        'id': 'template-a',
        'catalog_version_id': 'v1',
        'catalog_entry_id': 'entry-a',
        'stable_key': 'template-a',
        'revision': 1,
        'kind': 'cycle',
        'name_key': 'a',
      });
      await db.insert('templates', {
        'id': 'template-v2',
        'catalog_version_id': 'v2',
        'catalog_entry_id': 'entry-v2',
        'stable_key': 'template-v2',
        'revision': 1,
        'kind': 'cycle',
        'name_key': 'v2',
      });
      await db.insert('variants', {
        'id': 'variant-a',
        'catalog_version_id': 'v1',
        'template_id': 'template-a',
        'stable_key': 'base',
        'status': 'executable',
      });
      await db.insert('variants', {
        'id': 'variant-v2',
        'catalog_version_id': 'v2',
        'template_id': 'template-v2',
        'stable_key': 'base',
        'status': 'executable',
      });
      await db.insert('engine_bindings', {
        'id': 'binding-a',
        'catalog_version_id': 'v1',
        'variant_id': 'variant-a',
        'engine_kind': 'cycleV5',
        'engine_id': 'engine-a',
        'definition_id': 'a',
        'definition_revision': 1,
        'status': 'executable',
      });
      await expectLater(
        db.update(
          'engine_bindings',
          {'definition_revision': 2},
          where: 'id=?',
          whereArgs: ['binding-a'],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.insert('engine_binding_variants', {
          'id': 'cross-engine-variant',
          'catalog_version_id': 'v1',
          'engine_binding_id': 'binding-a',
          'variant_id': 'variant-v2',
          'status': 'supported',
        }),
        throwsA(anything),
      );
    },
  );

  test(
    'publication requires confirmed evidence for executable children',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'placeholder');
      await db.insert(
        'catalog_entries',
        _entry('entry-standard', 'OR-001', 'standard-531'),
      );
      await _runtimeGraph(db);
      await db.delete(
        'evidence',
        where: 'id=?',
        whereArgs: ['evidence-template-1'],
      );
      await db.insert('modules', {
        'id': 'module-proof',
        'stable_key': 'proof-module',
        'kind': 'main',
      });
      await db.insert('module_versions', {
        'id': 'module-proof-v1',
        'catalog_version_id': 'v1',
        'catalog_entry_id': 'entry-standard',
        'module_id': 'module-proof',
        'revision': 1,
        'definition_json': '{}',
        'review_status': 'confirmed',
      });
      await db.insert('movement_categories', {
        'id': 'category-proof',
        'catalog_version_id': 'v1',
        'stable_key': 'proof-category',
      });
      await db.insert('movements', {
        'id': 'movement-proof',
        'catalog_version_id': 'v1',
        'catalog_entry_id': 'entry-standard',
        'stable_key': 'proof-movement',
        'category_id': 'category-proof',
        'kind': 'exercise',
        'body_region': 'fullBody',
      });
      final service = const CatalogPublicationService();
      final hash = await service.computeContentHash(db, catalogVersionId: 'v1');
      await db.update(
        'catalog_versions',
        {'content_hash': hash},
        where: 'id=?',
        whereArgs: ['v1'],
      );
      await db.update(
        'catalog_versions',
        {'status': 'inReview'},
        where: 'id=?',
        whereArgs: ['v1'],
      );
      await db.update(
        'catalog_versions',
        {'status': 'approved'},
        where: 'id=?',
        whereArgs: ['v1'],
      );

      try {
        await service.publish(
          db,
          catalogVersionId: 'v1',
          publishedAt: '2026-07-21',
        );
        fail('Executable children without evidence must block publication.');
      } on CatalogPublicationException catch (error) {
        expect(error.issues, contains('template.template-1.evidence'));
        expect(
          error.issues,
          contains('moduleVersion.module-proof-v1.evidence'),
        );
        expect(error.issues, contains('movement.movement-proof.evidence'));
      }
    },
  );

  test(
    'publication requires evidence for every executable graph type',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'placeholder');
      await db.insert(
        'catalog_entries',
        _entry('entry-standard', 'OR-001', 'standard-531'),
      );
      await _runtimeGraph(db);
      await db.insert('variants', {
        'id': 'variant-unsourced',
        'catalog_version_id': 'v1',
        'template_id': 'template-1',
        'stable_key': 'unsourced',
        'status': 'executable',
      });
      await db.insert('schedules', {
        'id': 'schedule-unsourced',
        'catalog_version_id': 'v1',
        'variant_id': 'variant-unsourced',
        'stable_key': 'unsourced-schedule',
        'duration_weeks': 1,
        'days_per_week': 1,
      });
      await db.insert('finite_programs', {
        'id': 'program-unsourced',
        'catalog_version_id': 'v1',
        'template_id': 'template-1',
        'stable_key': 'unsourced-program',
      });
      await db.insert('assistance_plans', {
        'id': 'assistance-unsourced',
        'catalog_version_id': 'v1',
        'variant_id': 'variant-unsourced',
        'stable_key': 'unsourced-assistance',
        'deload_mode': 'omit',
      });
      await db.insert('policies', {
        'id': 'policy-unsourced',
        'catalog_version_id': 'v1',
        'variant_id': 'variant-unsourced',
        'kind': 'warmup',
        'policy_json': '{}',
        'review_status': 'confirmed',
      });
      final service = const CatalogPublicationService();
      final hash = await service.computeContentHash(db, catalogVersionId: 'v1');
      await db.update('catalog_versions', {'content_hash': hash});
      await db.update('catalog_versions', {'status': 'inReview'});
      await db.update('catalog_versions', {'status': 'approved'});

      try {
        await service.publish(
          db,
          catalogVersionId: 'v1',
          publishedAt: '2026-07-21',
        );
        fail('Every executable graph type must carry confirmed evidence.');
      } on CatalogPublicationException catch (error) {
        expect(error.issues, contains('variant.variant-unsourced.evidence'));
        expect(error.issues, contains('schedule.schedule-unsourced.evidence'));
        expect(
          error.issues,
          contains('finiteProgram.program-unsourced.evidence'),
        );
        expect(
          error.issues,
          contains('assistancePlan.assistance-unsourced.evidence'),
        );
        expect(error.issues, contains('policy.policy-unsourced.evidence'));
      }
      expect(await db.query('catalog_publication_validations'), isEmpty);
      expect((await db.query('catalog_versions')).single['status'], 'approved');
    },
  );

  test('published source graph and module definitions are immutable', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
    addTearDown(db.close);
    await _version(db, id: 'v1', ordinal: 1, hash: 'placeholder');
    await db.insert('books', {
      'id': 'book-1',
      'title': 'Owned reference',
      'license_status': 'ownedReference',
    });
    await db.insert('editions', {
      'id': 'edition-1',
      'book_id': 'book-1',
      'label': 'First',
    });
    await db.insert(
      'catalog_entries',
      _entry('entry-standard', 'OR-001', 'standard-531'),
    );
    await _runtimeGraph(db);
    await db.update(
      'sources',
      {'edition_id': 'edition-1'},
      where: 'id=?',
      whereArgs: ['source-1'],
    );
    await db.insert('modules', {
      'id': 'module-immutable',
      'stable_key': 'immutable-module',
      'kind': 'main',
    });
    await db.insert('module_versions', {
      'id': 'module-immutable-v1',
      'catalog_version_id': 'v1',
      'catalog_entry_id': 'entry-standard',
      'module_id': 'module-immutable',
      'revision': 1,
      'definition_json': '{}',
      'review_status': 'confirmed',
    });
    await db.insert('evidence', {
      'id': 'evidence-module-immutable',
      'catalog_version_id': 'v1',
      'source_id': 'source-1',
      'rule_id': 'immutable-module-rule',
      'subject_type': 'moduleVersion',
      'subject_id': 'module-immutable-v1',
      'review_status': 'confirmed',
    });
    await _publish(db, 'v1');
    final hash = await const CatalogPublicationService().computeContentHash(
      db,
      catalogVersionId: 'v1',
    );

    for (final mutation in <Future<int> Function()>[
      () => db.update('books', {'title': 'Tampered'}),
      () => db.update('editions', {'label': 'Tampered'}),
      () => db.update('sources', {'locator': 'Tampered'}),
      () => db.update('modules', {'kind': 'other'}),
    ]) {
      await expectLater(mutation(), throwsA(anything));
    }
    expect(
      await const CatalogPublicationService().computeContentHash(
        db,
        catalogVersionId: 'v1',
      ),
      hash,
    );
  });

  test('declarative rules require valid JSON and confirmed evidence', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
    addTearDown(db.close);
    await _version(db, id: 'v1', ordinal: 1, hash: 'placeholder');
    await db.insert(
      'catalog_entries',
      _entry('entry-standard', 'OR-001', 'standard-531'),
    );
    await _runtimeGraph(db);
    await expectLater(
      db.insert('declarative_rules', {
        'id': 'invalid-json-rule',
        'catalog_version_id': 'v1',
        'owner_type': 'variant',
        'owner_id': 'variant-1',
        'kind': 'required',
        'expression_json': '{',
      }),
      throwsA(anything),
    );
    await db.insert('declarative_rules', {
      'id': 'unsourced-rule',
      'catalog_version_id': 'v1',
      'owner_type': 'variant',
      'owner_id': 'variant-1',
      'kind': 'required',
      'expression_json': '{}',
    });
    final service = const CatalogPublicationService();
    final hash = await service.computeContentHash(db, catalogVersionId: 'v1');
    await db.update('catalog_versions', {'content_hash': hash});
    await db.update('catalog_versions', {'status': 'inReview'});
    await db.update('catalog_versions', {'status': 'approved'});
    await expectLater(
      service.publish(db, catalogVersionId: 'v1', publishedAt: '2026-07-21'),
      throwsA(
        isA<CatalogPublicationException>().having(
          (error) => error.issues,
          'issues',
          contains('rule.unsourced-rule.evidence'),
        ),
      ),
    );
    expect((await db.query('catalog_versions')).single['status'], 'approved');
    expect(await db.query('catalog_publication_validations'), isEmpty);
  });

  test('signed remote publication trusts only the injected verifier', () async {
    Future<List<String>> attempt({
      required String keyId,
      required String signature,
      bool tamper = false,
    }) async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => CatalogDatabaseSchema.create(db),
        ),
      );
      addTearDown(db.close);
      await _version(db, id: 'v1', ordinal: 1, hash: 'placeholder');
      await db.update('catalog_versions', {
        'trust_channel': 'signedRemote',
        'signature': signature,
        'signature_key_id': keyId,
        'signature_algorithm': 'ed25519',
        // Imported state is deliberately adversarial and must be ignored.
        'signature_verified': 1,
      });
      await db.insert(
        'catalog_entries',
        _entry('entry-standard', 'OR-001', 'standard-531'),
      );
      await _runtimeGraph(db);
      const service = CatalogPublicationService(
        signatureVerifier: _TestSignatureVerifier(),
      );
      final hash = await service.computeContentHash(db, catalogVersionId: 'v1');
      await db.update('catalog_versions', {'content_hash': hash});
      if (tamper) {
        await db.update('templates', {'name_key': 'tampered'});
      }
      await db.update('catalog_versions', {'status': 'inReview'});
      await db.update('catalog_versions', {'status': 'approved'});
      try {
        await service.publish(
          db,
          catalogVersionId: 'v1',
          publishedAt: '2026-07-21',
        );
        return const [];
      } on CatalogPublicationException catch (error) {
        expect(await db.query('catalog_publication_validations'), isEmpty);
        return error.issues;
      }
    }

    expect(
      await attempt(keyId: 'known-key', signature: 'garbage'),
      contains('version.signature_unverified'),
    );
    expect(
      await attempt(keyId: 'unknown-key', signature: 'valid-signature'),
      contains('version.signature_unverified'),
    );
    expect(
      await attempt(
        keyId: 'known-key',
        signature: 'valid-signature',
        tamper: true,
      ),
      contains('version.hash_mismatch'),
    );
  });

  test('publication gate and JSON boundaries fail closed', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
    addTearDown(db.close);
    await _version(db, id: 'v1', ordinal: 1, hash: 'hash');
    await db.update(
      'catalog_versions',
      {'status': 'inReview'},
      where: 'id=?',
      whereArgs: ['v1'],
    );
    await db.update(
      'catalog_versions',
      {'status': 'approved'},
      where: 'id=?',
      whereArgs: ['v1'],
    );
    await expectLater(
      db.update(
        'catalog_versions',
        {'status': 'published', 'published_at': '2026-07-21'},
        where: 'id=?',
        whereArgs: ['v1'],
      ),
      throwsA(anything),
    );
    await db.insert('catalog_entries', _entry('entry-a', 'OR-001', 'entry-a'));
    await db.insert('catalog_entries', _entry('entry-b', 'OR-002', 'entry-b'));
    await db.insert('catalog_entry_relations', {
      'id': 'edge-a-b',
      'catalog_version_id': 'v1',
      'from_entry_id': 'entry-a',
      'to_entry_id': 'entry-b',
      'kind': 'dependency',
    });
    await expectLater(
      db.insert('catalog_entry_relations', {
        'id': 'edge-b-a',
        'catalog_version_id': 'v1',
        'from_entry_id': 'entry-b',
        'to_entry_id': 'entry-a',
        'kind': 'dependency',
      }),
      throwsA(anything),
    );
    await db.insert('declarative_rules', {
      'id': 'dangling-rule',
      'catalog_version_id': 'v1',
      'owner_type': 'variant',
      'owner_id': 'missing-variant',
      'kind': 'required',
      'expression_json': '{}',
    });
    try {
      await const CatalogPublicationService().publish(
        db,
        catalogVersionId: 'v1',
        publishedAt: '2026-07-21',
      );
      fail('Publication must reject stale hashes and dangling owners.');
    } on CatalogPublicationException catch (error) {
      expect(error.issues, contains('version.hash_mismatch'));
      expect(error.issues, contains('rule.dangling-rule.owner'));
    }
    expect(
      await db.query(
        'catalog_publication_validations',
        where: 'catalog_version_id=?',
        whereArgs: ['v1'],
      ),
      isEmpty,
    );

    final root = await Directory.systemTemp.createTemp('invalid-snapshot-');
    addTearDown(() => root.delete(recursive: true));
    final training = await SplitLocalDatabases(
      rootPath: root.path,
      factory: databaseFactoryFfi,
    ).openTraining();
    addTearDown(training.close);
    await expectLater(
      training.createPlan(
        const TrainingPlanSnapshotWrite(
          id: 'bad',
          athleteId: 'a',
          catalogVersionId: 'v1',
          catalogContentHash: 'h',
          snapshotSchemaVersion: 1,
          snapshotCanonicalizationVersion: 1,
          snapshotHashAlgorithm: 'sha256',
          resolvedSnapshotHash:
              '0000000000000000000000000000000000000000000000000000000000000000',
          resolvedSnapshotJson: '{bad json',
          startsOn: '2026-07-21',
          status: 'draft',
          createdAt: '2026-07-21',
        ),
      ),
      throwsA(anything),
    );
  });

  test(
    'training plan is reproducible without cross-database foreign keys',
    () async {
      final root = await Directory.systemTemp.createTemp('training-snapshot-');
      addTearDown(() => root.delete(recursive: true));
      final training = await SplitLocalDatabases(
        rootPath: root.path,
        factory: databaseFactoryFfi,
      ).openTraining();
      addTearDown(training.close);
      const snapshotJson =
          '{"schemaVersion":1,"catalogVersionId":"catalog-v7",'
          '"catalogContentHash":"sha256:fixture",'
          '"template":{"id":"standard","revision":1},'
          '"schedule":{"sessions":[{"id":"session-1","sequence":0,'
          '"offsetDays":0,"blocks":[{"id":"block-1","sequence":0,'
          '"kind":"main"}]}]}}';
      final snapshotHash = TrainingSnapshotIntegrity.hash(snapshotJson);
      await training.createPlan(
        TrainingPlanSnapshotWrite(
          id: 'plan-1',
          athleteId: 'workspace-athlete-1',
          catalogVersionId: 'catalog-v7',
          catalogContentHash: 'sha256:fixture',
          snapshotSchemaVersion: 1,
          snapshotCanonicalizationVersion: 1,
          snapshotHashAlgorithm: 'sha256',
          resolvedSnapshotHash: snapshotHash,
          resolvedSnapshotJson: snapshotJson,
          startsOn: '2026-07-21',
          status: 'draft',
          createdAt: '2026-07-21T00:00:00Z',
        ),
      );
      await training.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.scheduled,
      );
      await expectLater(
        training.createPlan(
          const TrainingPlanSnapshotWrite(
            id: 'plan-lie',
            athleteId: 'workspace-athlete-1',
            catalogVersionId: 'catalog-v7',
            catalogContentHash: 'sha256:fixture',
            snapshotSchemaVersion: 1,
            snapshotCanonicalizationVersion: 1,
            snapshotHashAlgorithm: 'sha256',
            resolvedSnapshotHash:
                '0000000000000000000000000000000000000000000000000000000000000000',
            resolvedSnapshotJson: snapshotJson,
            startsOn: '2026-07-21',
            status: 'draft',
            createdAt: '2026-07-21T00:00:00Z',
          ),
        ),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'snapshot.hash_mismatch',
          ),
        ),
      );
      expect(
        () => training.insert('plans', {
          'id': 'plan-bypass',
          'athlete_id': 'workspace-athlete-1',
          'catalog_version_id': 'catalog-v7',
          'catalog_content_hash': 'sha256:fixture',
          'snapshot_schema_version': 1,
          'snapshot_canonicalization_version': 1,
          'snapshot_hash_algorithm': 'sha256',
          'resolved_snapshot_hash': 'sha256:lie',
          'resolved_snapshot_json': snapshotJson,
          'starts_on': '2026-07-21',
          'status': 'scheduled',
          'created_at': '2026-07-21T00:00:00Z',
        }),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'snapshot.direct_write_forbidden',
          ),
        ),
      );
      await expectLater(
        training.rawQuery("DELETE FROM plans WHERE id='plan-1' RETURNING id"),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'database.raw_query_forbidden',
          ),
        ),
      );
      expect(
        (await training.query('plans')).single,
        containsPair('catalog_content_hash', 'sha256:fixture'),
      );
      final snapshot =
          (await training.query('plans')).single['resolved_snapshot_json']!
              as String;
      expect(snapshot, isNot(contains('excerpt')));
      expect(snapshot, isNot(contains('display_name')));
      expect(snapshot, isNot(contains('email')));
      expect(
        await training.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='plans'",
        ),
        isNot(contains(contains('REFERENCES catalog'))),
      );
    },
  );

  test('custom definitions remain workspace-owned and exportable', () async {
    final root = await Directory.systemTemp.createTemp('workspace-custom-');
    addTearDown(() => root.delete(recursive: true));
    final workspace = await SplitLocalDatabases(
      rootPath: root.path,
      factory: databaseFactoryFfi,
    ).openWorkspace();
    addTearDown(workspace.close);
    await workspace.insert('athlete_profiles', {
      'id': 'a',
      'display_name': 'Fixture',
      'preferred_unit': 'kg',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
    });
    await workspace.insert('custom_definitions', {
      'id': 'c',
      'athlete_id': 'a',
      'parent_definition_id': 'canonical',
      'parent_catalog_version_id': 'v1',
      'parent_catalog_content_hash': 'hash',
      'schema_version': 1,
      'revision': 1,
      'canonicalization_version': 1,
      'definition_hash': 'sha256:custom',
      'kind': 'template',
      'name': 'Clone',
      'definition_json': '{}',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
    });
    await workspace.update(
      'custom_definitions',
      {'name': 'Edited'},
      where: 'id=?',
      whereArgs: ['c'],
    );
    expect(
      (await workspace.query('custom_definitions')).single['name'],
      'Edited',
    );
  });
}

Future<void> _version(
  Database db, {
  required String id,
  required int ordinal,
  required String hash,
  String? parent,
}) => db.insert('catalog_versions', {
  'id': id,
  'ordinal': ordinal,
  'status': 'draft',
  'parent_version_id': parent,
  'content_hash': hash,
  'canonicalization_version': 1,
  'trust_channel': 'localReview',
  'created_at': '2026-07-21T00:00:00Z',
});

Future<void> _publish(Database db, String id) async {
  final service = const CatalogPublicationService();
  final contentHash = await service.computeContentHash(
    db,
    catalogVersionId: id,
  );
  await db.update(
    'catalog_versions',
    {'content_hash': contentHash},
    where: 'id=?',
    whereArgs: [id],
  );
  await db.update(
    'catalog_versions',
    {'status': 'inReview'},
    where: 'id=?',
    whereArgs: [id],
  );
  await db.update(
    'catalog_versions',
    {'status': 'approved'},
    where: 'id=?',
    whereArgs: [id],
  );
  await service.publish(
    db,
    catalogVersionId: id,
    publishedAt: '2026-07-21T12:00:00Z',
  );
}

Map<String, Object?> _entry(
  String id,
  String historicalKey,
  String stableId, {
  String visibility = 'visible',
  String license = 'compatible',
  String execution = 'executable',
  String versionId = 'v1',
}) => {
  'id': id,
  'catalog_version_id': versionId,
  'catalog_entry_key': historicalKey,
  'stable_domain_id': stableId,
  'nature': 'cycleDefinition',
  'authority': 'canonical',
  'review_status': 'confirmed',
  'implementation_status': 'implemented',
  'execution_status': execution,
  'product_surface': 'cycle',
  'visibility': visibility,
  'license_status': license,
};

Map<String, Object?> _documentaryEntry() => {
  'id': 'documentary-entry',
  'catalog_version_id': 'v1',
  'catalog_entry_key': 'OR-999',
  'stable_domain_id': 'documentary-entry',
  'nature': 'resource',
  'authority': 'canonical',
  'review_status': 'needsReview',
  'implementation_status': 'notStarted',
  'execution_status': 'supported',
  'product_surface': 'none',
  'visibility': 'hidden',
  'license_status': 'unknown',
};

Future<void> _runtimeGraph(Database db) async {
  await db.insert('sources', {
    'id': 'source-1',
    'revision': 1,
    'kind': 'book',
    'locator': 'Book pages 1-2',
  });
  await db.insert('evidence', {
    'id': 'evidence-1',
    'catalog_version_id': 'v1',
    'source_id': 'source-1',
    'rule_id': 'standard-entry-rule',
    'subject_type': 'catalogEntry',
    'subject_id': 'entry-standard',
    'review_status': 'confirmed',
  });
  await db.insert('evidence', {
    'id': 'evidence-template-1',
    'catalog_version_id': 'v1',
    'source_id': 'source-1',
    'rule_id': 'standard-template-rule',
    'subject_type': 'template',
    'subject_id': 'template-1',
    'review_status': 'confirmed',
  });
  await db.insert('evidence', {
    'id': 'evidence-variant-1',
    'catalog_version_id': 'v1',
    'source_id': 'source-1',
    'rule_id': 'standard-variant-rule',
    'subject_type': 'variant',
    'subject_id': 'variant-1',
    'review_status': 'confirmed',
  });
  await db.insert('templates', {
    'id': 'template-1',
    'catalog_version_id': 'v1',
    'catalog_entry_id': 'entry-standard',
    'stable_key': 'standard-531',
    'revision': 1,
    'kind': 'cycle',
    'name_key': 'standard',
  });
  await db.insert('variants', {
    'id': 'variant-1',
    'catalog_version_id': 'v1',
    'template_id': 'template-1',
    'stable_key': 'base',
    'status': 'executable',
  });
  await db.insert('variants', {
    'id': 'variant-2',
    'catalog_version_id': 'v1',
    'template_id': 'template-1',
    'stable_key': 'unsupported',
    'status': 'blocked',
    'blocker_code': 'unsupported-variant',
  });
  await db.insert('engine_bindings', {
    'id': 'binding-1',
    'catalog_version_id': 'v1',
    'variant_id': 'variant-1',
    'engine_kind': 'cycleV5',
    'engine_id': 'canonical-standard',
    'definition_id': 'standard-531',
    'definition_revision': 1,
    'status': 'executable',
  });
}

Future<void> _p0Graph(Database db) async {
  await db.insert('catalog_entry_relations', {
    'id': 'relation-1',
    'catalog_version_id': 'v1',
    'from_entry_id': 'entry-standard',
    'to_entry_id': 'entry-assistance',
    'kind': 'dependency',
  });
  await db.insert('modules', {
    'id': 'module-1',
    'stable_key': 'assistance-module',
    'kind': 'assistance',
  });
  await db.insert('module_versions', {
    'id': 'module-version-1',
    'catalog_version_id': 'v1',
    'catalog_entry_id': 'entry-assistance',
    'module_id': 'module-1',
    'revision': 1,
    'definition_json': '{"loads":["bodyweight"]}',
    'review_status': 'confirmed',
  });
  await db.insert('parameter_schemas', {
    'id': 'parameters-1',
    'catalog_version_id': 'v1',
    'variant_id': 'variant-1',
    'schema_version': 1,
    'schema_json': '{"type":"object"}',
  });
  await db.insert('variant_module_bindings', {
    'id': 'module-binding-1',
    'catalog_version_id': 'v1',
    'variant_id': 'variant-1',
    'module_version_id': 'module-version-1',
    'role': 'assistance',
    'sequence': 0,
  });
  await db.insert('declarative_rules', {
    'id': 'rule-1',
    'catalog_version_id': 'v1',
    'owner_type': 'variant',
    'owner_id': 'variant-1',
    'kind': 'required',
    'expression_json': '{"parameter":"assistance"}',
  });
  await db.insert('engine_binding_variants', {
    'id': 'engine-variant-1',
    'catalog_version_id': 'v1',
    'engine_binding_id': 'binding-1',
    'variant_id': 'variant-1',
    'status': 'executable',
  });
  await db.insert('engine_binding_variants', {
    'id': 'engine-variant-2',
    'catalog_version_id': 'v1',
    'engine_binding_id': 'binding-1',
    'variant_id': 'variant-2',
    'status': 'blocked',
    'blocker_code': 'unsupported-variant',
  });
  await db.insert('engine_binding_capabilities', {
    'id': 'engine-capability-1',
    'catalog_version_id': 'v1',
    'engine_binding_id': 'binding-1',
    'capability_id': 'assistance',
  });
  await db.insert('engine_binding_migration_aliases', {
    'id': 'engine-alias-1',
    'catalog_version_id': 'v1',
    'engine_binding_id': 'binding-1',
    'alias': 'standard-531-v1',
  });
  await db.insert('movement_categories', {
    'id': 'category-1',
    'catalog_version_id': 'v1',
    'stable_key': 'conditioning',
  });
  await db.insert('movements', {
    'id': 'movement-1',
    'catalog_version_id': 'v1',
    'catalog_entry_id': 'entry-standard',
    'stable_key': 'prowler',
    'category_id': 'category-1',
    'kind': 'conditioning',
    'body_region': 'conditioning',
  });
  await db.insert('movement_capabilities', {
    'id': 'movement-capability-1',
    'catalog_version_id': 'v1',
    'movement_id': 'movement-1',
    'capability_id': 'barbell-load',
  });
  await db.insert('conditioning_definitions', {
    'id': 'conditioning-1',
    'catalog_version_id': 'v1',
    'movement_id': 'movement-1',
  });
  await db.insert('conditioning_modalities', {
    'id': 'conditioning-modality-1',
    'catalog_version_id': 'v1',
    'conditioning_definition_id': 'conditioning-1',
    'modality': 'intervals',
  });
  await db.insert('schedules', {
    'id': 'schedule-1',
    'catalog_version_id': 'v1',
    'variant_id': 'variant-1',
    'stable_key': 'four-days',
    'duration_weeks': 3,
    'days_per_week': 4,
  });
  await db.insert('engine_binding_schedules', {
    'id': 'engine-schedule-1',
    'catalog_version_id': 'v1',
    'engine_binding_id': 'binding-1',
    'schedule_id': 'schedule-1',
  });
  await db.insert('engine_binding_options', {
    'id': 'engine-option-1',
    'catalog_version_id': 'v1',
    'engine_binding_id': 'binding-1',
    'option_id': 'assistance',
  });
  await db.insert('schedule_segments', {
    'id': 'segment-1',
    'catalog_version_id': 'v1',
    'schedule_id': 'schedule-1',
    'sequence': 0,
    'kind': 'training',
    'start_offset_days': 0,
    'duration_days': 21,
    'frequency': 12,
  });
  await db.insert('schedule_segment_roles', {
    'id': 'segment-role-1',
    'catalog_version_id': 'v1',
    'segment_id': 'segment-1',
    'role_id': 'main',
  });
  await db.insert('schedule_training_max_evolution', {
    'id': 'tm-evolution-1',
    'catalog_version_id': 'v1',
    'schedule_id': 'schedule-1',
    'movement_id': 'movement-1',
    'effective_offset_days': 21,
    'training_max': 100.0,
  });
  await db.insert('schedule_weeks', {
    'id': 'week-1',
    'catalog_version_id': 'v1',
    'schedule_id': 'schedule-1',
    'sequence': 0,
    'role': 'leader',
  });
  await db.insert('schedule_sessions', {
    'id': 'session-1',
    'catalog_version_id': 'v1',
    'week_id': 'week-1',
    'sequence': 0,
    'weekday': 1,
    'role': 'main',
  });
  await db.insert('session_blocks', {
    'id': 'block-1',
    'catalog_version_id': 'v1',
    'session_id': 'session-1',
    'sequence': 0,
    'kind': 'conditioning',
    'module_version_id': 'module-version-1',
  });
  await db.insert('prescriptions', {
    'id': 'prescription-1',
    'catalog_version_id': 'v1',
    'block_id': 'block-1',
    'movement_id': 'movement-1',
    'sequence': 0,
    'kind': 'duration',
    'repetition_target_kind': 'none',
    'load_kind': 'none',
    'prescription_json': '{"seconds":600}',
  });
  await db.insert('finite_programs', {
    'id': 'program-1',
    'catalog_version_id': 'v1',
    'template_id': 'template-1',
    'stable_key': 'finite-standard',
  });
  await db.insert('finite_program_phases', {
    'id': 'phase-1',
    'catalog_version_id': 'v1',
    'finite_program_id': 'program-1',
    'sequence': 0,
    'role': 'leader',
    'repetitions': 2,
  });
  await db.insert('finite_program_phases', {
    'id': 'phase-2',
    'catalog_version_id': 'v1',
    'finite_program_id': 'program-1',
    'sequence': 1,
    'role': 'anchor',
    'repetitions': 1,
  });
  await db.insert('finite_program_segments', {
    'id': 'program-segment-1',
    'catalog_version_id': 'v1',
    'phase_id': 'phase-1',
    'sequence': 0,
    'variant_id': 'variant-1',
    'schedule_id': 'schedule-1',
  });
  await db.insert('finite_program_transitions', {
    'id': 'transition-1',
    'catalog_version_id': 'v1',
    'from_phase_id': 'phase-1',
    'to_phase_id': 'phase-2',
    'movement_id': 'movement-1',
    'kind': 'add',
    'amount': 5.0,
  });
  await db.insert('assistance_plans', {
    'id': 'assistance-1',
    'catalog_version_id': 'v1',
    'variant_id': 'variant-1',
    'stable_key': 'default',
    'deload_mode': 'templateDefault',
  });
  await db.insert('assistance_slots', {
    'id': 'slot-1',
    'catalog_version_id': 'v1',
    'assistance_plan_id': 'assistance-1',
    'session_role': 'main',
    'sequence': 0,
    'category_id': 'category-1',
    'minimum_selections': 1,
    'maximum_selections': 2,
    'prescription_json': '{"sets":3}',
  });
  await db.insert('assistance_slot_movements', {
    'id': 'slot-movement-1',
    'catalog_version_id': 'v1',
    'assistance_slot_id': 'slot-1',
    'movement_id': 'movement-1',
  });
}

final class _TestSignatureVerifier implements CatalogSignatureVerifier {
  const _TestSignatureVerifier();

  @override
  Future<bool> verify({
    required List<int> canonicalBytes,
    required String signature,
    required String keyId,
    required String algorithm,
  }) async =>
      canonicalBytes.isNotEmpty &&
      keyId == 'known-key' &&
      algorithm == 'ed25519' &&
      signature == 'valid-signature';
}

Future<Set<Object?>> _tables(Database db) async => (await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type='table'",
)).map((row) => row['name']).toSet();
