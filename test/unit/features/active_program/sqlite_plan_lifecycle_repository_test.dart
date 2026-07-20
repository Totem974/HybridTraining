import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/create_training_plan.dart';
import 'package:hybrid_training/features/active_program/application/plan_lifecycle.dart';
import 'package:hybrid_training/features/active_program/application/program_switch.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_plan_lifecycle_repository.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_versioned_plan_store.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqlitePlanLifecycleRepository lifecycle;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('plan-lifecycle-v5-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/lifecycle.db',
    );
    lifecycle = SqlitePlanLifecycleRepository(
      localDatabase: local,
      clock: () => DateTime.utc(2026, 7, 21, 8),
    );
    await _seedBeyondPlan(local);
  });

  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test('completeWorkout refuses cancelled and non-started sessions', () async {
    final database = await local.open();
    await database.insert('workout_executions', {
      'session_id': 'plan-session-1',
      'state': 'completed',
      'active_set_index': 0,
      'updated_at': '2026-07-21T07:00:00.000Z',
      'ended_at': '2026-07-21T07:00:00.000Z',
    });

    await expectLater(
      lifecycle.completeWorkout('plan-session-1', DateTime.utc(2026, 7, 21, 8)),
      throwsStateError,
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: ['plan-session-1'],
      )).single,
      {'status': 'planned', 'completed_at': null},
    );

    const cancelledAt = '2026-07-21T07:30:00.000Z';
    await database.update(
      'plan_training_sessions',
      {'status': 'cancelled', 'completed_at': cancelledAt},
      where: 'id = ?',
      whereArgs: ['plan-session-1'],
    );
    await expectLater(
      lifecycle.completeWorkout('plan-session-1', DateTime.utc(2026, 7, 21, 9)),
      throwsStateError,
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: ['plan-session-1'],
      )).single,
      {'status': 'cancelled', 'completed_at': cancelledAt},
    );
  });

  test('completeWorkout is idempotent and preserves completed_at', () async {
    final database = await local.open();
    const completedAt = '2026-07-21T07:30:00.000Z';
    await database.update(
      'plan_training_sessions',
      {'status': 'complete', 'completed_at': completedAt},
      where: 'id = ?',
      whereArgs: ['plan-session-1'],
    );
    await database.insert('workout_executions', {
      'session_id': 'plan-session-1',
      'state': 'completed',
      'active_set_index': 0,
      'updated_at': completedAt,
      'ended_at': completedAt,
    });

    await lifecycle.completeWorkout(
      'plan-session-1',
      DateTime.utc(2026, 7, 22, 9),
    );

    expect(
      (await database.query(
        'plan_training_sessions',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: ['plan-session-1'],
      )).single,
      {'status': 'complete', 'completed_at': completedAt},
    );
  });

  test('completeWorkout rolls back when lifecycle advancement fails', () async {
    final database = await local.open();
    await database.update(
      'plan_training_sessions',
      {'status': 'started', 'started_at': '2026-07-21T07:00:00.000Z'},
      where: 'id = ?',
      whereArgs: ['plan-session-1'],
    );
    await database.insert('workout_executions', {
      'session_id': 'plan-session-1',
      'state': 'completed',
      'active_set_index': 0,
      'updated_at': '2026-07-21T08:00:00.000Z',
      'ended_at': '2026-07-21T08:00:00.000Z',
    });
    await database.update(
      'training_plans',
      {'status': 'cancelled', 'completed_at': '2026-07-21T08:00:00.000Z'},
      where: 'id = ?',
      whereArgs: ['plan'],
    );

    await expectLater(
      lifecycle.completeWorkout('plan-session-1', DateTime.utc(2026, 7, 21, 9)),
      throwsStateError,
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: ['plan-session-1'],
      )).single,
      {'status': 'started', 'completed_at': null},
    );
  });

  test('abandon preview is invalidated by active workout progress', () async {
    final database = await local.open();
    await database.update(
      'plan_training_sessions',
      {'status': 'started', 'started_at': '2026-07-21T07:00:00.000Z'},
      where: 'id = ?',
      whereArgs: ['plan-session-2'],
    );
    await database.insert('workout_executions', {
      'session_id': 'plan-session-2',
      'state': 'activeSet',
      'active_set_index': 0,
      'updated_at': '2026-07-21T07:00:00.000Z',
    });
    await database.insert('activity_results', {
      'prescription_id': 'plan-session-2:set-1',
      'status': 'pending',
      'actual_json': '{}',
      'notes': '',
      'updated_at': '2026-07-21T07:00:00.000Z',
    });
    final request = PlanAmendmentRequest(
      planId: 'plan',
      reason: 'Abandon active fictitious workout',
      ruleId: 'TEST-ACTIVE-PROGRESS-SIGNATURE',
      rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 15)},
      activeSessionDisposition: ActiveSessionDisposition.abandon,
    );
    final stalePreview = await lifecycle.previewAmendment(request);
    await database.update(
      'plan_training_sessions',
      {'notes': 'Concurrent fictitious note'},
      where: 'id = ?',
      whereArgs: ['plan-session-2'],
    );
    await expectLater(
      lifecycle.applyAmendment(
        request,
        amendmentId: stalePreview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );
    await database.update(
      'plan_training_sessions',
      {'notes': ''},
      where: 'id = ?',
      whereArgs: ['plan-session-2'],
    );
    await database.update(
      'activity_results',
      {
        'status': 'success',
        'actual_json': '{"repetitions":5,"load":60}',
        'updated_at': '2026-07-21T07:05:00.000Z',
      },
      where: 'prescription_id = ?',
      whereArgs: ['plan-session-2:set-1'],
    );

    await expectLater(
      lifecycle.applyAmendment(
        request,
        amendmentId: stalePreview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );
    expect(
      (await database.query(
        'workout_executions',
        where: 'session_id = ?',
        whereArgs: ['plan-session-2'],
      )).single['state'],
      'activeSet',
    );
    expect(
      (await database.query(
        'plan_amendments',
        where: 'id = ?',
        whereArgs: [stalePreview.amendmentId],
      )).single['state'],
      'previewed',
    );

    final currentPreview = await lifecycle.previewAmendment(request);
    await lifecycle.applyAmendment(
      request,
      amendmentId: currentPreview.amendmentId,
      confirmed: true,
    );
    expect(
      (await database.query(
        'workout_executions',
        where: 'session_id = ?',
        whereArgs: ['plan-session-2'],
      )).single['state'],
      'abandoned',
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        where: 'id = ?',
        whereArgs: ['plan-session-2'],
      )).single['status'],
      'cancelled',
    );
  });

  test(
    'preview then apply changes only future work and preserves history',
    () async {
      final database = await local.open();
      await database.update(
        'plan_training_sessions',
        {'status': 'complete', 'completed_at': '2026-07-20T10:00:00.000Z'},
        where: 'id = ?',
        whereArgs: ['plan-session-1'],
      );
      await database.insert('activity_results', {
        'prescription_id': 'plan-session-1:set-1',
        'status': 'success',
        'actual_json': '{"repetitions":5,"load":65}',
        'rpe': 8.0,
        'notes': 'Immutable fictitious result',
        'recorded_at': '2026-07-20T10:00:00.000Z',
        'updated_at': '2026-07-20T10:00:00.000Z',
      });
      await database.update(
        'plan_training_sessions',
        {'status': 'started', 'started_at': '2026-07-21T07:00:00.000Z'},
        where: 'id = ?',
        whereArgs: ['plan-session-2'],
      );
      await database.insert('workout_executions', {
        'session_id': 'plan-session-2',
        'state': 'activeSet',
        'active_set_index': 0,
        'notes': '',
        'reversible_stack_json': '[]',
        'updated_at': '2026-07-21T07:00:00.000Z',
      });
      final completedLoad = (await database.query(
        'activity_prescriptions',
        columns: ['calculated_load'],
        where: 'id = ?',
        whereArgs: ['plan-session-1:set-1'],
      )).single['calculated_load'];
      final activeLoad = (await database.query(
        'activity_prescriptions',
        columns: ['calculated_load'],
        where: 'id = ?',
        whereArgs: ['plan-session-2:set-1'],
      )).single['calculated_load'];
      final request = PlanAmendmentRequest(
        planId: 'plan',
        reason: 'Confirmed future-only adjustment',
        ruleId: 'TEST-FUTURE-ONLY',
        rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 15)},
        trainingMaxChanges: {MovementId.squat.value: 110},
      );
      final rejectedPreview = await lifecycle.previewAmendment(request);
      expect(
        rejectedPreview.preservedCompletedSessionIds,
        contains('plan-session-1'),
      );
      expect(rejectedPreview.activeSessionIds, ['plan-session-2']);
      await expectLater(
        lifecycle.applyAmendment(
          request,
          amendmentId: rejectedPreview.amendmentId,
          confirmed: true,
        ),
        throwsStateError,
      );
      final accepted = PlanAmendmentRequest(
        planId: request.planId,
        reason: request.reason,
        ruleId: request.ruleId,
        rescheduledSessions: request.rescheduledSessions,
        trainingMaxChanges: request.trainingMaxChanges,
        activeSessionDisposition: ActiveSessionDisposition.abandon,
      );
      final preview = await lifecycle.previewAmendment(accepted);
      expect(preview.prescriptionChanges, greaterThan(0));
      await expectLater(
        lifecycle.applyAmendment(
          accepted,
          amendmentId: preview.amendmentId,
          confirmed: false,
        ),
        throwsStateError,
      );
      await lifecycle.applyAmendment(
        accepted,
        amendmentId: preview.amendmentId,
        confirmed: true,
      );

      expect(
        (await database.query(
          'plan_training_sessions',
          where: 'id = ?',
          whereArgs: ['plan-session-3'],
        )).single['scheduled_for'],
        '2026-08-15',
      );
      expect(
        (await database.query(
          'workout_executions',
          where: 'session_id = ?',
          whereArgs: ['plan-session-2'],
        )).single['state'],
        'abandoned',
      );
      expect(
        (await database.query(
          'activity_prescriptions',
          columns: ['calculated_load'],
          where: 'id = ?',
          whereArgs: ['plan-session-1:set-1'],
        )).single['calculated_load'],
        completedLoad,
      );
      expect(
        (await database.query(
          'activity_prescriptions',
          columns: ['calculated_load'],
          where: 'id = ?',
          whereArgs: ['plan-session-2:set-1'],
        )).single['calculated_load'],
        activeLoad,
      );
      expect(await database.query('activity_results'), hasLength(1));
      expect(
        (await database.query(
          'plan_amendments',
          where: 'id = ?',
          whereArgs: [preview.amendmentId],
        )).single['state'],
        'applied',
      );
    },
  );

  test(
    'reschedules any identified planned session and refuses history',
    () async {
      await lifecycle.rescheduleSession(
        'plan-session-8',
        DateTime.utc(2026, 9, 1),
      );
      final database = await local.open();
      expect(
        (await database.query(
          'plan_training_sessions',
          where: 'id = ?',
          whereArgs: ['plan-session-8'],
        )).single['scheduled_for'],
        '2026-09-01',
      );
      await database.update(
        'plan_training_sessions',
        {'status': 'complete'},
        where: 'id = ?',
        whereArgs: ['plan-session-8'],
      );
      await expectLater(
        lifecycle.rescheduleSession('plan-session-8', DateTime.utc(2026, 9, 2)),
        throwsStateError,
      );
    },
  );

  test('refuses a request changed after preview without mutation', () async {
    final previewed = PlanAmendmentRequest(
      planId: 'plan',
      reason: 'Previewed fictitious reschedule',
      ruleId: 'TEST-PREVIEW-MATCH',
      rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 15)},
    );
    final preview = await lifecycle.previewAmendment(previewed);
    final database = await local.open();
    final originalSchedule = (await database.query(
      'plan_training_sessions',
      columns: ['scheduled_for'],
      where: 'id = ?',
      whereArgs: ['plan-session-3'],
    )).single['scheduled_for'];
    final changed = PlanAmendmentRequest(
      planId: previewed.planId,
      reason: previewed.reason,
      ruleId: previewed.ruleId,
      rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 16)},
    );

    await expectLater(
      lifecycle.applyAmendment(
        changed,
        amendmentId: preview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );

    expect(
      (await database.query(
        'plan_training_sessions',
        where: 'id = ?',
        whereArgs: ['plan-session-3'],
      )).single['scheduled_for'],
      originalSchedule,
    );
    expect(
      (await database.query(
        'plan_amendments',
        where: 'id = ?',
        whereArgs: [preview.amendmentId],
      )).single['state'],
      'previewed',
    );
  });

  test('refuses a stale persisted state without partial mutation', () async {
    final request = PlanAmendmentRequest(
      planId: 'plan',
      reason: 'Previewed before external future change',
      ruleId: 'TEST-STALE-PREVIEW',
      rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 15)},
    );
    final preview = await lifecycle.previewAmendment(request);
    final database = await local.open();
    final originalTargetSchedule = (await database.query(
      'plan_training_sessions',
      columns: ['scheduled_for'],
      where: 'id = ?',
      whereArgs: ['plan-session-3'],
    )).single['scheduled_for'];
    await database.update(
      'plan_training_sessions',
      {'scheduled_for': '2026-08-01'},
      where: 'id = ?',
      whereArgs: ['plan-session-8'],
    );

    await expectLater(
      lifecycle.applyAmendment(
        request,
        amendmentId: preview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );

    expect(
      (await database.query(
        'plan_training_sessions',
        where: 'id = ?',
        whereArgs: ['plan-session-3'],
      )).single['scheduled_for'],
      originalTargetSchedule,
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        where: 'id = ?',
        whereArgs: ['plan-session-8'],
      )).single['scheduled_for'],
      '2026-08-01',
    );
    expect(
      (await database.query(
        'plan_amendments',
        where: 'id = ?',
        whereArgs: [preview.amendmentId],
      )).single['state'],
      'previewed',
    );
  });

  test('refuses an active execution completed after preview', () async {
    final database = await local.open();
    await database.update(
      'plan_training_sessions',
      {'status': 'started'},
      where: 'id = ?',
      whereArgs: ['plan-session-2'],
    );
    await database.insert('workout_executions', {
      'session_id': 'plan-session-2',
      'state': 'activeSet',
      'active_set_index': 0,
      'notes': '',
      'reversible_stack_json': '[]',
      'updated_at': '2026-07-21T07:00:00.000Z',
    });
    final request = PlanAmendmentRequest(
      planId: 'plan',
      reason: 'Preview while a fictitious workout is active',
      ruleId: 'TEST-ACTIVE-RACE',
      rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 15)},
      activeSessionDisposition: ActiveSessionDisposition.abandon,
    );
    final preview = await lifecycle.previewAmendment(request);
    await database.update(
      'workout_executions',
      {'state': 'completed'},
      where: 'session_id = ?',
      whereArgs: ['plan-session-2'],
    );

    await expectLater(
      lifecycle.applyAmendment(
        request,
        amendmentId: preview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );

    expect(
      (await database.query(
        'workout_executions',
        where: 'session_id = ?',
        whereArgs: ['plan-session-2'],
      )).single['state'],
      'completed',
    );
    expect(
      (await database.query(
        'plan_amendments',
        where: 'id = ?',
        whereArgs: [preview.amendmentId],
      )).single['state'],
      'previewed',
    );
  });

  test('refuses changed TM calculation inputs after preview', () async {
    final request = PlanAmendmentRequest(
      planId: 'plan',
      reason: 'Preview fictitious TM recalculation',
      ruleId: 'TEST-TM-INPUT-RACE',
      trainingMaxChanges: {MovementId.squat.value: 110},
    );
    final preview = await lifecycle.previewAmendment(request);
    final database = await local.open();
    final prescription = (await database.rawQuery(
      '''SELECT ap.id, ap.calculated_load
         FROM activity_prescriptions ap
         JOIN session_blocks sb ON sb.id = ap.session_block_id
         JOIN plan_training_sessions s ON s.id = sb.session_id
         WHERE s.status = 'planned' AND ap.movement_or_activity_id = ?
         ORDER BY ap.id LIMIT 1''',
      [MovementId.squat.value],
    )).single;
    await database.update(
      'activity_prescriptions',
      {'target_json': '{"percentage":0.01}'},
      where: 'id = ?',
      whereArgs: [prescription['id']],
    );

    await expectLater(
      lifecycle.applyAmendment(
        request,
        amendmentId: preview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );

    expect(
      (await database.query(
        'activity_prescriptions',
        columns: ['calculated_load'],
        where: 'id = ?',
        whereArgs: [prescription['id']],
      )).single['calculated_load'],
      prescription['calculated_load'],
    );
    expect(
      await database.query(
        'training_max_timeline',
        where: "movement_id = ? AND state = 'confirmed'",
        whereArgs: [MovementId.squat.value],
      ),
      hasLength(1),
    );
    expect(
      (await database.query(
        'plan_amendments',
        where: 'id = ?',
        whereArgs: [preview.amendmentId],
      )).single['state'],
      'previewed',
    );
  });

  test('confirmed TM decision rewrites only future prescriptions', () async {
    final database = await local.open();
    await database.update(
      'plan_training_sessions',
      {'status': 'started'},
      where: 'id = ?',
      whereArgs: ['plan-session-1'],
    );
    final historical = (await database.query(
      'activity_prescriptions',
      columns: ['calculated_load'],
      where: 'id = ?',
      whereArgs: ['plan-session-1:set-1'],
    )).single['calculated_load'];
    await lifecycle.applyTrainingMaxDecision(
      planId: 'plan',
      movementId: MovementId.squat.value,
      confirmedTrainingMax: 110,
      reason: 'Confirmed source-defined checkpoint',
      at: DateTime.utc(2026, 8, 10),
    );
    expect(
      (await database.query(
        'activity_prescriptions',
        columns: ['calculated_load'],
        where: 'id = ?',
        whereArgs: ['plan-session-1:set-1'],
      )).single['calculated_load'],
      historical,
    );
    expect(
      (await database.query(
        'activity_prescriptions',
        columns: ['calculated_load'],
        where: 'id = ?',
        whereArgs: ['plan-session-13:set-1'],
      )).single['calculated_load'],
      72.5,
    );
    expect(
      await database.query(
        'training_max_timeline',
        where: "movement_id = ? AND state = 'confirmed'",
        whereArgs: [MovementId.squat.value],
      ),
      hasLength(2),
    );
  });

  test(
    'refuses a TM above the preview proposal without partial mutation',
    () async {
      final database = await local.open();
      final activityBefore = await database.query(
        'activity_prescriptions',
        columns: ['id', 'unrounded_load', 'calculated_load'],
        orderBy: 'id',
      );
      final setsBefore = await database.query(
        'set_prescriptions',
        columns: ['id', 'training_max', 'unrounded_load', 'prescribed_load'],
        orderBy: 'id',
      );
      final pendingBefore = (await database.query(
        'training_max_timeline',
        where: "plan_id = ? AND movement_id = ? AND state = 'previewed'",
        whereArgs: ['plan', MovementId.squat.value],
        orderBy: 'sequence',
        limit: 1,
      )).single;
      final proposed = (pendingBefore['proposed_training_max'] as num)
          .toDouble();

      await expectLater(
        lifecycle.applyTrainingMaxDecision(
          planId: 'plan',
          movementId: MovementId.squat.value,
          confirmedTrainingMax: proposed + 0.01,
          reason: 'Fictitious decision above the previewed bound',
          at: DateTime.utc(2026, 8, 10),
        ),
        throwsStateError,
      );

      expect(
        await database.query(
          'activity_prescriptions',
          columns: ['id', 'unrounded_load', 'calculated_load'],
          orderBy: 'id',
        ),
        activityBefore,
      );
      expect(
        await database.query(
          'set_prescriptions',
          columns: ['id', 'training_max', 'unrounded_load', 'prescribed_load'],
          orderBy: 'id',
        ),
        setsBefore,
      );
      final pendingAfter = (await database.query(
        'training_max_timeline',
        where: 'id = ?',
        whereArgs: [pendingBefore['id']],
      )).single;
      expect(pendingAfter['state'], 'previewed');
      expect(pendingAfter['confirmed_training_max'], isNull);
      expect(pendingAfter['confirmed_at'], isNull);
    },
  );

  test('amendment cannot bypass the previewed TM proposal', () async {
    final database = await local.open();
    final pending = (await database.query(
      'training_max_timeline',
      where: "plan_id = ? AND movement_id = ? AND state = 'previewed'",
      whereArgs: ['plan', MovementId.squat.value],
      orderBy: 'sequence',
      limit: 1,
    )).single;
    final request = PlanAmendmentRequest(
      planId: 'plan',
      reason: 'Fictitious amendment above the previewed bound',
      ruleId: 'TEST-TM-PROPOSAL-BOUND',
      rescheduledSessions: {'plan-session-3': DateTime.utc(2026, 8, 20)},
      trainingMaxChanges: {
        MovementId.squat.value:
            (pending['proposed_training_max'] as num).toDouble() + 0.01,
      },
    );
    final preview = await lifecycle.previewAmendment(request);
    final prescriptionsBefore = await database.query(
      'activity_prescriptions',
      columns: ['id', 'unrounded_load', 'calculated_load'],
      orderBy: 'id',
    );
    final scheduleBefore = (await database.query(
      'plan_training_sessions',
      columns: ['scheduled_for'],
      where: 'id = ?',
      whereArgs: ['plan-session-3'],
    )).single['scheduled_for'];

    await expectLater(
      lifecycle.applyAmendment(
        request,
        amendmentId: preview.amendmentId,
        confirmed: true,
      ),
      throwsStateError,
    );

    expect(
      await database.query(
        'activity_prescriptions',
        columns: ['id', 'unrounded_load', 'calculated_load'],
        orderBy: 'id',
      ),
      prescriptionsBefore,
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        columns: ['scheduled_for'],
        where: 'id = ?',
        whereArgs: ['plan-session-3'],
      )).single['scheduled_for'],
      scheduleBefore,
    );
    final timelineAfter = (await database.query(
      'training_max_timeline',
      where: 'id = ?',
      whereArgs: [pending['id']],
    )).single;
    expect(timelineAfter['state'], 'previewed');
    expect(timelineAfter['confirmed_training_max'], isNull);
    expect(
      (await database.query(
        'plan_amendments',
        where: 'id = ?',
        whereArgs: [preview.amendmentId],
      )).single['state'],
      'previewed',
    );
  });

  test(
    'advances cycle, block and plan only when children are closed',
    () async {
      final database = await local.open();
      await database.update('plan_training_sessions', {'status': 'complete'});
      final status = await lifecycle.advancePlanLifecycle(
        'plan',
        DateTime.utc(2026, 10, 1),
      );
      expect(status.planComplete, isTrue);
      expect(
        (await database.query(
          'plan_training_cycles',
        )).every((row) => row['status'] == 'complete'),
        isTrue,
      );
      expect(
        (await database.query(
          'training_blocks',
        )).every((row) => row['status'] == 'complete'),
        isTrue,
      );
      expect(
        (await database.query('training_plans')).single['status'],
        'complete',
      );
      final completedAt = (await database.query(
        'training_plans',
        columns: ['completed_at'],
      )).single['completed_at'];
      final repeated = await lifecycle.advancePlanLifecycle(
        'plan',
        DateTime.utc(2026, 10, 2),
      );
      expect(repeated.planComplete, isTrue);
      expect(
        (await database.query(
          'training_plans',
          columns: ['completed_at'],
        )).single['completed_at'],
        completedAt,
      );
    },
  );

  test(
    'a cancelled cycle stays terminal when its sessions are closed',
    () async {
      final database = await local.open();
      final cycleId =
          (await database.query(
                'plan_training_cycles',
                columns: ['id'],
                orderBy: 'sequence',
                limit: 1,
              )).single['id']!
              as String;
      await database.update(
        'plan_training_sessions',
        {'status': 'complete'},
        where: 'cycle_id = ?',
        whereArgs: [cycleId],
      );
      await database.update(
        'plan_training_cycles',
        {'status': 'cancelled'},
        where: 'id = ?',
        whereArgs: [cycleId],
      );

      await lifecycle.advancePlanLifecycle('plan', DateTime.utc(2026, 10, 1));
      expect(
        (await database.query(
          'plan_training_cycles',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [cycleId],
        )).single['status'],
        'cancelled',
      );
      await expectLater(
        lifecycle.completeCycle(cycleId, DateTime.utc(2026, 10, 2)),
        throwsStateError,
      );
      expect(
        (await database.query(
          'plan_training_cycles',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [cycleId],
        )).single['status'],
        'cancelled',
      );
    },
  );

  test('a cancelled block keeps its terminal status and timestamp', () async {
    final database = await local.open();
    final blockId =
        (await database.query(
              'training_blocks',
              columns: ['id'],
              orderBy: 'sequence',
              limit: 1,
            )).single['id']!
            as String;
    await database.update(
      'plan_training_cycles',
      {'status': 'complete'},
      where: 'block_id = ?',
      whereArgs: [blockId],
    );
    const cancelledAt = '2026-09-30T07:00:00.000Z';
    await database.update(
      'training_blocks',
      {'status': 'cancelled', 'completed_at': cancelledAt},
      where: 'id = ?',
      whereArgs: [blockId],
    );

    await lifecycle.advancePlanLifecycle('plan', DateTime.utc(2026, 10, 1));
    final afterAdvance = (await database.query(
      'training_blocks',
      columns: ['status', 'completed_at'],
      where: 'id = ?',
      whereArgs: [blockId],
    )).single;
    expect(afterAdvance['status'], 'cancelled');
    expect(afterAdvance['completed_at'], cancelledAt);
    await expectLater(
      lifecycle.completeBlock(blockId, DateTime.utc(2026, 10, 2)),
      throwsStateError,
    );
    expect(
      (await database.query(
        'training_blocks',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: [blockId],
      )).single,
      {'status': 'cancelled', 'completed_at': cancelledAt},
    );
  });

  test(
    'a cancelled plan refuses advancement without changing descendants',
    () async {
      final database = await local.open();
      await database.update('plan_training_sessions', {'status': 'complete'});
      const cancelledAt = '2026-09-30T07:00:00.000Z';
      await database.update(
        'training_plans',
        {'status': 'cancelled', 'completed_at': cancelledAt},
        where: 'id = ?',
        whereArgs: ['plan'],
      );
      final cyclesBefore = await database.query(
        'plan_training_cycles',
        columns: ['id', 'status'],
        orderBy: 'id',
      );
      final blocksBefore = await database.query(
        'training_blocks',
        columns: ['id', 'status', 'started_at', 'completed_at'],
        orderBy: 'id',
      );

      await expectLater(
        lifecycle.advancePlanLifecycle('plan', DateTime.utc(2026, 10, 1)),
        throwsStateError,
      );
      await expectLater(
        lifecycle.completeTrainingPlan('plan', DateTime.utc(2026, 10, 2)),
        throwsStateError,
      );
      expect(
        await database.query(
          'plan_training_cycles',
          columns: ['id', 'status'],
          orderBy: 'id',
        ),
        cyclesBefore,
      );
      expect(
        await database.query(
          'training_blocks',
          columns: ['id', 'status', 'started_at', 'completed_at'],
          orderBy: 'id',
        ),
        blocksBefore,
      );
      expect(
        (await database.query(
          'training_plans',
          columns: ['status', 'completed_at'],
          where: 'id = ?',
          whereArgs: ['plan'],
        )).single,
        {'status': 'cancelled', 'completed_at': cancelledAt},
      );
    },
  );

  test('cycle completion rolls back when its plan is cancelled', () async {
    final database = await local.open();
    final cycle = (await database.rawQuery(
      '''SELECT c.id, c.status
         FROM plan_training_cycles c
         JOIN training_blocks b ON b.id = c.block_id
         WHERE b.plan_id = ? AND c.status IN ('planned','active')
         ORDER BY b.sequence, c.sequence LIMIT 1''',
      ['plan'],
    )).single;
    final cycleId = cycle['id']! as String;
    await database.update(
      'plan_training_sessions',
      {'status': 'complete'},
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
    );
    const cancelledAt = '2026-09-30T07:00:00.000Z';
    await database.update(
      'training_plans',
      {'status': 'cancelled', 'completed_at': cancelledAt},
      where: 'id = ?',
      whereArgs: ['plan'],
    );
    final blocksBefore = await database.query(
      'training_blocks',
      columns: ['id', 'status', 'started_at', 'completed_at'],
      orderBy: 'id',
    );

    await expectLater(
      lifecycle.completeCycle(cycleId, DateTime.utc(2026, 10, 1)),
      throwsStateError,
    );

    expect(
      (await database.query(
        'plan_training_cycles',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [cycleId],
      )).single['status'],
      cycle['status'],
    );
    expect(
      await database.query(
        'training_blocks',
        columns: ['id', 'status', 'started_at', 'completed_at'],
        orderBy: 'id',
      ),
      blocksBefore,
    );
    expect(
      (await database.query(
        'training_plans',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: ['plan'],
      )).single,
      {'status': 'cancelled', 'completed_at': cancelledAt},
    );
  });

  test('block completion rolls back when its plan is cancelled', () async {
    final database = await local.open();
    final block = (await database.query(
      'training_blocks',
      columns: ['id', 'status', 'started_at', 'completed_at'],
      where: "plan_id = ? AND status IN ('planned','active')",
      whereArgs: ['plan'],
      orderBy: 'sequence',
      limit: 1,
    )).single;
    final blockId = block['id']! as String;
    await database.update(
      'plan_training_cycles',
      {'status': 'complete'},
      where: 'block_id = ?',
      whereArgs: [blockId],
    );
    const cancelledAt = '2026-09-30T07:00:00.000Z';
    await database.update(
      'training_plans',
      {'status': 'cancelled', 'completed_at': cancelledAt},
      where: 'id = ?',
      whereArgs: ['plan'],
    );
    final cyclesBefore = await database.query(
      'plan_training_cycles',
      columns: ['id', 'status'],
      orderBy: 'id',
    );

    await expectLater(
      lifecycle.completeBlock(blockId, DateTime.utc(2026, 10, 1)),
      throwsStateError,
    );

    expect(
      (await database.query(
        'training_blocks',
        columns: ['id', 'status', 'started_at', 'completed_at'],
        where: 'id = ?',
        whereArgs: [blockId],
      )).single,
      block,
    );
    expect(
      await database.query(
        'plan_training_cycles',
        columns: ['id', 'status'],
        orderBy: 'id',
      ),
      cyclesBefore,
    );
    expect(
      (await database.query(
        'training_plans',
        columns: ['status', 'completed_at'],
        where: 'id = ?',
        whereArgs: ['plan'],
      )).single,
      {'status': 'cancelled', 'completed_at': cancelledAt},
    );
  });
}

