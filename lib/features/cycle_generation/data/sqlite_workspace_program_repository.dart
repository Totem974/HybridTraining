import 'package:sqflite/sqflite.dart';

import '../../../core/storage/sqlite_database_file.dart';
import '../application/workspace_program_repository.dart';
import '../domain/workspace_program.dart';

final class SqliteWorkspaceProgramRepository
    implements WorkspaceProgramRepository {
  const SqliteWorkspaceProgramRepository(this.databaseFile);

  final SqliteDatabaseFile databaseFile;

  static Future<void> createTables(Database db) async {
    await db.execute('''CREATE TABLE workspace_programs(
      id TEXT PRIMARY KEY,
      profile_id TEXT NOT NULL REFERENCES profiles(id),
      name TEXT NOT NULL,
      authority TEXT NOT NULL CHECK(authority = 'userDefined'),
      origin TEXT NOT NULL CHECK(origin = 'userDefined'),
      revision INTEGER NOT NULL CHECK(revision > 0),
      catalog_version INTEGER NOT NULL CHECK(catalog_version > 0),
      definition_json TEXT NOT NULL,
      updated_at TEXT NOT NULL)''');
  }

  @override
  Future<void> save(WorkspaceProgram program) async {
    if (program.id.trim().isEmpty ||
        program.profileId.trim().isEmpty ||
        program.name.trim().isEmpty ||
        program.revision <= 0 ||
        program.catalogVersion <= 0 ||
        program.weeks.isEmpty) {
      throw ArgumentError('A complete workspace program is required.');
    }
    final definition = const WorkspaceProgramCodec().encode(program);
    // Decode before persistence so invalid or unsupported primitives never
    // enter workspace.db.
    const WorkspaceProgramCodec().decodeDefinition(definition);
    final db = await databaseFile.open();
    await db.insert('workspace_programs', {
      'id': program.id,
      'profile_id': program.profileId,
      'name': program.name,
      'authority': 'userDefined',
      'origin': 'userDefined',
      'revision': program.revision,
      'catalog_version': program.catalogVersion,
      'definition_json': definition,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<WorkspaceProgram> load(String id) async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'workspace_programs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Workspace program not found: $id');
    final row = rows.single;
    if (row['authority'] != 'userDefined' || row['origin'] != 'userDefined') {
      throw const WorkspaceProgramFormatException(
        'Workspace programs must be userDefined',
      );
    }
    return WorkspaceProgram(
      id: row['id']! as String,
      profileId: row['profile_id']! as String,
      name: row['name']! as String,
      revision: row['revision']! as int,
      catalogVersion: row['catalog_version']! as int,
      weeks: const WorkspaceProgramCodec().decodeDefinition(
        row['definition_json']! as String,
      ),
    );
  }
}
