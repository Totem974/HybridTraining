import 'package:sqflite/sqflite.dart';

import 'catalog/catalog_database_schema.dart';
import 'training/training_database.dart';
import 'training/training_database_schema.dart';
import 'workspace/workspace_database_schema.dart';

class SplitLocalDatabases {
  SplitLocalDatabases({required this.rootPath, DatabaseFactory? factory})
    : _factory = factory ?? databaseFactory;

  final String rootPath;
  final DatabaseFactory _factory;

  Future<Database> openCatalog() => _factory.openDatabase(
    '$rootPath/catalog.db',
    options: OpenDatabaseOptions(
      version: CatalogDatabaseSchema.version,
      readOnly: true,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      onUpgrade: CatalogDatabaseSchema.migrate,
    ),
  );

  Future<Database> openWorkspace() => _factory.openDatabase(
    '$rootPath/workspace.db',
    options: OpenDatabaseOptions(
      version: WorkspaceDatabaseSchema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, version) => WorkspaceDatabaseSchema.create(db),
      onUpgrade: WorkspaceDatabaseSchema.migrate,
    ),
  );

  Future<TrainingDatabase> openTraining() => TrainingDatabase.open(
    path: '$rootPath/training.db',
    factory: _factory,
    options: OpenDatabaseOptions(
      version: TrainingDatabaseSchema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, version) => TrainingDatabaseSchema.create(db),
      onUpgrade: TrainingDatabaseSchema.migrate,
    ),
  );
}
