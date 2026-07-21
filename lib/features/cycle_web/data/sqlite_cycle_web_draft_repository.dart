import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/sqlite_database_file.dart';
import '../application/cycle_web_contract.dart';
import '../application/cycle_web_draft_repository.dart';

final class SqliteCycleWebDraftRepository implements CycleWebDraftRepository {
  const SqliteCycleWebDraftRepository({
    required this.databaseFile,
    required this.draftId,
    required this.profileId,
    required this.now,
  });

  final SqliteDatabaseFile databaseFile;
  final String draftId;
  final String profileId;
  final DateTime Function() now;

  @override
  Future<CycleEditorState?> load() async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'generation_drafts',
      columns: ['request_json'],
      where: 'id = ? AND profile_id = ?',
      whereArgs: [draftId, profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final root = jsonDecode(rows.single['request_json']! as String);
    if (root is! Map<String, Object?> ||
        root.keys.toSet().difference({
          'schemaVersion',
          'templateId',
          'variantId',
          'values',
        }).isNotEmpty ||
        root['schemaVersion'] != 1 ||
        root['templateId'] is! String ||
        root['variantId'] is! String ||
        root['values'] is! Map<String, Object?>) {
      throw const FormatException('Invalid Cycle Web draft.');
    }
    final values = root['values']! as Map<String, Object?>;
    if (values.values.any((value) => value == null || !_isJsonValue(value))) {
      throw const FormatException('Invalid Cycle Web option value.');
    }
    return CycleEditorState(
      templateId: root['templateId']! as String,
      variantId: root['variantId']! as String,
      values: values.cast<String, Object>(),
    );
  }

  @override
  Future<void> save(CycleEditorState state) async {
    if (draftId.trim().isEmpty ||
        profileId.trim().isEmpty ||
        state.templateId.trim().isEmpty ||
        state.variantId.trim().isEmpty ||
        state.values.values.any((value) => !_isJsonValue(value))) {
      throw const FormatException('Invalid Cycle Web draft.');
    }
    final db = await databaseFile.open();
    await db.insert('generation_drafts', {
      'id': draftId,
      'profile_id': profileId,
      'request_json': jsonEncode({
        'schemaVersion': 1,
        'templateId': state.templateId,
        'variantId': state.variantId,
        'values': state.values,
      }),
      'updated_at': now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static bool _isJsonValue(Object? value) =>
      value == null ||
      value is String ||
      value is num ||
      value is bool ||
      (value is List && value.every(_isJsonValue)) ||
      (value is Map<String, Object?> && value.values.every(_isJsonValue));
}
