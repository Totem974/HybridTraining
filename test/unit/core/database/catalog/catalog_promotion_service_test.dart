import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/catalog/catalog_administration_database.dart';
import 'package:hybrid_training/core/database/catalog/catalog_promotion_service.dart';
import 'package:hybrid_training/core/database/catalog/catalog_publication_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late String path;
  late CatalogAdministrationDatabase database;
  late CatalogPromotionService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('catalog-promotion-');
    path = '${root.path}/catalog.db';
    database = CatalogAdministrationDatabase(
      path: path,
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    );
    service = CatalogPromotionService(database, _testHash);
    await database.initialize();
    await database.transaction((transaction) async {
      await transaction.insertDraftVersion(
        const CatalogDraftVersion(
          id: 'source-v1',
          ordinal: 1,
          status: 'inReview',
          contentHash: _sourceHash,
          canonicalizationVersion: 1,
          signatureVerified: false,
          trustChannel: 'localReview',
          createdAt: '2026-07-21T00:00:00Z',
        ),
      );
      await transaction.insertBook(
        const CatalogBookWrite(
          id: 'review-book',
          title: 'Fictitious reviewed fixture book',
          author: 'Fixture Author',
          licenseStatus: 'unknown',
        ),
      );
      await transaction.insertEdition(
        const CatalogEditionWrite(
          id: 'review-edition',
          bookId: 'review-book',
          label: 'Fictitious test edition',
          publicationYear: 2026,
          digest: 'fixture-digest',
        ),
      );
      await transaction.insertSource(
        const CatalogSourceWrite(
          id: 'review-source',
          editionId: 'review-edition',
          revision: 1,
          kind: 'reviewedRepository',
          locator: 'review/fixture',
          note: 'Fictitious reviewed test source.',
        ),
      );
      for (final (key, hash) in const [
        ('OR-001', _recordOneHash),
        ('OR-002', _recordTwoHash),
      ]) {
        await transaction.insertEntry(
          CatalogEntryWrite(
            catalogVersionId: 'source-v1',
            catalogEntryKey: key,
            canonicalRecordJson: '{}',
            recordHash: hash,
            manifestHash: _sourceHash,
            stableDomainId: null,
            authority: null,
            reviewStatus: 'needsReview',
            visibility: 'hidden',
            executionStatus: 'blocked',
          ),
        );
      }
    });
  });

  tearDown(() => root.delete(recursive: true));

  test('simulation reports hashes and dispositions without writes', () async {
    final manifest = _manifest(service, normalized: _normalized());
    final report = await service.promote(manifest: manifest);

    expect(report.isValid, isTrue);
    expect(report.applied, isFalse);
    expect(report.planHash, manifest.expectedPlanHash);
    expect(report.sourceManifestHash, _sourceHash);
    expect(report.dispositions, hasLength(2));
    expect(
      report.dispositions
          .where((item) => item.sourceCatalogEntryKey == 'OR-001')
          .single
          .mappingHash,
      isNotNull,
    );
    expect(
      report.dispositions
          .where((item) => item.sourceCatalogEntryKey == 'OR-002')
          .single
          .disposition,
      PromotionDisposition.notAllowlisted,
    );
    final db = await _readOnly(path);
    addTearDown(db.close);
    expect(await db.query('catalog_promotion_batches'), isEmpty);
    expect(await db.query('catalog_versions'), hasLength(1));
  });

  test('apply is atomic, leaves S unchanged and is idempotent', () async {
    final manifest = _manifest(service, normalized: _normalized());
    final first = await service.promote(
      manifest: manifest,
      mode: CatalogPromotionMode.apply,
    );
    final second = await service.promote(
      manifest: manifest,
      mode: CatalogPromotionMode.apply,
    );

    expect(first.applied, isTrue);
    expect(first.idempotent, isFalse);
    expect(second.applied, isTrue);
    expect(second.idempotent, isTrue);
    expect(second.targetVersionId, 'target-v1');
    final db = await _readOnly(path);
    addTearDown(db.close);
    expect(
      await db.query(
        'catalog_staging_entries',
        where: 'catalog_version_id=?',
        whereArgs: ['source-v1'],
      ),
      hasLength(2),
    );
    expect(await db.query('catalog_entries'), hasLength(1));
    expect(await db.query('catalog_entry_aliases'), hasLength(1));
    expect(await db.query('declarative_rules'), hasLength(1));
    expect(
      (await db.query('catalog_promotion_batches')).single['status'],
      'applied',
    );
  });

  test(
    'hash mismatch, record mismatch and allowlist drift are rejected',
    () async {
      final valid = _manifest(service, normalized: _normalized());
      final wrongPlan = _manifest(
        service,
        normalized: _normalized(),
        expectedPlanHash: '0'.padRight(64, '0'),
      );
      final wrongRecord = _manifest(
        service,
        normalized: _normalized(),
        sourceRecordHash: 'f'.padRight(64, 'f'),
      );
      final allowlistDrift = _manifest(
        service,
        normalized: _normalized(),
        allowedKeys: {'OR-001', 'OR-002'},
      );

      expect(valid.expectedPlanHash, isNotEmpty);
      expect(
        (await service.promote(manifest: wrongPlan)).issues,
        contains('plan.hash_mismatch'),
      );
      expect(
        (await service.promote(manifest: wrongRecord)).issues,
        contains('source.record_hash_mismatch:OR-001'),
      );
      expect(
        (await service.promote(manifest: allowlistDrift)).issues,
        contains('plan.allowlist_mismatch'),
      );
    },
  );

  test(
    'needsReview, content reuse, unsourced rule and alias are blocked',
    () async {
      Future<List<String>> issues(ReviewedNormalizedEntry normalized) async =>
          (await service.promote(
            manifest: _manifest(service, normalized: normalized),
          )).issues;

      expect(
        await issues(_normalized(reviewStatus: 'needsReview')),
        contains('mapping.needs_review:OR-001'),
      );
      expect(
        await issues(_normalized(licenseStatus: 'unknown')),
        isNot(contains('mapping.license_status:OR-001')),
      );
      expect(
        await issues(_normalized(contentReuse: 'excerpt')),
        contains('mapping.source:entry-evidence'),
      );
      expect(
        await issues(_normalized(pages: '')),
        contains('mapping.source:entry-evidence'),
      );
      expect(
        await issues(_normalized(includeRuleEvidence: false)),
        contains('mapping.rule:rule-one'),
      );
      expect(
        await issues(_normalized(aliasEvidenceId: 'missing-evidence')),
        contains('mapping.alias:legacy-alias'),
      );
    },
  );

  test(
    'failure after target creation rolls back the whole promotion',
    () async {
      final duplicateEvidence = _normalized(duplicateEvidenceId: true);
      final manifest = _manifest(service, normalized: duplicateEvidence);

      await expectLater(
        service.promote(manifest: manifest, mode: CatalogPromotionMode.apply),
        throwsA(anything),
      );

      final db = await _readOnly(path);
      addTearDown(db.close);
      expect(await db.query('catalog_versions'), hasLength(1));
      expect(await db.query('catalog_entries'), isEmpty);
      expect(await db.query('catalog_promotion_batches'), isEmpty);
    },
  );
}

