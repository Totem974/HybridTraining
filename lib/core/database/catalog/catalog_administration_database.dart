import 'package:sqflite/sqflite.dart';

import 'catalog_database_schema.dart';
import 'catalog_publication_service.dart';

/// Immutable catalog-version fields exposed to administration tooling.
final class CatalogVersionSnapshot {
  const CatalogVersionSnapshot({
    required this.id,
    required this.ordinal,
    required this.status,
    required this.contentHash,
    required this.canonicalizationVersion,
    required this.trustChannel,
    required this.createdAt,
  });

  final String id;
  final int ordinal;
  final String status;
  final String contentHash;
  final int canonicalizationVersion;
  final String trustChannel;
  final String createdAt;
}

/// Complete input for a non-published catalog version.
final class CatalogDraftVersion {
  const CatalogDraftVersion({
    required this.id,
    required this.ordinal,
    required this.status,
    required this.contentHash,
    required this.canonicalizationVersion,
    required this.signatureVerified,
    required this.trustChannel,
    required this.createdAt,
    this.parentVersionId,
    this.signature,
    this.signatureKeyId,
    this.signatureAlgorithm,
  });

  final String id;
  final int ordinal;
  final String status;
  final String? parentVersionId;
  final String contentHash;
  final int canonicalizationVersion;
  final String? signature;
  final String? signatureKeyId;
  final String? signatureAlgorithm;
  final bool signatureVerified;
  final String trustChannel;
  final String createdAt;
}

/// Immutable snapshot of an administration-only staged manifest record.
final class CatalogEntrySnapshot {
  const CatalogEntrySnapshot({
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.canonicalRecordJson,
    required this.recordHash,
    required this.manifestHash,
    required this.stableDomainId,
    required this.authority,
    required this.reviewStatus,
    required this.visibility,
    required this.executionStatus,
  });

  final String catalogVersionId;
  final String catalogEntryKey;
  final String canonicalRecordJson;
  final String recordHash;
  final String manifestHash;
  final String? stableDomainId;
  final String? authority;
  final String reviewStatus;
  final String visibility;
  final String executionStatus;
}

/// Complete schema fields for an administration-only staged manifest record.
final class CatalogEntryWrite {
  const CatalogEntryWrite({
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.canonicalRecordJson,
    required this.recordHash,
    required this.manifestHash,
    required this.stableDomainId,
    required this.authority,
    required this.reviewStatus,
    required this.visibility,
    required this.executionStatus,
  });

  final String catalogVersionId;
  final String catalogEntryKey;
  final String canonicalRecordJson;
  final String recordHash;
  final String manifestHash;
  final String? stableDomainId;
  final String? authority;
  final String reviewStatus;
  final String visibility;
  final String executionStatus;
}

/// Structured issue retained beside a staged manifest record.
final class CatalogImportBlockerWrite {
  const CatalogImportBlockerWrite({
    required this.id,
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.issueCode,
    required this.severity,
    required this.message,
  });

  final String id;
  final String catalogVersionId;
  final String? catalogEntryKey;
  final String issueCode;
  final String severity;
  final String message;
}

final class CatalogImportBlockerSnapshot {
  const CatalogImportBlockerSnapshot({
    required this.id,
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.issueCode,
    required this.severity,
    required this.message,
  });

  final String id;
  final String catalogVersionId;
  final String? catalogEntryKey;
  final String issueCode;
  final String severity;
  final String message;
}

