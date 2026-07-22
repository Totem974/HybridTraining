import 'dart:convert';

import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/forever/domain/forever_contract.dart';
import 'package:sqflite_common/sqlite_api.dart';

final class StoredMacrocycle {
  const StoredMacrocycle({
    required this.id,
    required this.definitionId,
    required this.definitionRevision,
    required this.state,
    required this.logicalHash,
    required this.snapshot,
    required this.nodes,
  });
  final String id;
  final String definitionId;
  final int definitionRevision;
  final MacrocycleState state;
  final String logicalHash;
  final Map<String, Object?> snapshot;
  final List<Map<String, Object?>> nodes;
}

final class SqliteForeverMacrocycleRepository {
  const SqliteForeverMacrocycleRepository(this.databaseFile);
  final SqliteDatabaseFile databaseFile;

  Future<void> save({
    required GeneratedMacrocycle macrocycle,
    required DateTime savedAt,
  }) async {
    final snapshot = _macrocycleJson(macrocycle);
    final canonical = _canonicalJson(snapshot);
    final hash = logicalHash(canonical);
    final db = await databaseFile.open();
    await db.transaction((tx) async {
      final existing = await tx.query(
        'macrocycle_nodes',
        columns: ['node_index', 'state', 'snapshot_json'],
        where: 'macrocycle_id = ?',
        whereArgs: [macrocycle.id],
      );
      final completed = {
        for (final row in existing)
          if (row['state'] == 'completed')
            row['node_index']! as int: row['snapshot_json']! as String,
      };
      for (final node in macrocycle.nodes) {
        final nodeJson = _canonicalJson(_nodeJson(node));
        if (completed[node.index] case final old? when old != nodeJson) {
          throw StateError(
            'Completed macrocycle node ${node.index} is immutable.',
          );
        }
      }
      final now = savedAt.toUtc().toIso8601String();
      await tx.insert('macrocycles', {
        'id': macrocycle.id,
        'definition_id': macrocycle.definitionId.value,
        'definition_revision': macrocycle.definitionRevision.value,
        'state': macrocycle.state.name,
        'schema_version': 1,
        'logical_hash': hash,
        'snapshot_json': canonical,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.delete(
        'macrocycle_nodes',
        where: 'macrocycle_id = ? AND state <> ?',
        whereArgs: [macrocycle.id, 'completed'],
      );
      await tx.delete(
        'macrocycle_training_maxes',
        where: 'macrocycle_id = ?',
        whereArgs: [macrocycle.id],
      );
      for (final node in macrocycle.nodes) {
        final nodeJson = _canonicalJson(_nodeJson(node));
        await tx.insert('macrocycle_nodes', {
          'macrocycle_id': macrocycle.id,
          'node_index': node.index,
          'slot_id': node.slotId,
          'role': node.role.name,
          'cycle_id': node.cycle.id,
          'state': completed.containsKey(node.index)
              ? 'completed'
              : 'scheduled',
          'snapshot_json': nodeJson,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _saveMaxes(
          tx,
          macrocycle.id,
          node.index,
          node.trainingMaxesAfter,
        );
      }
      await tx.insert('macrocycle_events', {
        'macrocycle_id': macrocycle.id,
        'event_type': 'saved',
        'payload_json': '{}',
        'occurred_at': now,
      });
    });
  }

  Future<StoredMacrocycle> load(String id) async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'macrocycles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Macrocycle not found: $id');
    final row = rows.single;
    final nodeRows = await db.query(
      'macrocycle_nodes',
      where: 'macrocycle_id = ?',
      whereArgs: [id],
      orderBy: 'node_index ASC',
    );
    final decoded = jsonDecode(row['snapshot_json']! as String);
    final canonical = _canonicalJson(decoded);
    if (logicalHash(canonical) != row['logical_hash']) {
      throw StateError('Macrocycle snapshot hash mismatch: $id');
    }
    return StoredMacrocycle(
      id: id,
      definitionId: row['definition_id']! as String,
      definitionRevision: row['definition_revision']! as int,
      state: MacrocycleState.values.byName(row['state']! as String),
      logicalHash: row['logical_hash']! as String,
      snapshot: (decoded as Map).cast<String, Object?>(),
      nodes: nodeRows
          .map((row) {
            final value = jsonDecode(row['snapshot_json']! as String) as Map;
            return value.cast<String, Object?>();
          })
          .toList(growable: false),
    );
  }

  Future<void> completeNode(String macrocycleId, int nodeIndex) async {
    final db = await databaseFile.open();
    final count = await db.update(
      'macrocycle_nodes',
      {'state': 'completed'},
      where: 'macrocycle_id = ? AND node_index = ?',
      whereArgs: [macrocycleId, nodeIndex],
    );
    if (count != 1) throw StateError('Macrocycle node not found.');
  }

  Future<void> cancel(String macrocycleId, DateTime occurredAt) async {
    final db = await databaseFile.open();
    await db.transaction((tx) async {
      final count = await tx.update(
        'macrocycles',
        {
          'state': 'cancelled',
          'updated_at': occurredAt.toUtc().toIso8601String(),
        },
        where: 'id = ? AND state <> ?',
        whereArgs: [macrocycleId, 'completed'],
      );
      if (count != 1) throw StateError('Macrocycle cannot be cancelled.');
      await tx.insert('macrocycle_events', {
        'macrocycle_id': macrocycleId,
        'event_type': 'cancelled',
        'payload_json': '{}',
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      });
    });
  }

  static String logicalHash(String canonicalJson) {
    var first = 0x811c9dc5;
    var second = 5381;
    for (final byte in utf8.encode(canonicalJson)) {
      first = ((first ^ byte) * 0x01000193) & 0xffffffff;
      second = ((second * 33) ^ byte) & 0xffffffff;
    }
    return '${first.toRadixString(16).padLeft(8, '0')}'
        '${second.toRadixString(16).padLeft(8, '0')}';
  }
}

Future<void> _saveMaxes(
  DatabaseExecutor tx,
  String id,
  int index,
  TrainingMaxSnapshot snapshot,
) async {
  for (final entry in snapshot.values.entries) {
    await tx.insert('macrocycle_training_maxes', {
      'macrocycle_id': id,
      'node_index': index,
      'movement_id': entry.key.value,
      'value_kind': snapshot.kind.name,
      'centi_units': entry.value.centiUnits,
      'unit': entry.value.unit.name,
    });
  }
}

Map<String, Object?> _macrocycleJson(GeneratedMacrocycle value) => {
  'schemaVersion': 1,
  'id': value.id,
  'definitionId': value.definitionId.value,
  'definitionRevision': value.definitionRevision.value,
  'state': value.state.name,
  'initialTrainingMaxes': _weightsJson(value.initialTrainingMaxes),
  'projectedTrainingMaxes': _weightsJson(value.projectedTrainingMaxes),
  'nodes': value.nodes.map(_nodeJson).toList(growable: false),
};

Map<String, Object?> _nodeJson(GeneratedMacrocycleNode value) => {
  'index': value.index,
  'slotId': value.slotId,
  'role': value.role.name,
  'cycleReference': {
    'templateId': value.cycleReference.templateId,
    'templateRevision': value.cycleReference.templateRevision,
    'variantId': value.cycleReference.variantId,
    'variantRevision': value.cycleReference.variantRevision,
  },
  'cycle': value.cycle.toJson(),
  'trainingMaxesBefore': {
    'kind': value.trainingMaxesBefore.kind.name,
    'values': _weightsJson(value.trainingMaxesBefore.values),
  },
  'trainingMaxesAfter': {
    'kind': value.trainingMaxesAfter.kind.name,
    'values': _weightsJson(value.trainingMaxesAfter.values),
  },
};

Map<String, Object?> _weightsJson(Map<MovementId, Weight> values) => {
  for (final entry in values.entries) entry.key.value: entry.value.toJson(),
};

String _canonicalJson(Object? value) {
  Object? sort(Object? input) {
    if (input is Map) {
      final keys = input.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: sort(input[key])};
    }
    if (input is List) return input.map(sort).toList(growable: false);
    return input;
  }

  return jsonEncode(sort(value));
}
