import 'package:hybrid_training/core/database/catalog/catalog_administration_database.dart';

import 'catalog_seed_manifest.dart';

enum CatalogSeedImportMode { simulate, apply }

final class CatalogSeedImportRequest {
  const CatalogSeedImportRequest({
    required this.versionId,
    required this.createdAt,
    this.status = 'inReview',
    this.mode = CatalogSeedImportMode.simulate,
  });

  final String versionId;
  final String createdAt;
  final String status;
  final CatalogSeedImportMode mode;
}

final class CatalogSeedImportReport {
  CatalogSeedImportReport({
    required this.mode,
    required this.manifestHash,
    required this.catalogVersionId,
    required this.versionCreated,
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.rejected,
    required this.blockersRetained,
    required List<CatalogSeedIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final CatalogSeedImportMode mode;
  final String manifestHash;
  final String? catalogVersionId;
  final bool versionCreated;
  final int inserted;
  final int updated;
  final int unchanged;
  final int rejected;
  final int blockersRetained;
  final List<CatalogSeedIssue> issues;

  bool get applied => mode == CatalogSeedImportMode.apply && rejected == 0;
  bool get isValid => rejected == 0;
}

/// Imports the neutral seed only into administration staging.
///
/// The database facade owns the SQLite transaction. This adapter never sees a
/// database handle and cannot publish or populate normalized runtime tables.
final class CatalogSeedImporter {
  const CatalogSeedImporter(this._database);

  final CatalogAdministrationDatabase _database;

  Future<CatalogSeedImportReport> run({
    required CatalogSeedManifest manifest,
    required CatalogSeedImportRequest request,
  }) async {
    final requestIssues = _validateRequest(request);
    final issues = [...manifest.issues, ...requestIssues];
    final hasErrors = issues.any(
      (issue) => issue.severity == CatalogSeedIssueSeverity.error,
    );
    if (hasErrors) {
      return CatalogSeedImportReport(
        mode: request.mode,
        manifestHash: manifest.sourceHash,
        catalogVersionId: null,
        versionCreated: false,
        inserted: 0,
        updated: 0,
        unchanged: 0,
        rejected: manifest.records.length,
        blockersRetained: 0,
        issues: issues,
      );
    }

    return _database.transaction((transaction) async {
      final existingVersion = await transaction.findVersionByContentHash(
        manifest.sourceHash,
      );
      final versionId = existingVersion?.id ?? request.versionId;
      var inserted = 0;
      var updated = 0;
      var unchanged = 0;

      for (final record in manifest.records) {
        final write = _entryWrite(
          record: record,
          versionId: versionId,
          manifestHash: manifest.sourceHash,
        );
        final existing = existingVersion == null
            ? null
            : await transaction.findEntry(
                catalogVersionId: versionId,
                catalogEntryKey: record.id,
              );
        if (existing == null) {
          inserted++;
        } else if (_sameEntry(existing, write)) {
          unchanged++;
        } else {
          updated++;
        }
      }

      if (request.mode == CatalogSeedImportMode.simulate) {
        return CatalogSeedImportReport(
          mode: request.mode,
          manifestHash: manifest.sourceHash,
          catalogVersionId: versionId,
          versionCreated: existingVersion == null,
          inserted: inserted,
          updated: updated,
          unchanged: unchanged,
          rejected: 0,
          blockersRetained: issues.length,
          issues: issues,
        );
      }

      if (existingVersion == null) {
        await transaction.insertDraftVersion(
          CatalogDraftVersion(
            id: versionId,
            ordinal: await transaction.nextVersionOrdinal(),
            status: request.status,
            contentHash: manifest.sourceHash,
            canonicalizationVersion: manifest.canonicalizationVersion,
            signatureVerified: false,
            trustChannel: 'localReview',
            createdAt: request.createdAt,
          ),
        );
      } else if (existingVersion.status != 'draft' &&
          existingVersion.status != 'inReview') {
        throw StateError(
          'Seed staging cannot mutate catalog version ${existingVersion.id} '
          'with status ${existingVersion.status}.',
        );
      }

      for (final record in manifest.records) {
        final write = _entryWrite(
          record: record,
          versionId: versionId,
          manifestHash: manifest.sourceHash,
        );
        final existing = await transaction.findEntry(
          catalogVersionId: versionId,
          catalogEntryKey: record.id,
        );
        if (existing == null) {
          await transaction.insertEntry(write);
        } else if (!_sameEntry(existing, write)) {
          await transaction.updateEntry(write);
        }
      }
      final blockers = issues
          .map(
            (issue) => CatalogImportBlockerWrite(
              id: _blockerId(issue),
              catalogVersionId: versionId,
              catalogEntryKey: issue.catalogueId,
              issueCode: issue.code,
              severity: issue.severity.name,
              message: issue.message,
            ),
          )
          .toList(growable: false);
      await transaction.replaceImportBlockers(
        catalogVersionId: versionId,
        blockers: blockers,
      );

      return CatalogSeedImportReport(
        mode: request.mode,
        manifestHash: manifest.sourceHash,
        catalogVersionId: versionId,
        versionCreated: existingVersion == null,
        inserted: inserted,
        updated: updated,
        unchanged: unchanged,
        rejected: 0,
        blockersRetained: issues.length,
        issues: issues,
      );
    });
  }

  List<CatalogSeedIssue> _validateRequest(CatalogSeedImportRequest request) {
    final issues = <CatalogSeedIssue>[];
    if (request.versionId.trim().isEmpty) {
      issues.add(
        const CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'missing_catalog_version_id',
          message: 'A caller-supplied catalog version id is required.',
        ),
      );
    }
    if (request.createdAt.trim().isEmpty) {
      issues.add(
        const CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'missing_created_at',
          message: 'A caller-supplied creation timestamp is required.',
        ),
      );
    }
    if (request.status != 'draft' && request.status != 'inReview') {
      issues.add(
        const CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'invalid_staging_version_status',
          message: 'Seed imports may create only draft or inReview versions.',
        ),
      );
    }
    return issues;
  }

  CatalogEntryWrite _entryWrite({
    required CatalogSeedRecord record,
    required String versionId,
    required String manifestHash,
  }) => CatalogEntryWrite(
    catalogVersionId: versionId,
    catalogEntryKey: record.id,
    canonicalRecordJson: record.canonicalJson,
    recordHash: record.recordHash,
    manifestHash: manifestHash,
    stableDomainId: record.values['stableDomainId'] as String?,
    authority: record.values['authority'] as String?,
    reviewStatus: record.values['reviewStatus']! as String,
    visibility: record.values['visibility']! as String,
    executionStatus: record.values['executionStatus']! as String,
  );

  bool _sameEntry(CatalogEntrySnapshot existing, CatalogEntryWrite write) =>
      existing.canonicalRecordJson == write.canonicalRecordJson &&
      existing.recordHash == write.recordHash &&
      existing.manifestHash == write.manifestHash &&
      existing.stableDomainId == write.stableDomainId &&
      existing.authority == write.authority &&
      existing.reviewStatus == write.reviewStatus &&
      existing.visibility == write.visibility &&
      existing.executionStatus == write.executionStatus;

  String _blockerId(CatalogSeedIssue issue) => computeCatalogSeedSha256(
    '${issue.catalogueId ?? ''}|${issue.code}|${issue.severity.name}|'
    '${issue.message}',
  );
}
