import 'dart:convert';

import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:sqflite_common/sqlite_api.dart';

final class StoredForeverDraft {
  const StoredForeverDraft({
    required this.id,
    required this.payloadVersion,
    required this.definitionId,
    required this.definitionRevision,
    required this.payload,
    required this.updatedAt,
  });
  final String id;
  final int payloadVersion;
  final String definitionId;
  final int definitionRevision;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
}

final class SqliteForeverDraftRepository {
  const SqliteForeverDraftRepository(this.databaseFile);
  final SqliteDatabaseFile databaseFile;

  Future<void> save(StoredForeverDraft draft) async {
    if (draft.payloadVersion < 1 || draft.definitionRevision < 1) {
      throw ArgumentError('Positive payload and definition versions required.');
    }
    final db = await databaseFile.open();
    await db.insert('forever_drafts', {
      'draft_id': draft.id,
      'payload_version': draft.payloadVersion,
      'definition_id': draft.definitionId,
      'definition_revision': draft.definitionRevision,
      'payload_json': jsonEncode(draft.payload),
      'updated_at': draft.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<StoredForeverDraft?> load(String id) async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'forever_drafts',
      where: 'draft_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final payload = jsonDecode(row['payload_json']! as String);
    if (payload is! Map<String, Object?>) {
      throw const FormatException('Invalid Forever draft payload.');
    }
    return StoredForeverDraft(
      id: row['draft_id']! as String,
      payloadVersion: row['payload_version']! as int,
      definitionId: row['definition_id']! as String,
      definitionRevision: row['definition_revision']! as int,
      payload: payload,
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
