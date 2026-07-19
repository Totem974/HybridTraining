import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/plan_lifecycle.dart';
import 'package:hybrid_training/features/active_program/application/program_switch.dart';
import 'package:sqflite/sqflite.dart';

class SqlitePlanLifecycleRepository implements PlanLifecycleRepository {
  const SqlitePlanLifecycleRepository({
    required this.localDatabase,
    required this.clock,
  });

  final LocalDatabase localDatabase;
  final DateTime Function() clock;

  @override
  Future<PlanAmendmentPreview> previewAmendment(
    PlanAmendmentRequest request,
  ) async {
    _validateRequest(request);
    final database = await localDatabase.open();
    return database.transaction((tx) async {
      final sessions = await _planSessions(tx, request.planId);
      if (sessions.isEmpty) {
        throw StateError('Plan not found or has no sessions.');
      }
      final byId = {for (final row in sessions) row['id']! as String: row};
      for (final sessionId in request.rescheduledSessions.keys) {
        final session = byId[sessionId];
        if (session == null) {
          throw StateError('Session is outside the plan: $sessionId');
        }
        if (session['status'] == 'complete') {
          throw StateError('Completed sessions are immutable: $sessionId');
        }
      }
      final completed = sessions
          .where((row) => row['status'] == 'complete')
          .map((row) => row['id']! as String)
          .toList();
      final active = sessions
          .where(
            (row) =>
                row['status'] == 'started' ||
                const {
                  'activeSet',
                  'resting',
                  'paused',
                }.contains(row['execution_state']),
          )
          .map((row) => row['id']! as String)
          .toList();
      final planned = sessions
          .where((row) => row['status'] == 'planned')
          .map((row) => row['id']! as String)
          .toList();
      var prescriptionChanges = 0;
      for (final movement in request.trainingMaxChanges.keys) {
        prescriptionChanges +=
            Sqflite.firstIntValue(
              await tx.rawQuery(
                '''SELECT COUNT(*) FROM activity_prescriptions ap
                   JOIN session_blocks sb ON sb.id = ap.session_block_id
                   JOIN plan_training_sessions s ON s.id = sb.session_id
                   JOIN plan_training_cycles c ON c.id = s.cycle_id
                   JOIN training_blocks b ON b.id = c.block_id
                   WHERE b.plan_id = ? AND s.status = 'planned'
                     AND ap.movement_or_activity_id = ?''',
                [request.planId, movement],
              ),
            ) ??
            0;
        prescriptionChanges +=
            Sqflite.firstIntValue(
              await tx.rawQuery(
                '''SELECT COUNT(*) FROM set_prescriptions sp
                   JOIN session_blocks sb ON sb.id = sp.session_block_id
                   JOIN plan_training_sessions s ON s.id = sb.session_id
                   JOIN plan_training_cycles c ON c.id = s.cycle_id
                   JOIN training_blocks b ON b.id = c.block_id
                   WHERE b.plan_id = ? AND s.status = 'planned'
                     AND sb.movement_id = ?''',
                [request.planId, movement],
              ),
            ) ??
            0;
      }
      final version =
          (Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COALESCE(MAX(version), 0) + 1 FROM plan_amendments WHERE plan_id = ?',
              [request.planId],
            ),
          ) ??
          1);
      final amendmentId = '${request.planId}:amendment:$version';
      final before = {
        'sessions': {
          for (final row in sessions)
            row['id']! as String: {
              'status': row['status'],
              'scheduledFor': row['scheduled_for'],
            },
        },
      };
      final after = {
        'rescheduledSessions': {
          for (final entry in request.rescheduledSessions.entries)
            entry.key: _date(entry.value),
        },
        'trainingMaxChanges': request.trainingMaxChanges,
      };
      final diff = {
        'preservedCompletedSessionIds': completed,
        'activeSessionIds': active,
        'rescheduledSessionIds': request.rescheduledSessions.keys.toList(),
        'regeneratedSessionIds': request.trainingMaxChanges.isEmpty
            ? <String>[]
            : planned,
        'cancelledSessionIds':
            request.activeSessionDisposition == ActiveSessionDisposition.abandon
            ? active
            : <String>[],
        'trainingMaxChanges': request.trainingMaxChanges,
        'prescriptionChanges': prescriptionChanges,
      };
      await tx.insert('plan_amendments', {
        'id': amendmentId,
        'plan_id': request.planId,
        'version': version,
        'state': 'previewed',
        'reason': request.reason.trim(),
        'rule_id': request.ruleId.trim(),
        'before_snapshot_json': jsonEncode(before),
        'after_snapshot_json': jsonEncode(after),
        'diff_json': jsonEncode(diff),
        'created_at': _date(clock()),
      });
      return PlanAmendmentPreview(
        amendmentId: amendmentId,
        planId: request.planId,
        version: version,
        preservedCompletedSessionIds: completed,
        activeSessionIds: active,
        rescheduledSessionIds: request.rescheduledSessions.keys.toList(),
        regeneratedSessionIds: request.trainingMaxChanges.isEmpty
            ? const []
            : planned,
        cancelledSessionIds:
            request.activeSessionDisposition == ActiveSessionDisposition.abandon
            ? active
            : const [],
        trainingMaxChanges: request.trainingMaxChanges,
        prescriptionChanges: prescriptionChanges,
      );
    });
  }

  @override
  Future<void> applyAmendment(
    PlanAmendmentRequest request, {
    required String amendmentId,
    required bool confirmed,
  }) async {
    _validateRequest(request);
    if (!confirmed) throw StateError('An amendment requires confirmation.');
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final amendment = await tx.query(
        'plan_amendments',
        where: 'id = ? AND plan_id = ?',
        whereArgs: [amendmentId, request.planId],
        limit: 1,
      );
      if (amendment.isEmpty || amendment.single['state'] != 'previewed') {
        throw StateError('A matching unapplied preview is required.');
      }
      final sessions = await _planSessions(tx, request.planId);
      final active = sessions.where(
        (row) =>
            row['status'] == 'started' ||
            const {
              'activeSet',
              'resting',
              'paused',
            }.contains(row['execution_state']),
      );
      if (active.isNotEmpty &&
          request.activeSessionDisposition !=
              ActiveSessionDisposition.abandon) {
        throw StateError('An explicit active-session disposition is required.');
      }
      final at = _date(clock());
      for (final row in active) {
        final sessionId = row['id']! as String;
        await tx.update(
          'workout_executions',
          {'state': 'abandoned', 'ended_at': at, 'updated_at': at},
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        await tx.update(
          'plan_training_sessions',
          {'status': 'cancelled', 'completed_at': at},
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
      for (final entry in request.rescheduledSessions.entries) {
        final updated = await tx.update(
          'plan_training_sessions',
          {'scheduled_for': _dateOnly(entry.value)},
          where: "id = ? AND status = 'planned'",
          whereArgs: [entry.key],
        );
        if (updated != 1) {
          throw StateError('Only a planned future session can be rescheduled.');
        }
      }
      for (final entry in request.trainingMaxChanges.entries) {
        await _applyFutureTrainingMax(
          tx,
          planId: request.planId,
          movementId: entry.key,
          trainingMax: entry.value,
        );
        await _confirmTimeline(
          tx,
          planId: request.planId,
          movementId: entry.key,
          trainingMax: entry.value,
          at: at,
        );
      }
      await tx.update(
        'plan_amendments',
        {'state': 'applied', 'applied_at': at},
        where: "id = ? AND state = 'previewed'",
        whereArgs: [amendmentId],
      );
    });
  }

  @override
  Future<void> rescheduleSession(String sessionId, DateTime date) async {
    final database = await localDatabase.open();
    final updated = await database.update(
      'plan_training_sessions',
      {'scheduled_for': _dateOnly(date)},
      where: "id = ? AND status = 'planned'",
      whereArgs: [sessionId],
    );
    if (updated != 1) throw StateError('Only a planned session can be moved.');
  }

  @override
  Future<void> skipSession(String sessionId, {required String reason}) async {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason);
    final database = await localDatabase.open();
    final updated = await database.update(
      'plan_training_sessions',
      {'status': 'cancelled', 'completed_at': _date(clock()), 'notes': reason},
      where: "id = ? AND status = 'planned'",
      whereArgs: [sessionId],
    );
    if (updated != 1) {
      throw StateError('Only a planned session can be skipped.');
    }
  }

  @override
  Future<void> abandonActiveSession(
    String sessionId, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason);
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final at = _date(clock());
      final updated = await tx.update(
        'workout_executions',
        {
          'state': 'abandoned',
          'ended_at': at,
          'updated_at': at,
          'notes': reason,
        },
        where: "session_id = ? AND state IN ('activeSet','resting','paused')",
        whereArgs: [sessionId],
      );
      if (updated != 1) throw StateError('Session is not active.');
      await tx.update(
        'plan_training_sessions',
        {'status': 'cancelled', 'completed_at': at, 'notes': reason},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  @override
  Future<LifecycleStatus> completeWorkout(String sessionId, DateTime at) async {
    final database = await localDatabase.open();
    final planId = await database.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''SELECT p.id AS plan_id, e.state
           FROM plan_training_sessions s
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           JOIN training_plans p ON p.id = b.plan_id
           JOIN workout_executions e ON e.session_id = s.id
           WHERE s.id = ?''',
        [sessionId],
      );
      if (rows.isEmpty || rows.single['state'] != 'completed') {
        throw StateError('Workout execution must be completed first.');
      }
      await tx.update(
        'plan_training_sessions',
        {'status': 'complete', 'completed_at': _date(at)},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return rows.single['plan_id']! as String;
    });
    return advancePlanLifecycle(planId, at);
  }

  @override
  Future<LifecycleStatus> completeCycle(String cycleId, DateTime at) async {
    final database = await localDatabase.open();
    final rows = await database.rawQuery(
      '''SELECT c.block_id, b.plan_id,
                SUM(CASE WHEN s.status IN ('complete','cancelled') THEN 0 ELSE 1 END) AS open_count
         FROM plan_training_cycles c
         JOIN training_blocks b ON b.id = c.block_id
         JOIN plan_training_sessions s ON s.cycle_id = c.id
         WHERE c.id = ? GROUP BY c.id''',
      [cycleId],
    );
    if (rows.isEmpty || (rows.single['open_count']! as int) != 0) {
      throw StateError('Every session must be closed before cycle completion.');
    }
    await database.update(
      'plan_training_cycles',
      {'status': 'complete'},
      where: 'id = ?',
      whereArgs: [cycleId],
    );
    return advancePlanLifecycle(rows.single['plan_id']! as String, at);
  }

  @override
  Future<LifecycleStatus> completeBlock(String blockId, DateTime at) async {
    final database = await localDatabase.open();
    final rows = await database.rawQuery(
      '''SELECT b.plan_id,
                SUM(CASE WHEN c.status IN ('complete','cancelled') THEN 0 ELSE 1 END) AS open_count
         FROM training_blocks b
         JOIN plan_training_cycles c ON c.block_id = b.id
         WHERE b.id = ? GROUP BY b.id''',
      [blockId],
    );
    if (rows.isEmpty || (rows.single['open_count']! as int) != 0) {
      throw StateError('Every cycle must be closed before block completion.');
    }
    await database.update(
      'training_blocks',
      {'status': 'complete', 'completed_at': _date(at)},
      where: 'id = ?',
      whereArgs: [blockId],
    );
    return advancePlanLifecycle(rows.single['plan_id']! as String, at);
  }

  @override
  Future<LifecycleStatus> advancePlanLifecycle(
    String planId,
    DateTime at,
  ) async {
    final database = await localDatabase.open();
    return database.transaction((tx) async {
      await tx.rawUpdate(
        '''UPDATE plan_training_cycles SET status = 'complete'
           WHERE block_id IN (SELECT id FROM training_blocks WHERE plan_id = ?)
             AND status != 'complete'
             AND NOT EXISTS (
               SELECT 1 FROM plan_training_sessions s
               WHERE s.cycle_id = plan_training_cycles.id
                 AND s.status NOT IN ('complete','cancelled'))''',
        [planId],
      );
      await tx.rawUpdate(
        '''UPDATE training_blocks SET status = 'complete', completed_at = ?
           WHERE plan_id = ? AND status != 'complete'
             AND NOT EXISTS (
               SELECT 1 FROM plan_training_cycles c
               WHERE c.block_id = training_blocks.id
                 AND c.status NOT IN ('complete','cancelled'))''',
        [_date(at), planId],
      );
      final blocks = await tx.query(
        'training_blocks',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'sequence',
      );
      if (blocks.isEmpty) throw StateError('Plan not found: $planId');
      final next = blocks.cast<Map<String, Object?>>().firstWhere(
        (row) => row['status'] == 'planned',
        orElse: () => const {},
      );
      if (next.isNotEmpty) {
        await tx.update(
          'training_blocks',
          {'status': 'active', 'started_at': _date(at)},
          where: 'id = ?',
          whereArgs: [next['id']],
        );
      }
      final planComplete = blocks.every(
        (row) => const {'complete', 'cancelled'}.contains(row['status']),
      );
      if (planComplete) {
        await tx.update(
          'training_plans',
          {'status': 'complete', 'completed_at': _date(at)},
          where: 'id = ?',
          whereArgs: [planId],
        );
      }
      final completedWeek =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              '''SELECT MAX(s.programming_week_number)
                 FROM plan_training_sessions s
                 JOIN plan_training_cycles c ON c.id = s.cycle_id
                 JOIN training_blocks b ON b.id = c.block_id
                 WHERE b.plan_id = ? AND s.status = 'complete' ''',
              [planId],
            ),
          ) ??
          0;
      final decisionRequired =
          (Sqflite.firstIntValue(
                    await tx.rawQuery(
                      '''SELECT COUNT(*) FROM training_max_timeline
                     WHERE plan_id = ? AND state = 'previewed'
                       AND sequence IN (
                         SELECT MIN(sequence) FROM training_max_timeline
                         WHERE plan_id = ? AND state = 'previewed'
                       )''',
                      [planId, planId],
                    ),
                  ) ??
                  0) >
              0 &&
          completedWeek > 0;
      return LifecycleStatus(
        sessionComplete: true,
        cycleComplete: blocks.any((row) => row['status'] == 'complete'),
        blockComplete: blocks.any((row) => row['status'] == 'complete'),
        planComplete: planComplete,
        trainingMaxDecisionRequired: decisionRequired,
        nextBlockId: next['id'] as String?,
      );
    });
  }

  @override
  Future<void> completeTrainingPlan(String planId, DateTime at) async {
    final status = await advancePlanLifecycle(planId, at);
    if (!status.planComplete) throw StateError('Plan still has open work.');
  }

  @override
  Future<void> applyTrainingMaxDecision({
    required String planId,
    required String movementId,
    required double confirmedTrainingMax,
    required String reason,
    required DateTime at,
  }) async {
    if (confirmedTrainingMax <= 0 || reason.trim().isEmpty) {
      throw ArgumentError('A positive TM and reason are required.');
    }
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      await _applyFutureTrainingMax(
        tx,
        planId: planId,
        movementId: movementId,
        trainingMax: confirmedTrainingMax,
      );
      final updated = await _confirmTimeline(
        tx,
        planId: planId,
        movementId: movementId,
        trainingMax: confirmedTrainingMax,
        at: _date(at),
      );
      if (updated != 1) throw StateError('No pending TM decision was found.');
    });
  }

  Future<int> _confirmTimeline(
    DatabaseExecutor tx, {
    required String planId,
    required String movementId,
    required double trainingMax,
    required String at,
  }) async {
    final rows = await tx.query(
      'training_max_timeline',
      columns: ['id'],
      where: "plan_id = ? AND movement_id = ? AND state = 'previewed'",
      whereArgs: [planId, movementId],
      orderBy: 'sequence',
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return tx.update(
      'training_max_timeline',
      {
        'state': 'confirmed',
        'confirmed_training_max': trainingMax,
        'confirmed_at': at,
      },
      where: 'id = ?',
      whereArgs: [rows.single['id']],
    );
  }

  Future<void> _applyFutureTrainingMax(
    DatabaseExecutor tx, {
    required String planId,
    required String movementId,
    required double trainingMax,
  }) async {
    if (trainingMax <= 0) throw ArgumentError.value(trainingMax);
    final generic = await tx.rawQuery(
      '''SELECT ap.id, ap.target_json, ap.rounding_increment
         FROM activity_prescriptions ap
         JOIN session_blocks sb ON sb.id = ap.session_block_id
         JOIN plan_training_sessions s ON s.id = sb.session_id
         JOIN plan_training_cycles c ON c.id = s.cycle_id
         JOIN training_blocks b ON b.id = c.block_id
         WHERE b.plan_id = ? AND s.status = 'planned'
           AND ap.movement_or_activity_id = ?''',
      [planId, movementId],
    );
    for (final row in generic) {
      final target =
          jsonDecode(row['target_json']! as String) as Map<String, Object?>;
      final percentage = (target['percentage'] as num?)?.toDouble();
      if (percentage == null) continue;
      final unrounded = trainingMax * percentage;
      final increment = (row['rounding_increment'] as num?)?.toDouble();
      final rounded = increment == null
          ? unrounded
          : (unrounded / increment).round() * increment;
      await tx.update(
        'activity_prescriptions',
        {'unrounded_load': unrounded, 'calculated_load': rounded},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    final loaded = await tx.rawQuery(
      '''SELECT sp.id, sp.percentage, sp.rounding_increment
         FROM set_prescriptions sp
         JOIN session_blocks sb ON sb.id = sp.session_block_id
         JOIN plan_training_sessions s ON s.id = sb.session_id
         JOIN plan_training_cycles c ON c.id = s.cycle_id
         JOIN training_blocks b ON b.id = c.block_id
         WHERE b.plan_id = ? AND s.status = 'planned'
           AND sb.movement_id = ?''',
      [planId, movementId],
    );
    for (final row in loaded) {
      final percentage = (row['percentage'] as num?)?.toDouble();
      if (percentage == null) continue;
      final increment = (row['rounding_increment']! as num).toDouble();
      final unrounded = trainingMax * percentage;
      await tx.update(
        'set_prescriptions',
        {
          'training_max': trainingMax,
          'unrounded_load': unrounded,
          'prescribed_load': (unrounded / increment).round() * increment,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<List<Map<String, Object?>>> _planSessions(
    DatabaseExecutor tx,
    String planId,
  ) => tx.rawQuery(
    '''SELECT s.*, e.state AS execution_state
       FROM plan_training_sessions s
       JOIN plan_training_cycles c ON c.id = s.cycle_id
       JOIN training_blocks b ON b.id = c.block_id
       LEFT JOIN workout_executions e ON e.session_id = s.id
       WHERE b.plan_id = ? ORDER BY s.scheduled_for, s.id''',
    [planId],
  );

  void _validateRequest(PlanAmendmentRequest request) {
    if (request.planId.trim().isEmpty ||
        request.reason.trim().isEmpty ||
        request.ruleId.trim().isEmpty ||
        request.trainingMaxChanges.values.any((value) => value <= 0) ||
        (request.rescheduledSessions.isEmpty &&
            request.trainingMaxChanges.isEmpty)) {
      throw ArgumentError('A sourced, non-empty amendment is required.');
    }
  }

  static String _date(DateTime value) => value.toUtc().toIso8601String();
  static String _dateOnly(DateTime value) =>
      value.toUtc().toIso8601String().substring(0, 10);
}
