import 'dart:convert';

import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/training_log/application/training_snapshot_repository.dart';
import 'package:hybrid_training/features/training_log/domain/training_snapshot.dart';

final class SqliteTrainingSnapshotRepository
    implements TrainingSnapshotRepository {
  const SqliteTrainingSnapshotRepository(this.databaseFile);
  final SqliteDatabaseFile databaseFile;

  @override
  Future<void> save(GeneratedCycle cycle) async {
    final db = await databaseFile.open();
    await db.transaction((tx) async {
      await tx.insert('snapshots', {
        'cycle_id': cycle.id,
        'schema_version': 1,
        'resolved_json': jsonEncode(cycle.toJson()),
      });
      for (final week in cycle.weeks) {
        for (
          var sessionIndex = 0;
          sessionIndex < week.sessions.length;
          sessionIndex++
        ) {
          final session = week.sessions[sessionIndex];
          final blockIdCounts = <String, int>{};
          for (final block in session.blocks) {
            blockIdCounts.update(
              block.id,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
          await tx.insert('sessions', {
            'id': session.id,
            'cycle_id': cycle.id,
            'week_number': week.number,
            'sequence': sessionIndex,
            'scheduled_for': session.date.toIso8601String(),
            'movement_id': session.movementId.value,
            'state': 'planned',
          });
          for (
            var blockIndex = 0;
            blockIndex < session.blocks.length;
            blockIndex++
          ) {
            final block = session.blocks[blockIndex];
            final blockId = blockIdCounts[block.id] == 1
                ? '${session.id}:${block.id}'
                : '${session.id}:$blockIndex:${block.movementId.value}:${block.id}';
            await tx.insert('blocks', {
              'id': blockId,
              'session_id': session.id,
              'sequence': blockIndex,
              'role': block.role,
              'movement_id': block.movementId.value,
            });
            for (final set in block.sets) {
              await tx.insert('planned_sets', {
                'id': '$blockId:${set.index}',
                'block_id': blockId,
                'sequence': set.index,
                'repetitions_json': jsonEncode(set.repetitions),
                'percentage_basis_points': set.percentageBasisPoints,
                'planned_load_centi_units': set.plannedLoad?.centiUnits,
                'unit': set.plannedLoad?.unit.name,
                'plates_json': jsonEncode(
                  set.platesPerSide.map((plate) => plate.toJson()).toList(),
                ),
                'warning_json': set.warning == null
                    ? null
                    : jsonEncode(set.warning!.toJson()),
              });
            }
          }
        }
      }
    });
  }

  @override
  Future<StoredTrainingSnapshot> load(String cycleId) async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'snapshots',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Training snapshot not found: $cycleId');
    final decoded = jsonDecode(rows.single['resolved_json']! as String);
    if (decoded is! Map<String, Object?> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Unknown training snapshot schema.');
    }
    return StoredTrainingSnapshot(cycleId: cycleId, resolvedCycleJson: decoded);
  }

  @override
  Future<void> recordSetResult(String setId, ActualSetResult result) async {
    if (result.state == TrainingSetResultState.pending ||
        (result.repetitions != null && result.repetitions! < 0) ||
        (result.loadCentiUnits != null && result.loadCentiUnits! < 0) ||
        (result.state == TrainingSetResultState.completed &&
            result.repetitions == null)) {
      throw ArgumentError('A terminal, valid set result is required.');
    }
    final db = await databaseFile.open();
    final count = await db.update(
      'planned_sets',
      {
        'result_state': result.state.name,
        'actual_repetitions': result.repetitions,
        'actual_load_centi_units': result.loadCentiUnits,
        'note': result.note,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
    if (count != 1) throw StateError('Planned set not found: $setId');
  }

  @override
  Future<ActualSetResult> loadSetResult(String setId) async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'planned_sets',
      where: 'id = ?',
      whereArgs: [setId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Planned set not found: $setId');
    final row = rows.single;
    return ActualSetResult(
      state: TrainingSetResultState.values.byName(
        row['result_state']! as String,
      ),
      repetitions: row['actual_repetitions'] as int?,
      loadCentiUnits: row['actual_load_centi_units'] as int?,
      note: row['note'] as String?,
    );
  }
}
