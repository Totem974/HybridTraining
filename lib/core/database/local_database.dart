import 'package:hybrid_training/core/database/database_schema.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase({
    this.fileName = 'hybrid_training.db',
    DatabaseFactory? factory,
    this.databasePath,
  }) : _factory = factory ?? databaseFactory;

  final String fileName;
  final String? databasePath;
  final DatabaseFactory _factory;
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final root = databasePath ?? await _factory.getDatabasesPath();
    final database = await _factory.openDatabase(
      databasePath == null ? '$root/$fileName' : root,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: (database, version) async {
          await DatabaseSchema.createV1(database);
          if (version >= 2) await DatabaseSchema.createV2(database);
        },
        onUpgrade: DatabaseSchema.migrate,
      ),
    );
    _database = database;
    return database;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