Future<void> _seedBeyondPlan(LocalDatabase local) async {
  final database = await local.open();
  const at = '2026-07-19T08:00:00.000Z';
  await database.insert('athlete_profiles', {
    'id': 'athlete',
    'display_name': 'Fictitious Lifecycle Athlete',
    'preferred_unit': 'kg',
    'rounding_increment': 2.5,
    'created_at': at,
    'updated_at': at,
  });
  const movements = [
    MovementId.squat,
    MovementId.benchPress,
    MovementId.deadlift,
    MovementId.overheadPress,
  ];
  final initial = {
    MovementId.squat: 100.0,
    MovementId.benchPress: 80.0,
    MovementId.deadlift: 120.0,
    MovementId.overheadPress: 60.0,
  };
  final increments = {
    MovementId.squat: 5.0,
    MovementId.benchPress: 2.5,
    MovementId.deadlift: 5.0,
    MovementId.overheadPress: 2.5,
  };
  final confirmed = {
    for (final movement in movements)
      movement: initial[movement]! + increments[movement]!,
  };
  await CreateTrainingPlan(
    repository: SqliteVersionedPlanStore(localDatabase: local),
    clock: () => DateTime.utc(2026, 7, 19, 8),
  )(
    CreateTrainingPlanRequest(
      planId: 'plan',
      athleteId: 'athlete',
      presetId: 'beyond-six-week-cycle-v1',
      athlete: CanonicalAthleteConfiguration(
        movementOrder: movements,
        trainingMaxes: initial,
        progressionIncrements: increments,
        trainingWeekdays: const [1, 2, 4, 5],
        startDate: const LocalDate(2026, 7, 20),
        unit: WeightUnit.kilograms,
        rounder: const LoadRounder(increment: 2.5),
        confirmedBeyondTrainingMaxes: confirmed,
      ),
    ),
  );
}
