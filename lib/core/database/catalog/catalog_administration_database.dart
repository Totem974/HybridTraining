import 'package:sqflite/sqflite.dart';

import 'catalog_database_schema.dart';
import 'catalog_publication_service.dart';

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
