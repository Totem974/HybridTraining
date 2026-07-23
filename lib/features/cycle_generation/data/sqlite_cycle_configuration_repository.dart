import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/sqlite_database_file.dart';
import '../application/cycle_configuration_repository.dart';
import '../domain/cycle_configuration_record.dart';

final class SqliteCycleConfigurationRepository
    implements CycleConfigurationRepository {
  const SqliteCycleConfigurationRepository(this.databaseFile);

  final SqliteDatabaseFile databaseFile;

  @override
  Future<void> create(CycleConfigurationRecord configuration) async {
    _validate(configuration);
    final db = await databaseFile.open();
    await db.insert(
      'cycle_configurations',
      _toRow(configuration),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> update(CycleConfigurationRecord configuration) async {
    _validate(configuration);
    final db = await databaseFile.open();
    await db.transaction((transaction) async {
      final existing = await transaction.query(
        'cycle_configurations',
        columns: ['created_at'],
        where: 'id = ?',
        whereArgs: [configuration.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('Cycle configuration not found: ${configuration.id}');
      }
      final row = _toRow(configuration)
        ..['created_at'] = existing.single['created_at'];
      await transaction.update(
        'cycle_configurations',
        row,
        where: 'id = ?',
        whereArgs: [configuration.id],
      );
    });
  }

  @override
  Future<CycleConfigurationRecord?> find(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be blank.');
    }
    final db = await databaseFile.open();
    final rows = await db.query(
      'cycle_configurations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<List<CycleConfigurationRecord>> list({
    String? profileId,
    bool includeArchived = false,
  }) async {
    if (profileId != null && profileId.trim().isEmpty) {
      throw ArgumentError.value(profileId, 'profileId', 'Must not be blank.');
    }
    final predicates = <String>[];
    final arguments = <Object?>[];
    if (profileId != null) {
      predicates.add('profile_id = ?');
      arguments.add(profileId);
    }
    if (!includeArchived) predicates.add('archived_at IS NULL');
    final db = await databaseFile.open();
    final rows = await db.query(
      'cycle_configurations',
      where: predicates.isEmpty ? null : predicates.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'updated_at DESC, id ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> archive(String id, DateTime archivedAt) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be blank.');
    }
    final timestamp = archivedAt.toUtc().toIso8601String();
    final db = await databaseFile.open();
    final changed = await db.update(
      'cycle_configurations',
      {'archived_at': timestamp, 'updated_at': timestamp},
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) {
      throw StateError('Active cycle configuration not found: $id');
    }
  }

  static void _validate(CycleConfigurationRecord configuration) {
    if (configuration.id.trim().isEmpty ||
        configuration.name.trim().isEmpty ||
        configuration.profileId?.trim().isEmpty == true ||
        configuration.formatVersion <= 0 ||
        configuration.catalogVersion <= 0 ||
        configuration.catalogHash.trim().isEmpty ||
        configuration.updatedAt.isBefore(configuration.createdAt)) {
      throw const FormatException('Invalid cycle configuration metadata.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(configuration.configurationJson);
    } on FormatException {
      throw const FormatException('Invalid cycle configuration JSON.');
    }
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != 'hybrid-training-cycle' ||
        decoded['configurationVersion'] != configuration.formatVersion ||
        decoded['catalogVersion'] != configuration.catalogVersion ||
        decoded['catalogHash'] != configuration.catalogHash) {
      throw const FormatException(
        'Cycle configuration metadata does not match its envelope.',
      );
    }
    _validateStructure(decoded);
  }

  static void _validateStructure(Map<String, Object?> decoded) {
    const expectedKeys = {
      'format',
      'configurationVersion',
      'catalogVersion',
      'catalogHash',
      'template',
      'commonOptions',
      'maxes',
      'schedule',
      'equipment',
      'output',
    };
    if (decoded.keys.any((key) => !expectedKeys.contains(key)) ||
        decoded['template'] is! Map<String, Object?> ||
        decoded['commonOptions'] is! Map<String, Object?> ||
        decoded['maxes'] is! Map<String, Object?> ||
        decoded['schedule'] is! Map<String, Object?> ||
        decoded['equipment'] is! Map<String, Object?> ||
        decoded['output'] is! Map<String, Object?>) {
      throw const FormatException('Invalid cycle configuration structure.');
    }

    final template = decoded['template']! as Map<String, Object?>;
    final commonOptions = decoded['commonOptions']! as Map<String, Object?>;
    final maxes = decoded['maxes']! as Map<String, Object?>;
    final schedule = decoded['schedule']! as Map<String, Object?>;
    final equipment = decoded['equipment']! as Map<String, Object?>;
    final output = decoded['output']! as Map<String, Object?>;
    final hasProfile = equipment['barProfileId'] is String;
    final hasInlineBar = equipment['bar'] is Map<String, Object?>;

    if (template['id'] is! String ||
        (template['id']! as String).trim().isEmpty ||
        template['variantId'] is! String ||
        template['options'] is! Map<String, Object?> ||
        commonOptions['warmUp'] is! Map<String, Object?> ||
        commonOptions['joker'] is! Map<String, Object?> ||
        commonOptions['deload'] is! Map<String, Object?> ||
        !const {
          'oneRepMax',
          'directTrainingMax',
          'repMax',
        }.contains(maxes['mode']) ||
        maxes['globalTrainingMaxRatioBasisPoints'] is! int ||
        maxes['values'] is! Map<String, Object?> ||
        schedule['id'] is! String ||
        schedule['startDate'] is! String ||
        schedule['sessionOrder'] is! List<Object?> ||
        !const {'kg', 'lb'}.contains(equipment['unit']) ||
        hasProfile == hasInlineBar ||
        output['title'] is! String ||
        output['showPlating'] is! bool) {
      throw const FormatException('Invalid cycle configuration structure.');
    }
  }

  static Map<String, Object?> _toRow(CycleConfigurationRecord configuration) =>
      {
        'id': configuration.id,
        'profile_id': configuration.profileId,
        'name': configuration.name,
        'format_version': configuration.formatVersion,
        'catalog_version': configuration.catalogVersion,
        'catalog_hash': configuration.catalogHash,
        'configuration_json': configuration.configurationJson,
        'created_at': configuration.createdAt.toUtc().toIso8601String(),
        'updated_at': configuration.updatedAt.toUtc().toIso8601String(),
        'archived_at': configuration.archivedAt?.toUtc().toIso8601String(),
      };

  static CycleConfigurationRecord _fromRow(Map<String, Object?> row) =>
      CycleConfigurationRecord(
        id: row['id']! as String,
        profileId: row['profile_id'] as String?,
        name: row['name']! as String,
        formatVersion: row['format_version']! as int,
        catalogVersion: row['catalog_version']! as int,
        catalogHash: row['catalog_hash']! as String,
        configurationJson: row['configuration_json']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
        archivedAt: row['archived_at'] == null
            ? null
            : DateTime.parse(row['archived_at']! as String),
      );
}
