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
    final row = rows.single;
    return CatalogVersionSnapshot(
      id: row['id']! as String,
      ordinal: row['ordinal']! as int,
      status: row['status']! as String,
      contentHash: row['content_hash']! as String,
      canonicalizationVersion: row['canonicalization_version']! as int,
      trustChannel: row['trust_channel']! as String,
      createdAt: row['created_at']! as String,
    );
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
    final row = rows.single;
    return CatalogEntrySnapshot(
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