const _sourceHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _recordOneHash =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _recordTwoHash =
    '2222222222222222222222222222222222222222222222222222222222222222';

ReviewedPromotionManifest _manifest(
  CatalogPromotionService service, {
  required ReviewedNormalizedEntry normalized,
  String? expectedPlanHash,
  String sourceRecordHash = _recordOneHash,
  Set<String> allowedKeys = const {'OR-001'},
}) {
  ReviewedPromotionManifest build(String hash) => ReviewedPromotionManifest(
    sourceVersionId: 'source-v1',
    targetVersionId: 'target-v1',
    batchId: 'promotion-one',
    createdAt: '2026-07-21T01:00:00Z',
    completedAt: '2026-07-21T01:01:00Z',
    expectedPlanHash: hash,
    allowedSourceKeys: allowedKeys,
    items: [
      ReviewedPromotionItem.promote(
        sourceCatalogEntryKey: 'OR-001',
        expectedSourceRecordHash: sourceRecordHash,
        normalized: normalized,
      ),
    ],
  );
  final draft = build('');
  return build(expectedPlanHash ?? service.computePlanHash(draft));
}

ReviewedNormalizedEntry _normalized({
  String reviewStatus = 'confirmed',
  String licenseStatus = 'compatible',
  bool includeRuleEvidence = true,
  String aliasEvidenceId = 'entry-evidence',
  bool duplicateEvidenceId = false,
  String contentReuse = 'none',
  String pages = 'p. 1',
}) {
  final evidence = <ReviewedEvidence>[
    ReviewedEvidence(
      id: 'entry-evidence',
      sourceId: 'review-source',
      editionId: 'review-edition',
      sourceLocator: 'review/fixture',
      pages: pages,
      contentReuse: contentReuse,
      ruleId: 'entry-rule',
      subjectType: 'catalogEntry',
      subjectId: 'entry-one',
      reviewStatus: 'confirmed',
      excerptDigest: contentReuse == 'none' ? null : 'digest-one',
      note: 'Reviewed entry mapping.',
    ),
    if (includeRuleEvidence)
      ReviewedEvidence(
        id: duplicateEvidenceId ? 'entry-evidence' : 'rule-evidence',
        sourceId: 'review-source',
        editionId: 'review-edition',
        sourceLocator: 'review/fixture',
        pages: 'p. 2',
        contentReuse: contentReuse,
        ruleId: 'rule-one',
        subjectType: 'rule',
        subjectId: 'rule-one',
        reviewStatus: 'confirmed',
        excerptDigest: contentReuse == 'none' ? null : 'digest-two',
        note: 'Reviewed declarative rule.',
      ),
  ];
  return ReviewedNormalizedEntry(
    id: 'entry-one',
    catalogEntryKey: 'OR-001',
    stableDomainId: 'reviewed-entry-one',
    nature: 'cycleDefinition',
    authority: 'compatible',
    reviewStatus: reviewStatus,
    implementationStatus: 'implemented',
    executionStatus: 'executable',
    productSurface: 'cycle',
    visibility: reviewStatus == 'confirmed' ? 'visible' : 'hidden',
    licenseStatus: licenseStatus,
    evidence: evidence,
    rules: const [
      ReviewedRule(
        id: 'rule-one',
        ownerType: 'catalogEntry',
        ownerId: 'entry-one',
        kind: 'constraint',
        schemaVersion: 1,
        expressionJson: '{"type":"always","value":true}',
        blockerCode: null,
        reviewStatus: 'confirmed',
      ),
    ],
    aliases: [
      ReviewedAlias(
        id: 'legacy-alias',
        namespace: 'legacy',
        alias: 'OR-001',
        evidenceId: aliasEvidenceId,
        reviewStatus: 'confirmed',
      ),
    ],
  );
}

String _testHash(String value) {
  var first = 0x811c9dc5;
  var second = value.length;
  for (final unit in value.codeUnits) {
    first = ((first ^ unit) * 0x01000193) & 0xffffffff;
    second = ((second * 33) ^ unit) & 0xffffffff;
  }
  final block =
      '${first.toRadixString(16).padLeft(8, '0')}'
      '${second.toRadixString(16).padLeft(8, '0')}';
  return block * 4;
}

Future<Database> _readOnly(String path) => databaseFactoryFfi.openDatabase(
  path,
  options: OpenDatabaseOptions(readOnly: true),
);
