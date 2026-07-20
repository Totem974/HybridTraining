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
    await _requireExecutableSession(transaction, sessionId);
    final existing = await loadInTransaction(transaction, sessionId);
    if (existing != null) return existing;
    final prescriptions = await _prescriptionItems(transaction, sessionId);
    if (prescriptions.isEmpty) {
      throw StateError(
        'No executable prescriptions found for session: $sessionId',
      );
    }
    final execution = WorkoutExecution(
      sessionId: sessionId,
      sets: [
        for (final row in prescriptions)
          SetOutcome(
            setId: row['id']! as String,
            kind: ExecutionItemKind.values.byName(row['item_kind']! as String),
            storage: ExecutionItemStorage.values.byName(
              row['storage_kind']! as String,
            ),
          ),
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
    await _requireExecutableSession(transaction, sessionId);
    final current = await loadInTransaction(transaction, sessionId);
    if (current == null) {
      throw StateError('Workout execution not found: $sessionId');
    }
    final next = action(current);
    if (next.sessionId != current.sessionId) {
      throw StateError('A mutation cannot replace the session identity.');
    }
    _requireSameTopology(current, next);
    await _persist(transaction, next);
    await _appendEvent(transaction, next, eventType, payload);
    return next;
  }

  Future<void> _requireExecutableSession(
    DatabaseExecutor database,
    String sessionId,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT s.status AS session_status,
                c.status AS cycle_status,
                b.status AS block_status,
                p.status AS plan_status
           FROM plan_training_sessions s
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           JOIN training_plans p ON p.id = b.plan_id
          WHERE s.id = ?''',
      [sessionId],
    );
    if (rows.length != 1) {
      throw StateError('Training session not found: $sessionId');
    }
    final status = rows.single;
    final sessionStatus = status['session_status'] as String;
    const openAncestorStatuses = {'planned', 'active'};
    if ((sessionStatus != 'planned' && sessionStatus != 'started') ||
        !openAncestorStatuses.contains(status['cycle_status']) ||
        !openAncestorStatuses.contains(status['block_status']) ||
        !openAncestorStatuses.contains(status['plan_status'])) {
      throw StateError(
        'Workout execution is not allowed for a closed or inactive '
        'session hierarchy: $sessionId',
      );
    }
  }

  static void _requireSameTopology(
    WorkoutExecution current,
    WorkoutExecution next,
  ) {
    if (next.sets.length != current.sets.length) {
      throw StateError('A mutation cannot replace the execution topology.');
    }
    for (var index = 0; index < current.sets.length; index++) {
      final before = current.sets[index];
      final after = next.sets[index];
      if (after.setId != before.setId ||
          after.kind != before.kind ||
          after.storage != before.storage) {
        throw StateError('A mutation cannot replace the execution topology.');
      }
    }
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
    final outcomes = await _prescriptionItems(database, sessionId);
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
            setId: outcome['id']! as String,
            kind: ExecutionItemKind.values.byName(
              outcome['item_kind']! as String,
            ),
            storage: ExecutionItemStorage.values.byName(
              outcome['storage_kind']! as String,
            ),
            status: SetOutcomeStatus.values.byName(
              (outcome['outcome_status'] as String?) ?? 'pending',
            ),
            actualRepetitions:
                outcome['actual_repetitions'] as int? ??
                _actualInt(outcome['actual_json'], 'repetitions'),
            actualLoad:
                (outcome['actual_load'] as num?)?.toDouble() ??
                _actualDouble(outcome['actual_json'], 'load'),
            rpe: (outcome['rpe'] as num?)?.toDouble(),
            notes: outcome['notes']! as String,
            recordedAt: _date(outcome['recorded_at']),
            actualTotalRepetitions: _actualInt(
              outcome['actual_json'],
              'totalRepetitions',
            ),
            actualDurationSeconds: _actualInt(
              outcome['actual_json'],
              'durationSeconds',
            ),
            actualDistanceMeters: _actualDouble(
              outcome['actual_json'],
              'distanceMeters',
            ),
            actualRounds: _actualInt(outcome['actual_json'], 'rounds'),
            completed: _actualBool(outcome['actual_json'], 'completed'),
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
      if (outcome.storage == ExecutionItemStorage.genericActivity) {
        final values = <String, Object?>{
          'status': outcome.status.name,
          'actual_json': jsonEncode({
            'repetitions': outcome.actualRepetitions,
            'load': outcome.actualLoad,
            'totalRepetitions': outcome.actualTotalRepetitions,
            'durationSeconds': outcome.actualDurationSeconds,
            'distanceMeters': outcome.actualDistanceMeters,
            'rounds': outcome.actualRounds,
            'completed': outcome.completed,
          }),
          'rpe': outcome.rpe,
          'notes': outcome.notes,
          'recorded_at': outcome.recordedAt?.toUtc().toIso8601String(),
          'updated_at': updatedAt.toUtc().toIso8601String(),
        };
        final updated = await database.update(
          'activity_results',
          values,
          where: '''prescription_id = ? AND EXISTS (
            SELECT 1
              FROM activity_prescriptions ap
              JOIN session_blocks sb ON sb.id = ap.session_block_id
             WHERE ap.id = activity_results.prescription_id
               AND sb.session_id = ?
          )''',
          whereArgs: [outcome.setId, execution.sessionId],
        );
        if (updated == 0) {
          await database.insert('activity_results', {
            'prescription_id': outcome.setId,
            ...values,
          });
        }
        continue;
      }
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
        where: 'prescription_id = ? AND session_id = ?',
        whereArgs: [outcome.setId, execution.sessionId],
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

  Future<List<Map<String, Object?>>> _prescriptionItems(
    DatabaseExecutor database,
    String sessionId,
  ) async {
    final misownedOutcomes =
        Sqflite.firstIntValue(
          await database.rawQuery(
            '''SELECT COUNT(*)
                 FROM workout_set_outcomes wo
                 JOIN set_prescriptions sp ON sp.id = wo.prescription_id
                 JOIN session_blocks sb ON sb.id = sp.session_block_id
                WHERE (sb.session_id = ? OR wo.session_id = ?)
                  AND wo.session_id <> sb.session_id''',
            [sessionId, sessionId],
          ),
        ) ??
        0;
    if (misownedOutcomes != 0) {
      throw StateError(
        'A workout outcome belongs to a different session: $sessionId',
      );
    }
    return database.rawQuery(
      '''SELECT sp.id, 'loadedSet' AS item_kind, 'legacySet' AS storage_kind,
              sb.sequence AS block_sequence, sp.sequence AS item_sequence,
              wo.status AS outcome_status, wo.actual_repetitions,
              wo.actual_load, wo.rpe, wo.notes, wo.recorded_at,
              NULL AS actual_json
         FROM set_prescriptions sp
         JOIN session_blocks sb ON sb.id = sp.session_block_id
         LEFT JOIN workout_set_outcomes wo
           ON wo.prescription_id = sp.id AND wo.session_id = ?
        WHERE sb.session_id = ?
       UNION ALL
       SELECT ap.id,
              CASE WHEN ap.target_type = 'setsRepsLoad'
                   THEN 'loadedSet' ELSE 'activity' END AS item_kind,
              'genericActivity' AS storage_kind,
              sb.sequence AS block_sequence, ap.sequence AS item_sequence,
              ar.status AS outcome_status, NULL AS actual_repetitions,
              NULL AS actual_load, ar.rpe, ar.notes, ar.recorded_at,
              ar.actual_json
        FROM activity_prescriptions ap
         JOIN session_blocks sb ON sb.id = ap.session_block_id
        LEFT JOIN activity_results ar ON ar.prescription_id = ap.id
       WHERE sb.session_id = ?
       ORDER BY 4, 5, 2, 3, 1''',
      [sessionId, sessionId, sessionId],
    );
  }

  static Map<String, Object?>? _actual(Object? encoded) => encoded == null
      ? null
      : (jsonDecode(encoded as String) as Map<String, Object?>);

  static int? _actualInt(Object? encoded, String key) =>
      (_actual(encoded)?[key] as num?)?.toInt();

  static double? _actualDouble(Object? encoded, String key) =>
      (_actual(encoded)?[key] as num?)?.toDouble();

  static bool? _actualBool(Object? encoded, String key) =>
      _actual(encoded)?[key] as bool?;
}
