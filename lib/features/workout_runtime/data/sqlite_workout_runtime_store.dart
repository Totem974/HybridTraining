import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/workout_runtime/domain/composable_workout.dart';
import 'package:sqflite/sqflite.dart';

class SqliteWorkoutRuntimeStore {
  SqliteWorkoutRuntimeStore({
    required this.localDatabase,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final LocalDatabase localDatabase;
  final DateTime Function() _clock;

  Future<void> initialize(ComposableWorkout workout) async {
    final db = await localDatabase.open();
    final now = _now();
    await db.transaction((tx) async {
      await _assertWritable(tx, workout.id, runtimeMayBeMissing: true);
      await tx.insert('workout_runtime_sessions', {
        'session_id': workout.id,
        'status': workout.status.name,
        'active_block_sequence': workout.activeBlockIndex,
        'notes': workout.notes,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      for (final block in workout.blocks) {
        final rows = await tx.query(
          'session_blocks',
          columns: ['id'],
          where: 'id = ? AND session_id = ?',
          whereArgs: [block.id, workout.id],
        );
        if (rows.isEmpty) {
          throw StateError('Blueprint block not found: ${block.id}');
        }
        await tx.insert('workout_runtime_blocks', {
          'session_block_id': block.id,
          'status': block.status.name,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        for (final entry in block.prescriptions.indexed) {
          await tx.insert('workout_activities', {
            'id': entry.$2.id,
            'session_block_id': block.id,
            'sequence': entry.$1,
            'label': entry.$2.label,
            'target_type': entry.$2.target.type.name,
            'target_json': jsonEncode(entry.$2.target.toJson()),
            'status': entry.$2.status.name,
            'updated_at': now,
          });
        }
      }
    });
  }

  Future<Map<String, Object?>?> load(String sessionId) async {
    final db = await localDatabase.open();
    final sessions = await db.query(
      'workout_runtime_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessions.isEmpty) return null;
    final blocks = await db.rawQuery(
      '''SELECT sb.id, sb.sequence, sb.kind, sb.movement_id, rb.status, rb.rest_until FROM session_blocks sb JOIN workout_runtime_blocks rb ON rb.session_block_id = sb.id WHERE sb.session_id = ? ORDER BY sb.sequence''',
      [sessionId],
    );
    return {
      ...sessions.single,
      'blocks': [
        for (final block in blocks)
          {
            ...block,
            'activities': await db.query(
              'workout_activities',
              where: 'session_block_id = ?',
              whereArgs: [block['id']],
              orderBy: 'sequence',
            ),
          },
      ],
    };
  }

  Future<void> startOrResume(String sessionId) => _transaction(sessionId, (
    tx,
    now,
  ) async {
    final row = await _session(tx, sessionId);
    final status = row['status'] as String;
    if (status == 'completed' || status == 'abandoned' || status == 'skipped') {
      throw StateError('Session is closed: $sessionId');
    }
    await tx.update(
      'workout_runtime_sessions',
      {
        'status': 'started',
        'started_at': row['started_at'] ?? now,
        'updated_at': now,
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await _activateCurrent(
      tx,
      sessionId,
      row['active_block_sequence'] as int,
      now,
    );
  });

  Future<void> navigate(
    String sessionId, {
    required int blockSequence,
  }) => _transaction(sessionId, (tx, now) async {
    final runtime = await _session(tx, sessionId);
    if (runtime['status'] != 'started') {
      throw StateError('Runtime session is not started: $sessionId');
    }
    final exists =
        Sqflite.firstIntValue(
          await tx.rawQuery(
            'SELECT COUNT(*) FROM session_blocks WHERE session_id = ? AND sequence = ?',
            [sessionId, blockSequence],
          ),
        ) ??
        0;
    if (exists != 1) {
      throw StateError('Block sequence not found: $blockSequence');
    }
    final updated = await tx.update(
      'workout_runtime_sessions',
      {'active_block_sequence': blockSequence, 'updated_at': now},
      where: "session_id = ? AND status = 'started'",
      whereArgs: [sessionId],
    );
    if (updated != 1) {
      throw StateError('Runtime session is not started: $sessionId');
    }
    await _activateCurrent(tx, sessionId, blockSequence, now);
  });

  Future<void> record(
    String activityId,
    PrescriptionStatus status, {
    Map<String, Object?> result = const {},
  }) async {
    if (status == PrescriptionStatus.pending) {
      throw ArgumentError('A result cannot be pending.');
    }
    await _activityTransaction(activityId, (tx, now) async {
      final updated = await tx.update(
        'workout_activities',
        {
          'status': status.name,
          'result_json': jsonEncode(result),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [activityId],
      );
      if (updated != 1) throw StateError('Activity not found: $activityId');
    });
  }

  Future<void> editResult(
    String activityId,
    PrescriptionStatus status,
    Map<String, Object?> result,
  ) => record(activityId, status, result: result);
  Future<void> cancelResult(String activityId) async {
    await _activityTransaction(activityId, (tx, now) async {
      final updated = await tx.update(
        'workout_activities',
        {'status': 'pending', 'result_json': null, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [activityId],
      );
      if (updated != 1) throw StateError('Activity not found: $activityId');
    });
  }

  Future<void> setRest(String blockId, DateTime? until) async {
    final db = await localDatabase.open();
    await db.transaction((tx) async {
      final rows = await tx.rawQuery(
        'SELECT session_id FROM session_blocks WHERE id = ?',
        [blockId],
      );
      if (rows.isEmpty) throw StateError('Runtime block not found: $blockId');
      await _assertWritable(tx, rows.single['session_id']! as String);
      final updated = await tx.update(
        'workout_runtime_blocks',
        {'rest_until': until?.toUtc().toIso8601String(), 'updated_at': _now()},
        where: 'session_block_id = ?',
        whereArgs: [blockId],
      );
      if (updated != 1) throw StateError('Runtime block not found: $blockId');
    });
  }

  Future<void> updateNotes(String sessionId, String notes) =>
      _transaction(sessionId, (tx, now) async {
        final updated = await tx.update(
          'workout_runtime_sessions',
          {'notes': notes, 'updated_at': now},
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        if (updated != 1) {
          throw StateError('Runtime session not found: $sessionId');
        }
      });
  Future<void> abandon(String sessionId) =>
      _close(sessionId, WorkoutSessionStatus.abandoned);
  Future<void> skipRest(String sessionId) => _transaction(sessionId, (
    tx,
    now,
  ) async {
    final row = await _session(tx, sessionId);
    final active = row['active_block_sequence'] as int;
    await tx.rawUpdate(
      "UPDATE workout_runtime_blocks SET status = 'skipped', rest_until = NULL, updated_at = ? WHERE session_block_id IN (SELECT id FROM session_blocks WHERE session_id = ? AND sequence >= ?)",
      [now, sessionId, active],
    );
    await tx.rawUpdate(
      "UPDATE workout_activities SET status = 'skipped', updated_at = ? WHERE status = 'pending' AND session_block_id IN (SELECT id FROM session_blocks WHERE session_id = ? AND sequence >= ?)",
      [now, sessionId, active],
    );
    await _setClosed(tx, sessionId, WorkoutSessionStatus.skipped, now);
  });

  Future<void> complete(String sessionId) => _transaction(sessionId, (
    tx,
    now,
  ) async {
    final pending =
        Sqflite.firstIntValue(
          await tx.rawQuery(
            "SELECT COUNT(*) FROM workout_activities wa JOIN session_blocks sb ON sb.id = wa.session_block_id WHERE sb.session_id = ? AND wa.status = 'pending'",
            [sessionId],
          ),
        ) ??
        0;
    if (pending != 0) throw StateError('Session has pending prescriptions.');
    await tx.rawUpdate(
      "UPDATE workout_runtime_blocks SET status = CASE WHEN status = 'skipped' THEN status ELSE 'completed' END, rest_until = NULL, updated_at = ? WHERE session_block_id IN (SELECT id FROM session_blocks WHERE session_id = ?)",
      [now, sessionId],
    );
    await _setClosed(tx, sessionId, WorkoutSessionStatus.completed, now);
  });

  Future<void> _close(String id, WorkoutSessionStatus status) =>
      _transaction(id, (tx, now) => _setClosed(tx, id, status, now));
  Future<void> _setClosed(
    DatabaseExecutor tx,
    String id,
    WorkoutSessionStatus status,
    String now,
  ) async {
    await tx.update(
      'workout_runtime_sessions',
      {'status': status.name, 'ended_at': now, 'updated_at': now},
      where: 'session_id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, Object?>> _session(DatabaseExecutor tx, String id) async {
    final rows = await tx.query(
      'workout_runtime_sessions',
      where: 'session_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Runtime session not found: $id');
    return rows.single;
  }

  Future<void> _activateCurrent(
    DatabaseExecutor tx,
    String id,
    int sequence,
    String now,
  ) async {
    await tx.rawUpdate(
      "UPDATE workout_runtime_blocks SET status = 'active', updated_at = ? WHERE session_block_id IN (SELECT id FROM session_blocks WHERE session_id = ? AND sequence = ?) AND status = 'pending'",
      [now, id, sequence],
    );
  }

  Future<void> _transaction(
    String id,
    Future<void> Function(DatabaseExecutor, String) action,
  ) async {
    final db = await localDatabase.open();
    await db.transaction((tx) async {
      await _assertWritable(tx, id);
      await action(tx, _now());
    });
  }

  Future<void> _activityTransaction(
    String activityId,
    Future<void> Function(DatabaseExecutor, String) action,
  ) async {
    final db = await localDatabase.open();
    await db.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''SELECT sb.session_id FROM workout_activities wa
           JOIN session_blocks sb ON sb.id = wa.session_block_id
           WHERE wa.id = ?''',
        [activityId],
      );
      if (rows.isEmpty) throw StateError('Activity not found: $activityId');
      await _assertWritable(tx, rows.single['session_id']! as String);
      await action(tx, _now());
    });
  }

  /// The v3 runtime is retained for backup/migration reads only. Any legacy
  /// writer that is still called must respect the canonical v4 lifecycle.
  Future<void> _assertWritable(
    DatabaseExecutor tx,
    String sessionId, {
    bool runtimeMayBeMissing = false,
  }) async {
    final rows = await tx.rawQuery(
      '''SELECT s.status AS session_status,
                c.status AS cycle_status,
                b.status AS block_status,
                p.status AS plan_status,
                r.status AS runtime_status
         FROM plan_training_sessions s
         JOIN plan_training_cycles c ON c.id = s.cycle_id
         JOIN training_blocks b ON b.id = c.block_id
         JOIN training_plans p ON p.id = b.plan_id
         LEFT JOIN workout_runtime_sessions r ON r.session_id = s.id
         WHERE s.id = ?''',
      [sessionId],
    );
    if (rows.isEmpty) {
      throw StateError('Planned session not found: $sessionId');
    }
    final row = rows.single;
    if (!const {'planned', 'started'}.contains(row['session_status']) ||
        !const {'planned', 'active'}.contains(row['cycle_status']) ||
        !const {'planned', 'active'}.contains(row['block_status']) ||
        !const {'planned', 'active'}.contains(row['plan_status'])) {
      throw StateError('Session or an ancestor is closed: $sessionId');
    }
    final runtimeStatus = row['runtime_status'];
    if (runtimeStatus == null) {
      if (!runtimeMayBeMissing) {
        throw StateError('Runtime session not found: $sessionId');
      }
      return;
    }
    if (const {'completed', 'abandoned', 'skipped'}.contains(runtimeStatus)) {
      throw StateError('Runtime session is closed: $sessionId');
    }
  }

  String _now() => _clock().toUtc().toIso8601String();
}