final class CatalogPromotionBatchWrite {
  const CatalogPromotionBatchWrite({
    required this.id,
    required this.catalogVersionId,
    required this.sourceManifestHash,
    required this.status,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final String catalogVersionId;
  final String sourceManifestHash;
  final String status;
  final String createdAt;
  final String? completedAt;
}

final class CatalogPromotionItemWrite {
  const CatalogPromotionItemWrite({
    required this.id,
    required this.promotionBatchId,
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.sourceRecordHash,
    required this.targetCatalogEntryId,
    required this.status,
    required this.issueCode,
  });

  final String id;
  final String promotionBatchId;
  final String catalogVersionId;
  final String catalogEntryKey;
  final String sourceRecordHash;
  final String? targetCatalogEntryId;
  final String status;
  final String? issueCode;
}

final class CatalogPromotionBatchSnapshot {
  const CatalogPromotionBatchSnapshot({
    required this.id,
    required this.catalogVersionId,
    required this.sourceManifestHash,
    required this.status,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final String catalogVersionId;
  final String sourceManifestHash;
  final String status;
  final String createdAt;
  final String? completedAt;
}

final class CatalogPromotionItemSnapshot {
  const CatalogPromotionItemSnapshot({
    required this.id,
    required this.promotionBatchId,
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.sourceRecordHash,
    required this.targetCatalogEntryId,
    required this.status,
    required this.issueCode,
  });

  final String id;
  final String promotionBatchId;
  final String catalogVersionId;
  final String catalogEntryKey;
  final String sourceRecordHash;
  final String? targetCatalogEntryId;
  final String status;
  final String? issueCode;
}

final class CatalogGovernedEntryWrite {
  const CatalogGovernedEntryWrite({
    required this.id,
    required this.catalogVersionId,
    required this.catalogEntryKey,
    required this.stableDomainId,
    required this.nature,
    required this.authority,
    required this.reviewStatus,
    required this.implementationStatus,
    required this.executionStatus,
    required this.productSurface,
    required this.visibility,
    required this.licenseStatus,
  });

  final String id;
  final String catalogVersionId;
  final String catalogEntryKey;
  final String stableDomainId;
  final String nature;
  final String authority;
  final String reviewStatus;
  final String implementationStatus;
  final String executionStatus;
  final String productSurface;
  final String visibility;
  final String licenseStatus;
}

final class CatalogEvidenceWrite {
  const CatalogEvidenceWrite({
    required this.id,
    required this.catalogVersionId,
    required this.sourceId,
    required this.ruleId,
    required this.subjectType,
    required this.subjectId,
    required this.reviewStatus,
    required this.contentReuse,
    required this.excerptDigest,
    required this.note,
  });

  final String id;
  final String catalogVersionId;
  final String sourceId;
  final String ruleId;
  final String subjectType;
  final String subjectId;
  final String reviewStatus;
  final String contentReuse;
  final String? excerptDigest;
  final String note;
}

final class CatalogBookWrite {
  const CatalogBookWrite({
    required this.id,
    required this.title,
    required this.author,
    required this.licenseStatus,
  });

  final String id;
  final String title;
  final String? author;
  final String licenseStatus;
}

final class CatalogEditionWrite {
  const CatalogEditionWrite({
    required this.id,
    required this.bookId,
    required this.label,
    required this.publicationYear,
    required this.digest,
  });

  final String id;
  final String bookId;
  final String label;
  final int? publicationYear;
  final String? digest;
}

final class CatalogEditionSnapshot {
  const CatalogEditionSnapshot({
    required this.id,
    required this.bookId,
    required this.label,
    required this.publicationYear,
    required this.digest,
  });

  final String id;
  final String bookId;
  final String label;
  final int? publicationYear;
  final String? digest;
}

final class CatalogSourceWrite {
  const CatalogSourceWrite({
    required this.id,
    required this.editionId,
    required this.revision,
    required this.kind,
    required this.locator,
    required this.note,
  });

  final String id;
  final String? editionId;
  final int revision;
  final String kind;
  final String locator;
  final String note;
}

final class CatalogSourceSnapshot {
  const CatalogSourceSnapshot({
    required this.id,
    required this.editionId,
    required this.revision,
    required this.kind,
    required this.locator,
    required this.note,
  });

  final String id;
  final String? editionId;
  final int revision;
  final String kind;
  final String locator;
  final String note;
}

final class CatalogDeclarativeRuleWrite {
  const CatalogDeclarativeRuleWrite({
    required this.id,
    required this.catalogVersionId,
    required this.ownerType,
    required this.ownerId,
    required this.kind,
    required this.schemaVersion,
    required this.expressionJson,
    required this.blockerCode,
    required this.reviewStatus,
  });

  final String id;
  final String catalogVersionId;
  final String ownerType;
  final String ownerId;
  final String kind;
  final int schemaVersion;
  final String expressionJson;
  final String? blockerCode;
  final String reviewStatus;
}

final class CatalogEntryAliasWrite {
  const CatalogEntryAliasWrite({
    required this.id,
    required this.catalogVersionId,
    required this.namespace,
    required this.alias,
    required this.catalogEntryId,
    required this.evidenceId,
    required this.reviewStatus,
  });

  final String id;
  final String catalogVersionId;
  final String namespace;
  final String alias;
  final String catalogEntryId;
  final String evidenceId;
  final String reviewStatus;
}

/// Narrow transaction capability for catalog administration tooling.
///
/// It cannot be constructed by callers and becomes unusable as soon as its
/// callback completes. In particular, it never exposes a SQLite handle, the
/// database path, raw SQL, or generic query/execute operations.
final class CatalogAdministrationTransaction {
  CatalogAdministrationTransaction._(this._transaction);

  final Transaction _transaction;
  bool _active = true;

  Future<CatalogVersionSnapshot?> findVersionByContentHash(
    String contentHash,
  ) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_versions',
      columns: const [
        'id',
        'ordinal',
        'status',
        'content_hash',
        'canonicalization_version',
        'trust_channel',
        'created_at',
      ],
      where: 'content_hash=?',
      whereArgs: [contentHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _versionSnapshot(rows.single);
  }

  Future<CatalogVersionSnapshot?> findVersionById(String id) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_versions',
      columns: const [
        'id',
        'ordinal',
        'status',
        'content_hash',
        'canonicalization_version',
        'trust_channel',
        'created_at',
      ],
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _versionSnapshot(rows.single);
  }

  Future<int> nextVersionOrdinal() async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_versions',
      columns: const ['ordinal'],
      orderBy: 'ordinal DESC',
      limit: 1,
    );
    return rows.isEmpty ? 1 : (rows.single['ordinal']! as int) + 1;
  }

  Future<void> insertDraftVersion(CatalogDraftVersion version) async {
    _ensureActive();
    if (version.status != 'draft' && version.status != 'inReview') {
      throw ArgumentError.value(
        version.status,
        'version.status',
        'Administration imports may create only draft or inReview versions.',
      );
    }
    await _transaction.insert('catalog_versions', {
      'id': version.id,
      'ordinal': version.ordinal,
      'status': version.status,
      'parent_version_id': version.parentVersionId,
      'content_hash': version.contentHash,
      'canonicalization_version': version.canonicalizationVersion,
      'signature': version.signature,
      'signature_key_id': version.signatureKeyId,
      'signature_algorithm': version.signatureAlgorithm,
      'signature_verified': version.signatureVerified ? 1 : 0,
      'trust_channel': version.trustChannel,
      'created_at': version.createdAt,
    });
  }

  Future<CatalogEntrySnapshot?> findEntry({
    required String catalogVersionId,
    required String catalogEntryKey,
  }) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_staging_entries',
      where: 'catalog_version_id=? AND catalog_entry_key=?',
      whereArgs: [catalogVersionId, catalogEntryKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _entrySnapshot(rows.single);
  }

  Future<List<CatalogEntrySnapshot>> listStagedEntries(
    String catalogVersionId,
  ) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_staging_entries',
      where: 'catalog_version_id=?',
      whereArgs: [catalogVersionId],
      orderBy: 'catalog_entry_key',
    );
    return List.unmodifiable(rows.map(_entrySnapshot));
  }

  Future<List<CatalogImportBlockerSnapshot>> listImportBlockers(
    String catalogVersionId,
  ) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_import_blockers',
      where: 'catalog_version_id=?',
      whereArgs: [catalogVersionId],
      orderBy: 'id',
    );
    return List.unmodifiable(
      rows.map(
        (row) => CatalogImportBlockerSnapshot(
          id: row['id']! as String,
          catalogVersionId: row['catalog_version_id']! as String,
          catalogEntryKey: row['catalog_entry_key'] as String?,
          issueCode: row['issue_code']! as String,
          severity: row['severity']! as String,
          message: row['message']! as String,
        ),
      ),
    );
  }

  Future<void> insertEntry(CatalogEntryWrite entry) async {
    _ensureActive();
    await _transaction.insert('catalog_staging_entries', _entryValues(entry));
  }

  Future<void> updateEntry(CatalogEntryWrite entry) async {
    _ensureActive();
    final changed = await _transaction.update(
      'catalog_staging_entries',
      _entryValues(entry),
      where: 'catalog_version_id=? AND catalog_entry_key=?',
      whereArgs: [entry.catalogVersionId, entry.catalogEntryKey],
    );
    if (changed != 1) {
      throw StateError(
        'No staged catalog entry ${entry.catalogEntryKey} exists in '
        '${entry.catalogVersionId}.',
      );
    }
  }

  Future<void> insertImportBlocker(CatalogImportBlockerWrite blocker) async {
    _ensureActive();
    await _insertImportBlocker(blocker);
  }

  /// Atomically replaces the complete blocker set owned by one import version.
  Future<void> replaceImportBlockers({
    required String catalogVersionId,
    required List<CatalogImportBlockerWrite> blockers,
  }) async {
    _ensureActive();
    for (final blocker in blockers) {
      if (blocker.catalogVersionId != catalogVersionId) {
        throw ArgumentError.value(
          blocker.catalogVersionId,
          'blockers.catalogVersionId',
          'Every blocker must belong to $catalogVersionId.',
        );
      }
    }
    await _transaction.delete(
      'catalog_import_blockers',
      where: 'catalog_version_id=?',
      whereArgs: [catalogVersionId],
    );
    for (final blocker in blockers) {
      await _insertImportBlocker(blocker);
    }
  }

  Future<CatalogPromotionBatchSnapshot?> findPromotionBatch({
    required String targetVersionId,
    required String sourceManifestHash,
  }) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_promotion_batches',
      where: 'catalog_version_id=? AND source_manifest_hash=?',
      whereArgs: [targetVersionId, sourceManifestHash],
      limit: 1,
    );
    return rows.isEmpty ? null : _promotionBatchSnapshot(rows.single);
  }

  Future<CatalogPromotionBatchSnapshot?> findAppliedPromotion({
    required String sourceManifestHash,
    required String targetContentHash,
  }) async {
    _ensureActive();
    final version = await findVersionByContentHash(targetContentHash);
    if (version == null) return null;
    final batch = await findPromotionBatch(
      targetVersionId: version.id,
      sourceManifestHash: sourceManifestHash,
    );
    return batch?.status == 'applied' ? batch : null;
  }

  Future<List<CatalogPromotionItemSnapshot>> listPromotionItems(
    String promotionBatchId,
  ) async {
    _ensureActive();
    final rows = await _transaction.query(
      'catalog_promotion_items',
      where: 'promotion_batch_id=?',
      whereArgs: [promotionBatchId],
      orderBy: 'catalog_entry_key',
    );
    return List.unmodifiable(
      rows.map(
        (row) => CatalogPromotionItemSnapshot(
          id: row['id']! as String,
          promotionBatchId: row['promotion_batch_id']! as String,
          catalogVersionId: row['catalog_version_id']! as String,
          catalogEntryKey: row['catalog_entry_key']! as String,
          sourceRecordHash: row['source_record_hash']! as String,
          targetCatalogEntryId: row['target_catalog_entry_id'] as String?,
          status: row['status']! as String,
          issueCode: row['issue_code'] as String?,
        ),
      ),
    );
  }

  Future<void> insertGovernedEntry(CatalogGovernedEntryWrite entry) async {
    _ensureActive();
    await _transaction.insert('catalog_entries', {
      'id': entry.id,
      'catalog_version_id': entry.catalogVersionId,
      'catalog_entry_key': entry.catalogEntryKey,
      'stable_domain_id': entry.stableDomainId,
      'nature': entry.nature,
      'authority': entry.authority,
      'review_status': entry.reviewStatus,
      'implementation_status': entry.implementationStatus,
      'execution_status': entry.executionStatus,
      'product_surface': entry.productSurface,
      'visibility': entry.visibility,
      'license_status': entry.licenseStatus,
    });
  }

  Future<void> insertEvidence(CatalogEvidenceWrite evidence) async {
    _ensureActive();
    await _transaction.insert('evidence', {
      'id': evidence.id,
      'catalog_version_id': evidence.catalogVersionId,
      'source_id': evidence.sourceId,
      'rule_id': evidence.ruleId,
      'subject_type': evidence.subjectType,
      'subject_id': evidence.subjectId,
      'review_status': evidence.reviewStatus,
      'content_reuse': evidence.contentReuse,
      'excerpt_digest': evidence.excerptDigest,
      'note': evidence.note,
    });
  }

  Future<CatalogSourceSnapshot?> findSourceById(String id) async {
    _ensureActive();
    final rows = await _transaction.query(
      'sources',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CatalogSourceSnapshot(
      id: row['id']! as String,
      editionId: row['edition_id'] as String?,
      revision: row['revision']! as int,
      kind: row['kind']! as String,
      locator: row['locator']! as String,
      note: row['note']! as String,
    );
  }

  Future<void> insertBook(CatalogBookWrite book) async {
    _ensureActive();
    await _transaction.insert('books', {
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'license_status': book.licenseStatus,
    });
  }

  Future<CatalogEditionSnapshot?> findEditionById(String id) async {
    _ensureActive();
    final rows = await _transaction.query(
      'editions',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CatalogEditionSnapshot(
      id: row['id']! as String,
      bookId: row['book_id']! as String,
      label: row['label']! as String,
      publicationYear: row['publication_year'] as int?,
      digest: row['digest'] as String?,
    );
  }

  Future<void> insertEdition(CatalogEditionWrite edition) async {
    _ensureActive();
    await _transaction.insert('editions', {
      'id': edition.id,
      'book_id': edition.bookId,
      'label': edition.label,
      'publication_year': edition.publicationYear,
      'digest': edition.digest,
    });
  }

  Future<void> insertSource(CatalogSourceWrite source) async {
    _ensureActive();
    await _transaction.insert('sources', {
      'id': source.id,
      'edition_id': source.editionId,
      'revision': source.revision,
      'kind': source.kind,
      'locator': source.locator,
      'note': source.note,
    });
  }

  Future<void> insertDeclarativeRule(CatalogDeclarativeRuleWrite rule) async {
    _ensureActive();
    await _transaction.insert('declarative_rules', {
      'id': rule.id,
      'catalog_version_id': rule.catalogVersionId,
      'owner_type': rule.ownerType,
      'owner_id': rule.ownerId,
      'kind': rule.kind,
      'expression_json': rule.expressionJson,
      'blocker_code': rule.blockerCode,
      'schema_version': rule.schemaVersion,
      'review_status': rule.reviewStatus,
    });
  }

  Future<void> insertPromotionBatch(CatalogPromotionBatchWrite batch) async {
    _ensureActive();
    await _transaction.insert('catalog_promotion_batches', {
      'id': batch.id,
      'catalog_version_id': batch.catalogVersionId,
      'source_manifest_hash': batch.sourceManifestHash,
      'status': batch.status,
      'created_at': batch.createdAt,
      'completed_at': batch.completedAt,
    });
  }

  Future<void> updatePromotionBatch(CatalogPromotionBatchWrite batch) async {
    _ensureActive();
    final changed = await _transaction.update(
      'catalog_promotion_batches',
      {
        'source_manifest_hash': batch.sourceManifestHash,
        'status': batch.status,
        'created_at': batch.createdAt,
        'completed_at': batch.completedAt,
      },
      where: 'id=? AND catalog_version_id=?',
      whereArgs: [batch.id, batch.catalogVersionId],
    );
    if (changed != 1) {
      throw StateError('Promotion batch not found: ${batch.id}.');
    }
  }

  Future<void> insertPromotionItem(CatalogPromotionItemWrite item) async {
    _ensureActive();
    await _transaction.insert('catalog_promotion_items', {
      'id': item.id,
      'promotion_batch_id': item.promotionBatchId,
      'catalog_version_id': item.catalogVersionId,
      'catalog_entry_key': item.catalogEntryKey,
      'source_record_hash': item.sourceRecordHash,
      'target_catalog_entry_id': item.targetCatalogEntryId,
      'status': item.status,
      'issue_code': item.issueCode,
    });
  }

  Future<void> updatePromotionItem(CatalogPromotionItemWrite item) async {
    _ensureActive();
    final changed = await _transaction.update(
      'catalog_promotion_items',
      {
        'promotion_batch_id': item.promotionBatchId,
        'catalog_entry_key': item.catalogEntryKey,
        'source_record_hash': item.sourceRecordHash,
        'target_catalog_entry_id': item.targetCatalogEntryId,
        'status': item.status,
        'issue_code': item.issueCode,
      },
      where: 'id=? AND catalog_version_id=?',
      whereArgs: [item.id, item.catalogVersionId],
    );
    if (changed != 1) {
      throw StateError('Promotion item not found: ${item.id}.');
    }
  }

  Future<void> insertEntryAlias(CatalogEntryAliasWrite alias) async {
    _ensureActive();
    await _transaction.insert('catalog_entry_aliases', {
      'id': alias.id,
      'catalog_version_id': alias.catalogVersionId,
      'namespace': alias.namespace,
      'alias': alias.alias,
      'catalog_entry_id': alias.catalogEntryId,
      'evidence_id': alias.evidenceId,
      'review_status': alias.reviewStatus,
    });
  }

  Future<void> _insertImportBlocker(CatalogImportBlockerWrite blocker) async {
    await _transaction.insert('catalog_import_blockers', {
      'id': blocker.id,
      'catalog_version_id': blocker.catalogVersionId,
      'catalog_entry_key': blocker.catalogEntryKey,
      'issue_code': blocker.issueCode,
      'severity': blocker.severity,
      'message': blocker.message,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  CatalogVersionSnapshot _versionSnapshot(Map<String, Object?> row) =>
      CatalogVersionSnapshot(
        id: row['id']! as String,
        ordinal: row['ordinal']! as int,
        status: row['status']! as String,
        contentHash: row['content_hash']! as String,
        canonicalizationVersion: row['canonicalization_version']! as int,
        trustChannel: row['trust_channel']! as String,
        createdAt: row['created_at']! as String,
      );

  CatalogEntrySnapshot _entrySnapshot(Map<String, Object?> row) =>
      CatalogEntrySnapshot(
        catalogVersionId: row['catalog_version_id']! as String,
        catalogEntryKey: row['catalog_entry_key']! as String,
        canonicalRecordJson: row['canonical_record_json']! as String,
        recordHash: row['record_hash']! as String,
        manifestHash: row['manifest_hash']! as String,
        stableDomainId: row['stable_domain_id'] as String?,
        authority: row['authority'] as String?,
        reviewStatus: row['review_status']! as String,
        visibility: row['visibility']! as String,
        executionStatus: row['execution_status']! as String,
      );

  CatalogPromotionBatchSnapshot _promotionBatchSnapshot(
    Map<String, Object?> row,
  ) => CatalogPromotionBatchSnapshot(
    id: row['id']! as String,
    catalogVersionId: row['catalog_version_id']! as String,
    sourceManifestHash: row['source_manifest_hash']! as String,
    status: row['status']! as String,
    createdAt: row['created_at']! as String,
    completedAt: row['completed_at'] as String?,
  );

  Map<String, Object?> _entryValues(CatalogEntryWrite entry) => {
    'catalog_version_id': entry.catalogVersionId,
    'catalog_entry_key': entry.catalogEntryKey,
    'canonical_record_json': entry.canonicalRecordJson,
    'record_hash': entry.recordHash,
    'manifest_hash': entry.manifestHash,
    'stable_domain_id': entry.stableDomainId,
    'authority': entry.authority,
    'review_status': entry.reviewStatus,
    'visibility': entry.visibility,
    'execution_status': entry.executionStatus,
  };

  void _ensureActive() {
    if (!_active) {
      throw StateError('The catalog administration transaction has ended.');
    }
  }

  void _deactivate() => _active = false;
}

/// Tooling-only facade for the writable catalog database.
///
/// This is an API boundary, not a local security boundary: code with filesystem
/// access can still open the SQLite file itself. Runtime code must use the
/// read-only catalog facade. The writable handle deliberately never escapes
/// this class, and publication always passes through [CatalogPublicationService].
final class CatalogAdministrationDatabase {
  CatalogAdministrationDatabase({
    required this._path,
    required this._publicationService,
    DatabaseFactory? factory,
  }) : _factory = factory ?? databaseFactory;

  final String _path;
  final CatalogPublicationService _publicationService;
  final DatabaseFactory _factory;

  Future<void> initialize() => _withDatabase((_) async {});

  Future<void> publish({
    required String catalogVersionId,
    required String publishedAt,
  }) => _withDatabase(
    (database) => _publicationService.publish(
      database,
      catalogVersionId: catalogVersionId,
      publishedAt: publishedAt,
    ),
  );

  Future<T> transaction<T>(
    Future<T> Function(CatalogAdministrationTransaction transaction) operation,
  ) => _withDatabase(
    (database) => database.transaction((sqliteTransaction) async {
      final transaction = CatalogAdministrationTransaction._(sqliteTransaction);
      try {
        return await operation(transaction);
      } finally {
        transaction._deactivate();
      }
    }),
  );

  Future<T> _withDatabase<T>(
    Future<T> Function(Database database) operation,
  ) async {
    final database = await _open();
    try {
      return await operation(database);
    } finally {
      await database.close();
    }
  }

  Future<Database> _open() => _factory.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: CatalogDatabaseSchema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      onUpgrade: CatalogDatabaseSchema.migrate,
    ),
  );
}
