import 'package:sqflite_common/sqlite_api.dart';

final class SqliteDatabaseFile {
  SqliteDatabaseFile({
    required this.fileName,
    required this.version,
    required this.onCreate,
    this.onUpgrade,
    required this.factory,
    this.databasePath,
  });

  final String fileName;
  final int version;
  final Future<void> Function(Database database, int version) onCreate;
  final Future<void> Function(
    Database database,
    int oldVersion,
    int newVersion,
  )?
  onUpgrade;
  final DatabaseFactory factory;
  final String? databasePath;
  Database? _database;

  Future<Database> open() async {
    if (_database case final database? when database.isOpen) return database;
    final selectedFactory = factory;
    final root = databasePath ?? await selectedFactory.getDatabasesPath();
    _database = await selectedFactory.openDatabase(
      databasePath ?? '$root/$fileName',
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
