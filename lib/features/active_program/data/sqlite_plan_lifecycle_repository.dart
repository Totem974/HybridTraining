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
        if (session['status'] != 'planned') {
          throw StateError(
            'Only planned sessions can be rescheduled: $sessionId',
          );
        }
      }
      for (final sessionId in request.skippedSessionIds) {
        final session = byId[sessionId];
        if (session == null) {
          throw StateError('Session is outside the plan: $sessionId');
        }
        if (session['status'] != 'planned') {
          throw StateError('Only planned sessions can be skipped: $sessionId');
        }
      }
      final diff = await _expectedDiff(tx, sessions, request);
      final version =
          (Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COALESCE(MAX(version), 0) + 1 FROM plan_amendments WHERE plan_id = ?',
              [request.planId],
            ),
          ) ??
          1);
      final amendmentId = '${request.planId}:amendment:$version';
      final before = await _beforeSnapshot(tx, sessions, request);
      final after = _requestSnapshot(request);
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
        preservedCompletedSessionIds:
            (diff['preservedCompletedSessionIds']! as List).cast<String>(),
        activeSessionIds: (diff['activeSessionIds']! as List).cast<String>(),
        rescheduledSessionIds: (diff['rescheduledSessionIds']! as List)
            .cast<String>(),
        regeneratedSessionIds: request.trainingMaxChanges.isEmpty
            ? const []
            : (diff['regeneratedSessionIds']! as List).cast<String>(),
        cancelledSessionIds: (diff['cancelledSessionIds']! as List)
            .cast<String>(),
        trainingMaxChanges: Map.unmodifiable(
          (diff['trainingMaxChanges']! as Map).cast<String, double>(),
        ),
        prescriptionChanges: diff['prescriptionChanges']! as int,
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
      final preview = amendment.single;
      if (preview['reason'] != request.reason.trim() ||
          preview['rule_id'] != request.ruleId.trim() ||
          !_sameJson(
            preview['after_snapshot_json']! as String,
            _requestSnapshot(request),
          )) {
        throw StateError('The amendment request differs from its preview.');
      }
      if (!_sameJson(
        preview['before_snapshot_json']! as String,
        await _beforeSnapshot(tx, sessions, request),
      )) {
        throw StateError('The plan changed after the amendment preview.');
      }
      if (!_sameJson(
        preview['diff_json']! as String,
        await _expectedDiff(tx, sessions, request),
      )) {
        throw StateError('The amendment diff differs from its preview.');
      }
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
        final executionUpdated = await tx.update(
          'workout_executions',
          {'state': 'abandoned', 'ended_at': at, 'updated_at': at},
          where: "session_id = ? AND state IN ('activeSet','resting','paused')",
          whereArgs: [sessionId],
        );
        if (executionUpdated != 1) {
          throw StateError('The active workout changed after its preview.');
        }
        final sessionUpdated = await tx.update(
          'plan_training_sessions',
          {'status': 'cancelled', 'completed_at': at},
          where: "id = ? AND status = 'started'",
          whereArgs: [sessionId],
        );
        if (sessionUpdated != 1) {
          throw StateError('The active session changed after its preview.');
        }
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
      for (final sessionId in request.skippedSessionIds) {
        final updated = await tx.update(
          'plan_training_sessions',
          {
            'status': 'cancelled',
            'completed_at': at,
            'notes': request.reason.trim(),
          },
          where: "id = ? AND status = 'planned'",
          whereArgs: [sessionId],
        );
        if (updated != 1) {
          throw StateError('Only a planned future session can be skipped.');
        }
      }
      for (final entry in request.trainingMaxChanges.entries) {
        final timeline = await _pendingTimelineDecision(
          tx,
          planId: request.planId,
          movementId: entry.key,
          confirmedTrainingMax: entry.value,
        );
        await _applyFutureTrainingMax(
          tx,
          planId: request.planId,
          movementId: entry.key,
          trainingMax: entry.value,
        );
        final timelineUpdated = await _confirmTimeline(
          tx,
          timelineId: timeline.id,
          trainingMax: entry.value,
          at: at,
        );
        if (timelineUpdated != 1) {
          throw StateError('No pending TM decision was found.');
        }
      }
      final updated = await tx.update(
        'plan_amendments',
        {'state': 'applied', 'applied_at': at},
        where: "id = ? AND state = 'previewed'",
        whereArgs: [amendmentId],
      );
      if (updated != 1) {
        throw StateError('The amendment preview could not be applied.');
      }
    });
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
    return database.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''SELECT p.id AS plan_id, s.status, s.completed_at, e.state
           FROM plan_training_sessions s
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           JOIN training_plans p ON p.id = b.plan_id
           JOIN workout_executions e ON e.session_id = s.id
           WHERE s.id = ?''',
        [sessionId],
      );
      if (rows.length != 1 || rows.single['state'] != 'completed') {
        throw StateError('Workout execution must be completed first.');
      }
      final status = rows.single['status'];
      if (status == 'cancelled') {
        throw StateError('A cancelled session cannot be completed.');
      }
      if (status == 'planned') {
        throw StateError('A workout must be started before completion.');
      }
      if (status != 'complete') {
        final updated = await tx.update(
          'plan_training_sessions',
          {'status': 'complete', 'completed_at': _date(at)},
          where: "id = ? AND status = 'started'",
          whereArgs: [sessionId],
        );
        if (updated != 1) {
          throw StateError('Session changed before workout completion.');
        }
      }
      return _advancePlanLifecycle(tx, rows.single['plan_id']! as String, at);
    });
  }

  @override
  Future<LifecycleStatus> completeCycle(String cycleId, DateTime at) async {
    final database = await localDatabase.open();
    return database.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''SELECT c.status, c.block_id, b.plan_id,
                SUM(CASE WHEN s.status IN ('complete','cancelled') THEN 0 ELSE 1 END) AS open_count
         FROM plan_training_cycles c
         JOIN training_blocks b ON b.id = c.block_id
         JOIN plan_training_sessions s ON s.cycle_id = c.id
         WHERE c.id = ? GROUP BY c.id''',
        [cycleId],
      );
      if (rows.isEmpty || (rows.single['open_count']! as int) != 0) {
        throw StateError(
          'Every session must be closed before cycle completion.',
        );
      }
      final status = rows.single['status'];
      if (status == 'cancelled') {
        throw StateError('A cancelled cycle cannot be completed.');
      }
      if (status != 'complete') {
        final updated = await tx.update(
          'plan_training_cycles',
          {'status': 'complete'},
          where: "id = ? AND status IN ('planned','active')",
          whereArgs: [cycleId],
        );
        if (updated != 1) {
          throw StateError('Cycle changed before completion.');
        }
      }
      return _advancePlanLifecycle(tx, rows.single['plan_id']! as String, at);
    });
  }

  @override
  Future<LifecycleStatus> completeBlock(String blockId, DateTime at) async {
    final database = await localDatabase.open();
    return database.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''SELECT b.status, b.plan_id,
                SUM(CASE WHEN c.status IN ('complete','cancelled') THEN 0 ELSE 1 END) AS open_count
         FROM training_blocks b
         JOIN plan_training_cycles c ON c.block_id = b.id
         WHERE b.id = ? GROUP BY b.id''',
        [blockId],
      );
      if (rows.isEmpty || (rows.single['open_count']! as int) != 0) {
        throw StateError('Every cycle must be closed before block completion.');
      }
      final status = rows.single['status'];
      if (status == 'cancelled') {
        throw StateError('A cancelled block cannot be completed.');
      }
      if (status != 'complete') {
        final updated = await tx.update(
          'training_blocks',
          {'status': 'complete', 'completed_at': _date(at)},
          where: "id = ? AND status IN ('planned','active')",
          whereArgs: [blockId],
        );
        if (updated != 1) {
          throw StateError('Block changed before completion.');
        }
      }
      return _advancePlanLifecycle(tx, rows.single['plan_id']! as String, at);
    });
  }

  @override
  Future<LifecycleStatus> advancePlanLifecycle(
    String planId,
    DateTime at,
  ) async {
    final database = await localDatabase.open();
    return database.transaction((tx) => _advancePlanLifecycle(tx, planId, at));
  }

  Future<LifecycleStatus> _advancePlanLifecycle(
    DatabaseExecutor tx,
    String planId,
    DateTime at,
  ) async {
    final plans = await tx.query(
      'training_plans',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [planId],
      limit: 2,
    );
    if (plans.length != 1) throw StateError('Plan not found: $planId');
    final planStatus = plans.single['status'];
    if (planStatus == 'cancelled') {
      throw StateError('A cancelled plan cannot advance.');
    }

    await tx.rawUpdate(
      '''UPDATE plan_training_cycles SET status = 'complete'
           WHERE block_id IN (SELECT id FROM training_blocks WHERE plan_id = ?)
             AND status IN ('planned','active')
             AND NOT EXISTS (
               SELECT 1 FROM plan_training_sessions s
               WHERE s.cycle_id = plan_training_cycles.id
                 AND s.status NOT IN ('complete','cancelled'))''',
      [planId],
    );
    await tx.rawUpdate(
      '''UPDATE training_blocks SET status = 'complete', completed_at = ?
           WHERE plan_id = ? AND status IN ('planned','active')
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
      final updated = await tx.update(
        'training_plans',
        {'status': 'complete', 'completed_at': _date(at)},
        where: "id = ? AND status IN ('planned','active')",
        whereArgs: [planId],
      );
      if (planStatus != 'complete' && updated != 1) {
        throw StateError('Plan changed before completion.');
      }
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
    if (!confirmedTrainingMax.isFinite ||
        confirmedTrainingMax <= 0 ||
        reason.trim().isEmpty) {
      throw ArgumentError('A positive TM and reason are required.');
    }
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final timeline = await _pendingTimelineDecision(
        tx,
        planId: planId,
        movementId: movementId,
        confirmedTrainingMax: confirmedTrainingMax,
      );
      await _applyFutureTrainingMax(
        tx,
        planId: planId,
        movementId: movementId,
        trainingMax: confirmedTrainingMax,
      );
      final updated = await _confirmTimeline(
        tx,
        timelineId: timeline.id,
        trainingMax: confirmedTrainingMax,
        at: _date(at),
      );
      if (updated != 1) throw StateError('No pending TM decision was found.');
    });
  }

  Future<({String id, double previous, double proposed})>
  _pendingTimelineDecision(
    DatabaseExecutor tx, {
    required String planId,
    required String movementId,
    required double confirmedTrainingMax,
  }) async {
    final rows = await tx.query(
      'training_max_timeline',
      columns: ['id', 'previous_training_max', 'proposed_training_max'],
      where: "plan_id = ? AND movement_id = ? AND state = 'previewed'",
      whereArgs: [planId, movementId],
      orderBy: 'sequence',
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('No pending TM decision was found.');
    }
    final row = rows.single;
    final previous = (row['previous_training_max'] as num).toDouble();
    final proposed = (row['proposed_training_max'] as num).toDouble();
    if (!previous.isFinite ||
        previous <= 0 ||
        !proposed.isFinite ||
        proposed <= 0) {
      throw StateError('The pending TM decision contains an invalid value.');
    }
    final comparisonTolerance = proposed.abs() * 1e-9 + 1e-9;
    if (!confirmedTrainingMax.isFinite ||
        confirmedTrainingMax <= 0 ||
        confirmedTrainingMax - proposed > comparisonTolerance) {
      throw StateError('The confirmed TM exceeds the proposed TM.');
    }
    return (id: row['id']! as String, previous: previous, proposed: proposed);
  }

  Future<int> _confirmTimeline(
    DatabaseExecutor tx, {
    required String timelineId,
    required double trainingMax,
    required String at,
  }) async {
    return tx.update(
      'training_max_timeline',
      {
        'state': 'confirmed',
        'confirmed_training_max': trainingMax,
        'confirmed_at': at,
      },
      where: "id = ? AND state = 'previewed'",
      whereArgs: [timelineId],
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
    final rescheduledIds = request.rescheduledSessions.keys;
    final hasBlankSessionId =
        rescheduledIds.any((id) => id.trim().isEmpty) ||
        request.skippedSessionIds.any((id) => id.trim().isEmpty);
    final overlaps = rescheduledIds.any(request.skippedSessionIds.contains);
    if (request.planId.trim().isEmpty ||
        request.reason.trim().isEmpty ||
        request.ruleId.trim().isEmpty ||
        request.trainingMaxChanges.values.any((value) => value <= 0) ||
        hasBlankSessionId ||
        overlaps ||
        (request.rescheduledSessions.isEmpty &&
            request.skippedSessionIds.isEmpty &&
            request.trainingMaxChanges.isEmpty)) {
      throw ArgumentError('A sourced, non-empty amendment is required.');
    }
  }

  Future<Map<String, Object?>> _expectedDiff(
    DatabaseExecutor tx,
    List<Map<String, Object?>> sessions,
    PlanAmendmentRequest request,
  ) async {
    List<String> sessionIdsWhere(bool Function(Map<String, Object?>) test) =>
        sessions.where(test).map((row) => row['id']! as String).toList()
          ..sort();

    final completed = sessionIdsWhere((row) => row['status'] == 'complete');
    final active = sessionIdsWhere(
      (row) =>
          row['status'] == 'started' ||
          const {
            'activeSet',
            'resting',
            'paused',
          }.contains(row['execution_state']),
    );
    final planned = sessionIdsWhere((row) => row['status'] == 'planned');
    final rescheduled = request.rescheduledSessions.keys.toList()..sort();
    final skipped = request.skippedSessionIds.toList()..sort();
    final movements = request.trainingMaxChanges.keys.toList()..sort();
    final trainingMaxChanges = <String, double>{
      for (final movement in movements)
        movement: request.trainingMaxChanges[movement]!,
    };
    var prescriptionChanges = 0;
    for (final movement in movements) {
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
    return {
      'preservedCompletedSessionIds': completed,
      'activeSessionIds': active,
      'rescheduledSessionIds': rescheduled,
      'regeneratedSessionIds': request.trainingMaxChanges.isEmpty
          ? <String>[]
          : planned,
      'cancelledSessionIds': <String>{
        ...skipped,
        if (request.activeSessionDisposition ==
            ActiveSessionDisposition.abandon)
          ...active,
      }.toList()..sort(),
      'trainingMaxChanges': trainingMaxChanges,
      'prescriptionChanges': prescriptionChanges,
    };
  }

  Future<Map<String, Object?>> _beforeSnapshot(
    DatabaseExecutor tx,
    List<Map<String, Object?>> sessions,
    PlanAmendmentRequest request,
  ) async {
    final movements = request.trainingMaxChanges.keys.toList()..sort();
    final prescriptionInputs = <String, Object?>{};
    final timelineInputs = <String, Object?>{};
    for (final movement in movements) {
      prescriptionInputs[movement] = {
        'activities': await tx.rawQuery(
          '''SELECT ap.id, ap.target_json, ap.rounding_increment
             FROM activity_prescriptions ap
             JOIN session_blocks sb ON sb.id = ap.session_block_id
             JOIN plan_training_sessions s ON s.id = sb.session_id
             JOIN plan_training_cycles c ON c.id = s.cycle_id
             JOIN training_blocks b ON b.id = c.block_id
             WHERE b.plan_id = ? AND s.status = 'planned'
               AND ap.movement_or_activity_id = ? ORDER BY ap.id''',
          [request.planId, movement],
        ),
        'sets': await tx.rawQuery(
          '''SELECT sp.id, sp.percentage, sp.rounding_increment
             FROM set_prescriptions sp
             JOIN session_blocks sb ON sb.id = sp.session_block_id
             JOIN plan_training_sessions s ON s.id = sb.session_id
             JOIN plan_training_cycles c ON c.id = s.cycle_id
             JOIN training_blocks b ON b.id = c.block_id
             WHERE b.plan_id = ? AND s.status = 'planned'
               AND sb.movement_id = ? ORDER BY sp.id''',
          [request.planId, movement],
        ),
      };
      timelineInputs[movement] = await tx.query(
        'training_max_timeline',
        columns: ['id', 'sequence', 'state'],
        where: 'plan_id = ? AND movement_id = ?',
        whereArgs: [request.planId, movement],
        orderBy: 'sequence, id',
      );
    }
    final activeSessionIds =
        sessions
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
            .toList()
          ..sort();
    final activeProgress = activeSessionIds.isEmpty
        ? const <String, Object?>{
            'executions': <Object?>[],
            'outcomes': <Object?>[],
            'events': <Object?>[],
            'setPerformances': <Object?>[],
            'activityResults': <Object?>[],
          }
        : await _activeProgressSnapshot(tx, activeSessionIds);
    return {
      'sessions': {
        for (final row in sessions)
          row['id']! as String: {
            'cycleId': row['cycle_id'],
            'sequence': row['sequence'],
            'status': row['status'],
            'scheduledFor': row['scheduled_for'],
            'startedAt': row['started_at'],
            'completedAt': row['completed_at'],
            'notes': row['notes'],
            'restUntil': row['rest_until'],
            'programmingWeekNumber': row['programming_week_number'],
            'sessionPosition': row['session_position'],
            'executionState': row['execution_state'],
          },
      },
      'prescriptionInputs': prescriptionInputs,
      'timelineInputs': timelineInputs,
      'activeProgress': activeProgress,
    };
  }

  Future<Map<String, Object?>> _activeProgressSnapshot(
    DatabaseExecutor tx,
    List<String> sessionIds,
  ) async {
    final placeholders = List.filled(sessionIds.length, '?').join(',');
    return {
      'executions': await tx.rawQuery(
        '''SELECT * FROM workout_executions
           WHERE session_id IN ($placeholders) ORDER BY session_id''',
        sessionIds,
      ),
      'outcomes': await tx.rawQuery('''SELECT * FROM workout_set_outcomes
           WHERE session_id IN ($placeholders)
           ORDER BY session_id, sequence, prescription_id''', sessionIds),
      'events': await tx.rawQuery('''SELECT * FROM workout_execution_events
           WHERE session_id IN ($placeholders)
           ORDER BY session_id, sequence, id''', sessionIds),
      'setPerformances': await tx.rawQuery(
        '''SELECT performance.* FROM set_performances performance
           JOIN set_prescriptions prescription
             ON prescription.id = performance.prescription_id
           JOIN session_blocks block
             ON block.id = prescription.session_block_id
           WHERE block.session_id IN ($placeholders)
           ORDER BY block.session_id, performance.prescription_id,
                    performance.id''',
        sessionIds,
      ),
      'activityResults': await tx.rawQuery(
        '''SELECT result.* FROM activity_results result
           JOIN activity_prescriptions prescription
             ON prescription.id = result.prescription_id
           JOIN session_blocks block
             ON block.id = prescription.session_block_id
           WHERE block.session_id IN ($placeholders)
           ORDER BY block.session_id, result.prescription_id''',
        sessionIds,
      ),
    };
  }

  static Map<String, Object?> _requestSnapshot(PlanAmendmentRequest request) {
    final rescheduledIds = request.rescheduledSessions.keys.toList()..sort();
    final skippedIds = request.skippedSessionIds.toList()..sort();
    final movements = request.trainingMaxChanges.keys.toList()..sort();
    return {
      'rescheduledSessions': {
        for (final id in rescheduledIds)
          id: _date(request.rescheduledSessions[id]!),
      },
      'skippedSessionIds': skippedIds,
      'trainingMaxChanges': {
        for (final movement in movements)
          movement: request.trainingMaxChanges[movement],
      },
      'activeSessionDisposition': request.activeSessionDisposition.name,
    };
  }

  static bool _sameJson(String encoded, Object? value) =>
      jsonEncode(_canonicalJson(jsonDecode(encoded))) ==
      jsonEncode(_canonicalJson(value));

  static Object? _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalJson(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalJson).toList();
    return value;
  }

  static String _date(DateTime value) => value.toUtc().toIso8601String();
  static String _dateOnly(DateTime value) =>
      value.toUtc().toIso8601String().substring(0, 10);
}
