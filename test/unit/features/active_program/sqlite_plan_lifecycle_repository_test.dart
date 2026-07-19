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
    },
  );
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
