import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_training/features/poc_531/catalog/catalog.dart';
import 'package:hybrid_training/features/poc_531/domain/models.dart';
import '../../../../tool/catalog_seed/catalog_seed_manifest.dart';

void main() {
  final manifest = buildCatalogSeedManifest();

  test('stages exactly 354 stable historical ids', () {
    expect(manifest.records, hasLength(354));
    expect(manifest.records.map((record) => record.id).toSet(), hasLength(354));
    expect(
      manifest.records.every(
        (record) => RegExp(r'^(OR|BY|FV|PL)-[0-9]{3}$').hasMatch(record.id),
      ),
      isTrue,
    );

    int count(String prefix) => manifest.records
        .where((record) => record.id.startsWith('$prefix-'))
        .length;
    expect(
      (count('OR'), count('BY'), count('FV'), count('PL')),
      (40, 107, 182, 25),
    );
  });

  test('separates staging safety from publication readiness', () {
    expect(manifest.isSafeToStage, isTrue);
    expect(manifest.isSafeToPublish, isFalse);
    expect(
      manifest.issues
          .where(
            (issue) =>
                issue.severity == CatalogSeedIssueSeverity.publishBlocker,
          )
          .map((issue) => issue.code),
      containsAll({
        'cycle_engine_bindings_not_in_source',
        'stable_domain_ids_not_reviewed',
        'authority_review_attestations_missing',
        'license_metadata_not_in_source',
        'needs_review_records_present',
      }),
    );
    expect(
      manifest.issues.where(
        (issue) => issue.severity == CatalogSeedIssueSeverity.error,
      ),
      isEmpty,
    );
  });

  test('keeps authority and review status explicit', () {
    expect(
      manifest.records.where(
        (record) =>
            record.values['authority'] == CatalogSeedAuthority.canonical.name,
      ),
      hasLength(3),
    );
    expect(
      manifest.records.where(
        (record) =>
            record.values['authority'] == CatalogSeedAuthority.compatible.name,
      ),
      hasLength(1),
    );
    expect(
      manifest.records.where(
        (record) =>
            record.values['reviewStatus'] ==
            CatalogSeedReviewStatus.confirmed.name,
      ),
      hasLength(4),
    );
    expect(
      manifest.records.where(
        (record) =>
            record.values['reviewStatus'] ==
            CatalogSeedReviewStatus.needsReview.name,
      ),
      hasLength(350),
    );
    expect(
      manifest.records.where((record) => record.values['authority'] == null),
      hasLength(350),
    );
  });

  test(
    'retains complete provenance and resolved unique generator bindings',
    () {
      for (final record in manifest.records) {
        final sources = record.values['sources']! as List<Object?>;
        expect(sources, isNotEmpty, reason: record.id);
        for (final source in sources.cast<Map<Object?, Object?>>()) {
          expect(
            (source['title']! as String).trim(),
            isNotEmpty,
            reason: record.id,
          );
          expect(
            (source['pages']! as String).trim(),
            isNotEmpty,
            reason: record.id,
          );
        }
      }
      final generatorIds = manifest.records
          .map((record) => record.values['generatorId'])
          .whereType<String>()
          .toList();
      expect(generatorIds.toSet(), hasLength(generatorIds.length));
      expect(generatorIds.toSet(), catalogGeneratorStrategies);
      expect(
        manifest.issues.map((issue) => issue.code),
        isNot(contains('missing_source_provenance')),
      );
      expect(
        manifest.issues.map((issue) => issue.code),
        isNot(contains('unresolved_generator_id')),
      );
    },
  );

  test('manifest and record hashes are deterministic', () {
    final rebuilt = buildCatalogSeedManifest();
    expect(manifest.manifestVersion, catalogSeedManifestVersion);
    expect(rebuilt.sourceHash, manifest.sourceHash);
    expect(
      rebuilt.records.map((record) => record.recordHash),
      manifest.records.map((record) => record.recordHash),
    );
    expect(manifest.canonicalizationVersion, 1);
    expect(manifest.hashAlgorithm, 'SHA-256');
    expect(manifest.sourceHash, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      manifest.records.every(
        (record) => RegExp(r'^[0-9a-f]{64}$').hasMatch(record.recordHash),
      ),
      isTrue,
    );
  });

  test('SHA-256 implementation matches its public attestation vector', () {
    expect(
      computeCatalogSeedSha256('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('keeps catalogue keys separate from unmapped stable domain ids', () {
    expect(
      manifest.records.every(
        (record) => record.values['catalogEntryKey'] == record.id,
      ),
      isTrue,
    );
    expect(
      manifest.records.every(
        (record) => record.values['stableDomainId'] == null,
      ),
      isTrue,
    );
  });

  test('targets isolated staging only and keeps runtime gate closed', () {
    expect(manifest.target, CatalogSeedTarget.isolatedStaging);
    expect(manifest.isSafeToStage, isTrue);
    expect(manifest.isSafeToImportIntoRuntime, isFalse);
    expect(manifest.isSafeToPublish, isFalse);
  });

  test('uses explicit visibility and emits four reviewed legacy bindings', () {
    final attested = manifest.records.where(
      (record) => record.values['authority'] != null,
    );
    expect(attested, hasLength(4));
    expect(
      attested.every(
        (record) =>
            record.values['reviewStatus'] == 'confirmed' &&
            record.values['visibility'] == 'internal',
      ),
      isTrue,
    );
    expect(
      manifest.records
          .where((record) => record.values['authority'] == null)
          .every(
            (record) =>
                record.values['reviewStatus'] == 'needsReview' &&
                record.values['visibility'] == 'hidden',
          ),
      isTrue,
    );
    expect(
      manifest.records.every(
        (record) => (record.values['relations']! as List<Object?>).isEmpty,
      ),
      isTrue,
    );
    final bindings = manifest.records
        .expand((record) => record.values['engineBindings']! as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .toList();
    expect(bindings, hasLength(4));
    expect(
      bindings.map((binding) => binding['engineId']).toSet(),
      catalogGeneratorStrategies,
    );
  });

  test('different canonical content does not collide', () {
    final first = CatalogSeedRecord({'catalogEntryKey': 'OR-001', 'value': 1});
    final second = CatalogSeedRecord({'catalogEntryKey': 'OR-001', 'value': 2});
    expect(first.recordHash, isNot(second.recordHash));
  });

  test('rejects a source that contradicts a reviewed legacy attestation', () {
    final invalid = buildCatalogSeedManifest(
      sourceRecords: [
        _record(id: 'BY-026', generatorId: 'unexpected-generator'),
      ],
      registeredGeneratorIds: const {'unexpected-generator'},
      expectedRecordCount: 1,
    );
    expect(invalid.isSafeToStage, isFalse);
    expect(
      invalid.issues.map((issue) => issue.code),
      contains('legacy_binding_attestation_mismatch'),
    );
  });

  test('manifest values are deeply immutable', () {
    expect(
      () => manifest.records.add(manifest.records.first),
      throwsUnsupportedError,
    );
    expect(
      () => manifest.issues.add(
        const CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.info,
          code: 'test',
          message: 'test',
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => manifest.records.first.values['name'] = 'changed',
      throwsUnsupportedError,
    );
    final sources = manifest.records.first.values['sources']! as List<Object?>;
    expect(() => sources.add(const {}), throwsUnsupportedError);
    final source = sources.first as Map<Object?, Object?>;
    expect(() => source['title'] = 'changed', throwsUnsupportedError);
  });

  test('output contains no protected path, PII or secret marker', () {
    expect(
      manifest.issues.where(
        (issue) => issue.code == 'protected_or_personal_data',
      ),
      isEmpty,
    );
  });

  test('invalid source rows fail staging with typed errors', () {
    final invalid = buildCatalogSeedManifest(
      sourceRecords: [
        _record(
          id: 'or-001',
          sourceTitle: '',
          sourcePages: '',
          generatorId: 'missing-generator',
          entryKind: CatalogEntryKind.executableTemplate,
          nonExecutableReason: 'NEEDS_REVIEW: unresolved',
        ),
      ],
      registeredGeneratorIds: const {},
      expectedRecordCount: 1,
    );

    expect(invalid.isSafeToStage, isFalse);
    expect(invalid.isSafeToPublish, isFalse);
    expect(
      invalid.issues
          .where((issue) => issue.severity == CatalogSeedIssueSeverity.error)
          .map((issue) => issue.code),
      containsAll({
        'invalid_historical_id',
        'missing_source_provenance',
        'needs_review_marked_executable',
        'unresolved_generator_id',
      }),
    );
  });

  test('duplicate generator bindings and protected values fail staging', () {
    final invalid = buildCatalogSeedManifest(
      sourceRecords: [
        _record(
          id: 'OR-001',
          name: r'C:\Users\Admin\secret',
          generatorId: 'same',
        ),
        _record(id: 'OR-002', generatorId: 'same'),
      ],
      registeredGeneratorIds: const {'same'},
      expectedRecordCount: 2,
    );

    expect(invalid.isSafeToStage, isFalse);
    expect(
      invalid.issues.map((issue) => issue.code),
      containsAll({'duplicate_generator_id', 'protected_or_personal_data'}),
    );
  });
}

CatalogRecord _record({
  required String id,
  String name = 'Fixture',
  String sourceTitle = 'Fixture source',
  String sourcePages = 'p. 1',
  String? generatorId,
  CatalogEntryKind entryKind = CatalogEntryKind.documentation,
  String? nonExecutableReason = 'NEEDS_REVIEW: fixture',
}) => CatalogRecord(
  definition: ProgramDefinition(
    id: id,
    name: name,
    family: 'Fixture',
    variant: 'Fixture',
    generation: Generation.original,
    status: ProgramStatus.current,
    sourceKind: SourceKind.canonical,
    entryKind: entryKind,
    frequencies: const {4},
    levels: const {ExperienceLevel.intermediate},
    goals: const {TrainingGoal.strength},
    sources: [SourceProvenance(title: sourceTitle, pages: sourcePages)],
    generatorId: generatorId,
    nonExecutableReason: nonExecutableReason,
  ),
  nature: 'fixture',
  ambiguity: false,
);
