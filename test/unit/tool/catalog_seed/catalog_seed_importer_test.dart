import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/catalog/catalog_administration_database.dart';
import 'package:hybrid_training/core/database/catalog/catalog_publication_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../tool/catalog_seed/catalog_seed_importer.dart';
import '../../../../tool/catalog_seed/catalog_seed_manifest.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late String path;
  late CatalogAdministrationDatabase database;
  late CatalogSeedImporter importer;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('catalog-seed-import-');
    path = '${root.path}/catalog.db';
    database = CatalogAdministrationDatabase(
      path: path,
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    );
    importer = CatalogSeedImporter(database);
    await database.initialize();
  });

  tearDown(() => root.delete(recursive: true));

  test('simulation reports all 354 inserts without writing data', () async {
    final manifest = buildCatalogSeedManifest();
    final report = await importer.run(
      manifest: manifest,
      request: const CatalogSeedImportRequest(
        versionId: 'seed-v1',
        createdAt: '2026-07-21T00:00:00Z',
      ),
    );

    expect(report.mode, CatalogSeedImportMode.simulate);
    expect(report.versionCreated, isTrue);
    expect(report.inserted, 354);
    expect(report.updated, 0);
    expect(report.unchanged, 0);
    expect(report.rejected, 0);
    expect(report.blockersRetained, manifest.issues.length);

    final db = await _openReadOnly(path);
    addTearDown(db.close);
    expect(await db.query('catalog_versions'), isEmpty);
    expect(await db.query('catalog_staging_entries'), isEmpty);
    expect(await db.query('catalog_import_blockers'), isEmpty);
  });

  test('imports into inReview staging and retains every blocker', () async {
    final manifest = buildCatalogSeedManifest();
    final report = await importer.run(
      manifest: manifest,
      request: const CatalogSeedImportRequest(
        versionId: 'seed-v1',
        createdAt: '2026-07-21T00:00:00Z',
        mode: CatalogSeedImportMode.apply,
      ),
    );

    expect(report.applied, isTrue);
    expect(report.inserted, 354);
    expect(report.blockersRetained, manifest.issues.length);

    final db = await _openReadOnly(path);
    addTearDown(db.close);
    final versions = await db.query('catalog_versions');
    expect(versions, hasLength(1));
    expect(versions.single['status'], 'inReview');
    expect(versions.single['content_hash'], manifest.sourceHash);
    expect(await db.query('catalog_staging_entries'), hasLength(354));
    final blockers = await db.query('catalog_import_blockers');
    expect(blockers, hasLength(manifest.issues.length));
    expect(
      blockers.map((row) => row['issue_code']),
      containsAll(manifest.issues.map((issue) => issue.code)),
    );
    expect(await db.query('catalog_entries'), isEmpty);
    expect(await db.query('catalog_publication_validations'), isEmpty);
  });

  test('identical import is idempotent', () async {
    final manifest = buildCatalogSeedManifest();
    const firstRequest = CatalogSeedImportRequest(
      versionId: 'seed-v1',
      createdAt: '2026-07-21T00:00:00Z',
      mode: CatalogSeedImportMode.apply,
    );
    await importer.run(manifest: manifest, request: firstRequest);

    final second = await importer.run(
      manifest: manifest,
      request: const CatalogSeedImportRequest(
        versionId: 'ignored-because-hash-is-stable',
        createdAt: '2026-07-22T00:00:00Z',
        mode: CatalogSeedImportMode.apply,
      ),
    );

    expect(second.catalogVersionId, 'seed-v1');
    expect(second.versionCreated, isFalse);
    expect(second.inserted, 0);
    expect(second.updated, 0);
    expect(second.unchanged, 354);

    final db = await _openReadOnly(path);
    addTearDown(db.close);
    expect(await db.query('catalog_versions'), hasLength(1));
    expect(await db.query('catalog_staging_entries'), hasLength(354));
    expect(
      await db.query('catalog_import_blockers'),
      hasLength(manifest.issues.length),
    );
  });

  test('reimport removes blockers absent from the new report', () async {
    final source = buildCatalogSeedManifest();
    final first = _manifestWithIssues(source.records, const [_issueA, _issueB]);
    final second = _manifestWithIssues(source.records, const [_issueB]);
    await importer.run(manifest: first, request: _applyRequest);

    final report = await importer.run(manifest: second, request: _applyRequest);

    expect(report.blockersRetained, 1);
    final blockers = await _readBlockers(path);
    expect(blockers, hasLength(1));
    expect(blockers.single['issue_code'], _issueB.code);
  });

  test(
    'reimport replaces a modified blocker without leaving stale data',
    () async {
      final source = buildCatalogSeedManifest();
      final first = _manifestWithIssues(source.records, const [_issueA]);
      final modified = _manifestWithIssues(source.records, const [
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.publishBlocker,
          code: 'fixture_a',
          message: 'Reviewed wording for blocker A.',
        ),
      ]);
      await importer.run(manifest: first, request: _applyRequest);
      final oldId = (await _readBlockers(path)).single['id'];

      final report = await importer.run(
        manifest: modified,
        request: _applyRequest,
      );

      expect(report.blockersRetained, 1);
      final blockers = await _readBlockers(path);
      expect(blockers, hasLength(1));
      expect(blockers.single['message'], 'Reviewed wording for blocker A.');
      expect(blockers.single['id'], isNot(oldId));
    },
  );

  test('blocker identities are stable across issue reordering', () async {
    final source = buildCatalogSeedManifest();
    final first = _manifestWithIssues(source.records, const [_issueA, _issueB]);
    final reordered = _manifestWithIssues(source.records, const [
      _issueB,
      _issueA,
    ]);
    await importer.run(manifest: first, request: _applyRequest);
    final initialIds = {
      for (final row in await _readBlockers(path))
        row['issue_code'] as String: row['id'] as String,
    };

    final report = await importer.run(
      manifest: reordered,
      request: _applyRequest,
    );

    expect(report.blockersRetained, 2);
    final reorderedIds = {
      for (final row in await _readBlockers(path))
        row['issue_code'] as String: row['id'] as String,
    };
    expect(reorderedIds, initialIds);
  });

  test(
    'validation errors reject the complete manifest before writes',
    () async {
      final manifest = buildCatalogSeedManifest(expectedRecordCount: 355);
      final report = await importer.run(
        manifest: manifest,
        request: const CatalogSeedImportRequest(
          versionId: 'seed-invalid',
          createdAt: '2026-07-21T00:00:00Z',
          mode: CatalogSeedImportMode.apply,
        ),
      );

      expect(report.applied, isFalse);
      expect(report.rejected, 354);
      expect(
        report.issues.map((issue) => issue.code),
        contains('unexpected_record_count'),
      );
      final db = await _openReadOnly(path);
      addTearDown(db.close);
      expect(await db.query('catalog_versions'), isEmpty);
    },
  );

  test('a blocker write failure rolls back version and staged rows', () async {
    final source = buildCatalogSeedManifest();
    final manifest = CatalogSeedManifest(
      manifestVersion: source.manifestVersion,
      records: [source.records.first],
      issues: const [
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.publishBlocker,
          code: 'fixture_dangling_blocker',
          message: 'Fixture forces a foreign-key failure after entry staging.',
          catalogueId: 'OR-999',
        ),
      ],
    );

    await expectLater(
      importer.run(
        manifest: manifest,
        request: const CatalogSeedImportRequest(
          versionId: 'seed-rollback',
          createdAt: '2026-07-21T00:00:00Z',
          mode: CatalogSeedImportMode.apply,
        ),
      ),
      throwsA(anything),
    );

    final db = await _openReadOnly(path);
    addTearDown(db.close);
    expect(await db.query('catalog_versions'), isEmpty);
    expect(await db.query('catalog_staging_entries'), isEmpty);
    expect(await db.query('catalog_import_blockers'), isEmpty);
  });

  test(
    'published status is rejected without opening an import transaction',
    () async {
      final report = await importer.run(
        manifest: buildCatalogSeedManifest(),
        request: const CatalogSeedImportRequest(
          versionId: 'seed-published',
          createdAt: '2026-07-21T00:00:00Z',
          status: 'published',
          mode: CatalogSeedImportMode.apply,
        ),
      );

      expect(report.rejected, 354);
      expect(
        report.issues.map((issue) => issue.code),
        contains('invalid_staging_version_status'),
      );
    },
  );
}

Future<Database> _openReadOnly(String path) => databaseFactoryFfi.openDatabase(
  path,
  options: OpenDatabaseOptions(readOnly: true),
);

const _applyRequest = CatalogSeedImportRequest(
  versionId: 'seed-v1',
  createdAt: '2026-07-21T00:00:00Z',
  mode: CatalogSeedImportMode.apply,
);

const _issueA = CatalogSeedIssue(
  severity: CatalogSeedIssueSeverity.publishBlocker,
  code: 'fixture_a',
  message: 'Blocker A.',
);

const _issueB = CatalogSeedIssue(
  severity: CatalogSeedIssueSeverity.warning,
  code: 'fixture_b',
  message: 'Blocker B.',
);

CatalogSeedManifest _manifestWithIssues(
  List<CatalogSeedRecord> records,
  List<CatalogSeedIssue> issues,
) => CatalogSeedManifest(manifestVersion: 1, records: records, issues: issues);

Future<List<Map<String, Object?>>> _readBlockers(String path) async {
  final database = await _openReadOnly(path);
  try {
    return database.query('catalog_import_blockers', orderBy: 'issue_code');
  } finally {
    await database.close();
  }
}
