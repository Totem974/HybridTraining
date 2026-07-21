import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/catalog/catalog_administration_database.dart';
import 'package:hybrid_training/core/database/catalog/catalog_publication_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('writable database handle and forgeable capability are not public', () {
    final source = File(
      'lib/core/database/catalog/catalog_administration_database.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('CatalogAdministrationCapability')));
    expect(source, isNot(matches(RegExp(r'Future<Database>\s+open\s*\('))));
    expect(source, contains('Future<Database> _open()'));
    expect(source, contains('CatalogAdministrationTransaction._('));
    expect(source, isNot(contains('Future<void> execute(')));
    expect(
      source,
      isNot(contains('Future<List<Map<String, Object?>>> query(')),
    );
    expect(source, isNot(contains('rawQuery(')));
  });

  test('runtime libraries do not import the administration facade', () {
    final forbiddenImport = RegExp(
      r'''import\s+['"][^'"]*catalog_administration_database\.dart['"]''',
    );
    final runtimeImports = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => !file.path.endsWith('catalog_administration_database.dart'),
        )
        .where((file) => forbiddenImport.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(runtimeImports, isEmpty);
  });

  test('publication is routed through the publication service', () async {
    final root = await Directory.systemTemp.createTemp('catalog-admin-');
    addTearDown(() => root.delete(recursive: true));
    final facade = CatalogAdministrationDatabase(
      path: '${root.path}/catalog.db',
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    );

    await facade.initialize();

    await expectLater(
      facade.publish(
        catalogVersionId: 'missing-version',
        publishedAt: '2026-07-21T00:00:00Z',
      ),
      throwsA(
        isA<CatalogPublicationException>().having(
          (error) => error.issues,
          'issues',
          const ['version.not_found'],
        ),
      ),
    );

    final database = await databaseFactoryFfi.openDatabase(
      '${root.path}/catalog.db',
      options: OpenDatabaseOptions(readOnly: true),
    );
    addTearDown(database.close);
    expect(await database.query('catalog_publication_validations'), isEmpty);
  });

  test(
    'transaction stages incomplete history without touching runtime entries',
    () async {
      final root = await Directory.systemTemp.createTemp('catalog-staging-');
      addTearDown(() => root.delete(recursive: true));
      final path = '${root.path}/catalog.db';
      final facade = _facade(path);
      late CatalogAdministrationTransaction escaped;

      await facade.transaction((transaction) async {
        escaped = transaction;
        expect(await transaction.nextVersionOrdinal(), 1);
        await transaction.insertDraftVersion(_draft());
        expect(
          await transaction.findVersionByContentHash('manifest-hash'),
          isA<CatalogVersionSnapshot>()
              .having((version) => version.id, 'id', 'seed-v1')
              .having((version) => version.status, 'status', 'inReview'),
        );
        await transaction.insertEntry(_entry());
        await transaction.replaceImportBlockers(
          catalogVersionId: 'seed-v1',
          blockers: const [
            CatalogImportBlockerWrite(
              id: 'blocker-stable-id',
              catalogVersionId: 'seed-v1',
              catalogEntryKey: 'OR-001',
              issueCode: 'stable_domain_id_missing',
              severity: 'publishBlocker',
              message: 'A reviewed stable domain id is required.',
            ),
            CatalogImportBlockerWrite(
              id: 'blocker-authority',
              catalogVersionId: 'seed-v1',
              catalogEntryKey: 'OR-001',
              issueCode: 'authority_missing',
              severity: 'publishBlocker',
              message: 'A reviewed authority is required.',
            ),
          ],
        );
        expect(
          await transaction.findEntry(
            catalogVersionId: 'seed-v1',
            catalogEntryKey: 'OR-001',
          ),
          isA<CatalogEntrySnapshot>()
              .having((entry) => entry.stableDomainId, 'stableDomainId', isNull)
              .having((entry) => entry.authority, 'authority', isNull)
              .having((entry) => entry.recordHash, 'recordHash', 'record-1'),
        );
      });

      await expectLater(escaped.nextVersionOrdinal(), throwsStateError);

      final database = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      addTearDown(database.close);
      expect(await database.query('catalog_staging_entries'), hasLength(1));
      expect(await database.query('catalog_import_blockers'), hasLength(2));
      expect(await database.query('catalog_entries'), isEmpty);
      expect(await database.query('runtime_catalog_entries'), isEmpty);
      expect(await database.query('catalog_publication_validations'), isEmpty);
    },
  );

  test('transaction rolls back version, staged entries and blockers', () async {
    final root = await Directory.systemTemp.createTemp('catalog-rollback-');
    addTearDown(() => root.delete(recursive: true));
    final path = '${root.path}/catalog.db';
    final facade = _facade(path);

    await expectLater(
      facade.transaction<void>((transaction) async {
        await transaction.insertDraftVersion(_draft());
        await transaction.insertEntry(_entry());
        await transaction.insertImportBlocker(
          const CatalogImportBlockerWrite(
            id: 'blocker-stable-id',
            catalogVersionId: 'seed-v1',
            catalogEntryKey: 'OR-001',
            issueCode: 'stable_domain_id_missing',
            severity: 'publishBlocker',
            message: 'A reviewed stable domain id is required.',
          ),
        );
        throw StateError('forced failure on final entry');
      }),
      throwsStateError,
    );

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(database.close);
    expect(await database.query('catalog_versions'), isEmpty);
    expect(await database.query('catalog_staging_entries'), isEmpty);
    expect(await database.query('catalog_import_blockers'), isEmpty);
  });

  test(
    'entry update is key-scoped and retains caller-supplied fields',
    () async {
      final root = await Directory.systemTemp.createTemp('catalog-update-');
      addTearDown(() => root.delete(recursive: true));
      final facade = _facade('${root.path}/catalog.db');

      await facade.transaction((transaction) async {
        await transaction.insertDraftVersion(_draft());
        await transaction.insertEntry(_entry());
        await transaction.updateEntry(
          const CatalogEntryWrite(
            catalogVersionId: 'seed-v1',
            catalogEntryKey: 'OR-001',
            canonicalRecordJson: '{"catalogEntryKey":"OR-001","changed":true}',
            recordHash: 'record-2',
            manifestHash: 'manifest-hash',
            stableDomainId: 'reviewed-domain-id',
            authority: 'canonical',
            reviewStatus: 'confirmed',
            visibility: 'internal',
            executionStatus: 'supported',
          ),
        );
        final updated = await transaction.findEntry(
          catalogVersionId: 'seed-v1',
          catalogEntryKey: 'OR-001',
        );
        expect(updated?.recordHash, 'record-2');
        expect(updated?.stableDomainId, 'reviewed-domain-id');
        expect(updated?.authority, 'canonical');
      });
    },
  );

  test('blocker replacement is version-scoped and atomic', () async {
    final root = await Directory.systemTemp.createTemp('catalog-blockers-');
    addTearDown(() => root.delete(recursive: true));
    final path = '${root.path}/catalog.db';
    final facade = _facade(path);

    await facade.transaction((transaction) async {
      await transaction.insertDraftVersion(_draft());
      await transaction.replaceImportBlockers(
        catalogVersionId: 'seed-v1',
        blockers: const [
          CatalogImportBlockerWrite(
            id: 'global-warning',
            catalogVersionId: 'seed-v1',
            catalogEntryKey: null,
            issueCode: 'manifest_warning',
            severity: 'warning',
            message: 'Manifest warning.',
          ),
          CatalogImportBlockerWrite(
            id: 'global-blocker',
            catalogVersionId: 'seed-v1',
            catalogEntryKey: null,
            issueCode: 'manifest_blocked',
            severity: 'publishBlocker',
            message: 'Manifest publication blocker.',
          ),
        ],
      );
      await expectLater(
        transaction.replaceImportBlockers(
          catalogVersionId: 'seed-v1',
          blockers: const [
            CatalogImportBlockerWrite(
              id: 'wrong-version',
              catalogVersionId: 'another-version',
              catalogEntryKey: null,
              issueCode: 'wrong_version',
              severity: 'error',
              message: 'Wrong version.',
            ),
          ],
        ),
        throwsArgumentError,
      );
      await transaction.replaceImportBlockers(
        catalogVersionId: 'seed-v1',
        blockers: const [
          CatalogImportBlockerWrite(
            id: 'global-warning',
            catalogVersionId: 'seed-v1',
            catalogEntryKey: null,
            issueCode: 'manifest_warning',
            severity: 'warning',
            message: 'Updated manifest warning.',
          ),
        ],
      );
    });

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(database.close);
    final blockers = await database.query('catalog_import_blockers');
    expect(blockers, hasLength(1));
    expect(blockers.single['id'], 'global-warning');
    expect(blockers.single['message'], 'Updated manifest warning.');
  });
}

CatalogAdministrationDatabase _facade(String path) =>
    CatalogAdministrationDatabase(
      path: path,
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    );

CatalogDraftVersion _draft() => const CatalogDraftVersion(
  id: 'seed-v1',
  ordinal: 1,
  status: 'inReview',
  contentHash: 'manifest-hash',
  canonicalizationVersion: 1,
  signatureVerified: false,
  trustChannel: 'localReview',
  createdAt: '2026-07-21T00:00:00Z',
);

CatalogEntryWrite _entry() => const CatalogEntryWrite(
  catalogVersionId: 'seed-v1',
  catalogEntryKey: 'OR-001',
  canonicalRecordJson: '{"catalogEntryKey":"OR-001"}',
  recordHash: 'record-1',
  manifestHash: 'manifest-hash',
  stableDomainId: null,
  authority: null,
  reviewStatus: 'needsReview',
  visibility: 'hidden',
  executionStatus: 'blocked',
);
