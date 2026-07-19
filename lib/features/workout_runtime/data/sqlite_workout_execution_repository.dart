import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/workout_runtime/application/workout_execution_repository.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';
import 'package:sqflite/sqflite.dart';

class SqliteWorkoutExecutionRepository implements WorkoutExecutionRepository {
  const SqliteWorkoutExecutionRepository({required this.localDatabase});

  final LocalDatabase localDatabase;

  @override
  Future<WorkoutExecution> create(String sessionId) async {
    final database = await localDatabase.open();
    return database.transaction(
      (transaction) => createInTransaction(transaction, sessionId),
    );
  }

  Future<WorkoutExecution> createInTransaction(
    DatabaseExecutor transaction,
    String sessionId,
  ) async {
    final existing = await loadInTransaction(transaction, sessionId);
    if (existing != null) return existing;
    final prescriptions = await transaction.rawQuery(
      '''SELECT sp.id FROM set_prescriptions sp
           JOIN session_blocks sb ON sb.id = sp.session_block_id
           WHERE sb.session_id = ? ORDER BY sb.sequence, sp.sequence''',
      [sessionId],
    );
    if (prescriptions.isEmpty) {
      throw StateError('No set prescriptions found for session: $sessionId');
    }
    final execution = WorkoutExecution(
      sessionId: sessionId,
      sets: [
        for (final row in prescriptions)
          SetOutcome(setId: row['id']! as String),
      ],
    );
    await _persist(transaction, execution);
    await _appendEvent(transaction, execution, 'created', const {});
    return execution;
  }

  @override
  Future<WorkoutExecution?> load(String sessionId) async {
    final database = await localDatabase.open();
    return loadInTransaction(database, sessionId);
  }

  @override
  Future<WorkoutExecution> mutate(
    String sessionId, {
    required String eventType,
    Map<String, Object?> payload = const {},
    required WorkoutExecution Function(WorkoutExecution current) action,
  }) async {
    if (eventType.trim().isEmpty) throw ArgumentError.value(eventType);
    final database = await localDatabase.open();
    return database.transaction(
      (transaction) => mutateInTransaction(
        transaction,
        sessionId,
        eventType: eventType,
        payload: payload,
        action: action,
      ),
    );
  }

  Future<WorkoutExecution> mutateInTransaction(
    DatabaseExecutor transaction,
    String sessionId, {
    required String eventType,
    Map<String, Object?> payload = const {},
    required WorkoutExecution Function(WorkoutExecution current) action,
  }) async {
    final current = await loadInTransaction(transaction, sessionId);
    if (current == null) {
      throw StateError('Workout execution not found: $sessionId');
    }
    final next = action(current);
    if (next.sessionId != current.sessionId) {
      throw StateError('A mutation cannot replace the session identity.');
    }
    await _persist(transaction, next);
    await _appendEvent(transaction, next, eventType, payload);
    return next;
  }

  Future<WorkoutExecution?> loadInTransaction(
    DatabaseExecutor database,
    String sessionId,
  ) async {
    final rows = await database.query(
      'workout_executions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final outcomes = await database.query(
      'workout_set_outcomes',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sequence',
    );
    return WorkoutExecution(
      sessionId: sessionId,
      state: WorkoutExecutionState.values.byName(row['state']! as String),
      activeSetIndex: row['active_set_index']! as int,
      restUntil: _date(row['rest_until']),
      pausedFrom: row['paused_from'] == null
          ? null
          : WorkoutExecutionState.values.byName(row['paused_from']! as String),
      notes: row['notes']! as String,
      reversibleSetIndexes:
          (jsonDecode(row['reversible_stack_json']! as String) as List<Object?>)
              .cast<int>(),
      updatedAt: _date(row['updated_at']),
      sets: [
        for (final outcome in outcomes)
          SetOutcome(
            setId: outcome['prescription_id']! as String,
            status: SetOutcomeStatus.values.byName(
              outcome['status']! as String,
            ),
            actualRepetitions: outcome['actual_repetitions'] as int?,
            actualLoad: (outcome['actual_load'] as num?)?.toDouble(),
            rpe: (outcome['rpe'] as num?)?.toDouble(),
            notes: outcome['notes']! as String,
            recordedAt: _date(outcome['recorded_at']),
          ),
      ],
    );
  }

  Future<void> _persist(
    DatabaseExecutor database,
    WorkoutExecution execution,
  ) async {
    final updatedAt =
        execution.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final executionValues = <String, Object?>{
      'state': execution.state.name,
      'active_set_index': execution.activeSetIndex,
      'rest_until': execution.restUntil?.toUtc().toIso8601String(),
      'paused_from': execution.pausedFrom?.name,
      'notes': execution.notes,
      'reversible_stack_json': jsonEncode(execution.reversibleSetIndexes),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'ended_at': execution.isClosed
          ? updatedAt.toUtc().toIso8601String()
          : null,
    };
    final updatedExecution = await database.update(
      'workout_executions',
      executionValues,
      where: 'session_id = ?',
      whereArgs: [execution.sessionId],
    );
    if (updatedExecution == 0) {
      await database.insert('workout_executions', {
        'session_id': execution.sessionId,
        ...executionValues,
      });
    }
    for (final entry in execution.sets.indexed) {
      final outcome = entry.$2;
      final outcomeValues = <String, Object?>{
        'session_id': execution.sessionId,
        'sequence': entry.$1,
        'status': outcome.status.name,
        'actual_repetitions': outcome.actualRepetitions,
        'actual_load': outcome.actualLoad,
        'rpe': outcome.rpe,
        'notes': outcome.notes,
        'recorded_at': outcome.recordedAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
      final updatedOutcome = await database.update(
        'workout_set_outcomes',
        outcomeValues,
        where: 'prescription_id = ?',
        whereArgs: [outcome.setId],
      );
      if (updatedOutcome == 0) {
        await database.insert('workout_set_outcomes', {
          'prescription_id': outcome.setId,
          ...outcomeValues,
        });
      }
    }
  }

  Future<void> _appendEvent(
    DatabaseExecutor database,
    WorkoutExecution execution,
    String eventType,
    Map<String, Object?> payload,
  ) async {
    final sequence =
        Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT COALESCE(MAX(sequence), -1) + 1 FROM workout_execution_events WHERE session_id = ?',
            [execution.sessionId],
          ),
        ) ??
        0;
    final at =
        execution.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    await database.insert('workout_execution_events', {
      'id': '${execution.sessionId}:event:$sequence',
      'session_id': execution.sessionId,
      'sequence': sequence,
      'event_type': eventType,
      'payload_json': jsonEncode(payload),
      'occurred_at': at.toUtc().toIso8601String(),
    });
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}
