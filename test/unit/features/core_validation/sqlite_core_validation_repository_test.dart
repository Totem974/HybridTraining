import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteCoreValidationRepository repository;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('core-validation-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/core.db',
    );
    repository = SqliteCoreValidationRepository(
      localDatabase: local,
      clock: () => DateTime.utc(2026, 7, 20),
    );
  });

  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test('DEV fixture persists one Beginner plan and is idempotent', () async {
    await repository.createDevelopmentFixture();
    await repository.createDevelopmentFixture();

    final snapshot = await repository.load();
    expect(snapshot.profileName, 'Athlete DEV');
    expect(snapshot.activePlans, 1);
    expect(snapshot.plannedSessions, 9);
    expect(snapshot.actualTonnage, isNull);
    final database = await local.open();
    expect(
      (await database.query('training_plans')).single['blueprint_id'],
      'forever-beginner-prep-school-v1',
    );
  });

  test('program switch preview generates a diff without writing', () async {
    await repository.createDevelopmentFixture();
    final preview = await repository.previewProgramSwitch(
      DateTime.utc(2026, 8, 3),
    );
    expect(preview.currentPlanId, 'dev-bps-plan-1');
    expect(preview.nextPlanId, 'preview-bps-2026-08-03');
    expect(preview.nextStartDate, DateTime(2026, 8, 3));
    final database = await local.open();
    expect(await database.query('training_plans'), hasLength(1));
    expect(await database.query('plan_events'), isEmpty);
  });

  test(
    'confirmed program switch preserves history and activates next plan',
    () async {
      await repository.createDevelopmentFixture();
      final preview = await repository.previewProgramSwitch(
        DateTime.utc(2026, 8, 3),
      );
      await repository.applyProgramSwitch(
        DateTime.utc(2026, 8, 3),
        abandonActiveSession: false,
        previewId: preview.previewId,
        confirmed: true,
      );
      final database = await local.open();
      final plans = await database.query(
        'training_plans',
        orderBy: 'created_at',
      );
      expect(plans, hasLength(2));
      expect(plans.first['status'], 'cancelled');
      expect(plans.last['status'], 'active');
      expect(await database.query('plan_events'), hasLength(1));
    },
  );

  test(
    'program switch remains applicable when the repository clock advances',
    () async {
      var now = DateTime.utc(2026, 7, 20, 10);
      repository = SqliteCoreValidationRepository(
        localDatabase: local,
        clock: () => now,
      );
      await repository.createDevelopmentFixture();
      final preview = await repository.previewProgramSwitch(
        DateTime.utc(2026, 8, 3),
      );
      now = DateTime.utc(2026, 7, 20, 11);

      await repository.applyProgramSwitch(
        DateTime.utc(2026, 8, 3),
        abandonActiveSession: false,
        previewId: preview.previewId,
        confirmed: true,
      );

      final database = await local.open();
      expect(await database.query('training_plans'), hasLength(2));
    },
  );

  test(
    'planned workout is rescheduled then skipped through previews',
    () async {
      await repository.createDevelopmentFixture();
      final sessionId = (await repository.loadFirstWorkout())!.sessionId;
      final reschedule = await repository.previewRescheduleWorkout(
        DateTime.utc(2026, 9, 1),
      );
      await repository.applyWorkoutAmendment(
        reschedule.request,
        amendmentId: reschedule.preview.amendmentId,
        confirmed: true,
      );
      final database = await local.open();
      expect(
        (await database.query(
          'plan_training_sessions',
          columns: ['scheduled_for'],
          where: 'id = ?',
          whereArgs: [sessionId],
        )).single['scheduled_for'],
        '2026-09-01',
      );
      final skip = await repository.previewSkipWorkout();
      final skippedSessionId = skip.request.skippedSessionIds.single;
      await repository.applyWorkoutAmendment(
        skip.request,
        amendmentId: skip.preview.amendmentId,
        confirmed: true,
      );
      expect(
        (await database.query(
          'plan_training_sessions',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [skippedSessionId],
        )).single['status'],
        'cancelled',
      );
      expect(await database.query('workout_executions'), isEmpty);
    },
  );

  test(
    'workout amendment cannot apply without explicit confirmation',
    () async {
      await repository.createDevelopmentFixture();
      final draft = await repository.previewSkipWorkout();

      await expectLater(
        repository.applyWorkoutAmendment(
          draft.request,
          amendmentId: draft.preview.amendmentId,
          confirmed: false,
        ),
        throwsStateError,
      );

      final database = await local.open();
      expect(
        (await database.query(
          'plan_training_sessions',
          where: 'id = ?',
          whereArgs: [draft.request.skippedSessionIds.single],
        )).single['status'],
        'planned',
      );
    },
  );

  test(
    'active workout requires explicit abandonment and preserves outcomes',
    () async {
      await repository.createDevelopmentFixture();
      await repository.startFirstWorkout();
      await _advanceToLoadedSet(repository);
      await repository.recordCurrentSet(
        status: SetOutcomeStatus.success,
        actualRepetitions: 5,
        actualLoad: 40,
      );
      await repository.abandonWorkout();
      final database = await local.open();
      expect(
        (await database.query('workout_executions')).single['state'],
        'abandoned',
      );
      expect(
        (await database.query('activity_results', where: "status = 'success'")),
        hasLength(1),
      );
    },
  );

  test(
    'tonnage uses actual successful load and never prescribed load',
    () async {
      await repository.createDevelopmentFixture();
      final database = await local.open();
      final prescription = (await database.query(
        'activity_prescriptions',
        where: "target_type = 'setsRepsLoad'",
        limit: 1,
      )).single;
      expect((await repository.load()).actualTonnage, isNull);

      await database.insert('activity_results', {
        'prescription_id': prescription['id'],
        'status': 'success',
        'actual_json': jsonEncode({'repetitions': 6, 'load': 42.5}),
        'rpe': null,
        'notes': '',
        'recorded_at': DateTime.utc(2026, 7, 20).toIso8601String(),
        'updated_at': DateTime.utc(2026, 7, 20).toIso8601String(),
      });

      expect((await repository.load()).actualTonnage, 255);
    },
  );

  test(
    'runs, pauses, reopens, undoes and completes the first workout',
    () async {
      await repository.createDevelopmentFixture();
      expect(
        (await repository.loadFirstWorkout())?.state,
        WorkoutExecutionState.planned,
      );

      await repository.startFirstWorkout();
      final precedingActivities = await _advanceToLoadedSet(repository);
      await repository.recordCurrentSet(
        status: SetOutcomeStatus.success,
        actualRepetitions: 6,
        actualLoad: 42.5,
        rpe: 8,
        notes: 'Fictitious integration result',
      );
      await repository.pauseOrResumeWorkout();
      expect(
        (await repository.loadFirstWorkout())?.state,
        WorkoutExecutionState.paused,
      );

      await local.close();
      repository = SqliteCoreValidationRepository(
        localDatabase: local,
        clock: () => DateTime.utc(2026, 7, 20, 10, 5),
      );
      expect(
        (await repository.loadFirstWorkout())?.state,
        WorkoutExecutionState.paused,
      );
      await repository.pauseOrResumeWorkout();
      await repository.undoLastSet();
      expect(
        (await repository.loadFirstWorkout())?.completedSets,
        precedingActivities,
      );
      await repository.recordCurrentSet(
        status: SetOutcomeStatus.success,
        actualRepetitions: 6,
        actualLoad: 42.5,
        rpe: 8,
      );
      await repository.beginOrEndRest(duration: const Duration(seconds: 45));
      expect(
        (await repository.loadFirstWorkout())?.state,
        WorkoutExecutionState.resting,
      );
      await repository.beginOrEndRest(duration: const Duration(seconds: 45));

      var workout = await repository.loadFirstWorkout();
      while (workout!.completedSets < workout.totalSets) {
        await repository.recordCurrentSet(status: SetOutcomeStatus.skipped);
        workout = await repository.loadFirstWorkout();
      }
      expect(workout.canComplete, isTrue);
      await repository.completeWorkout();

      final snapshot = await repository.load();
      expect(snapshot.completedSessions, 1);
      expect(snapshot.successfulSets, 1);
      expect(snapshot.skippedSets, 15);
      expect(snapshot.successfulSets + snapshot.skippedSets, 16);
      expect(snapshot.actualTonnage, 255);
      final database = await local.open();
      expect(
        (await database.query('workout_executions', limit: 1)).single['state'],
        'completed',
      );
    },
  );
}

Future<int> _advanceToLoadedSet(
  SqliteCoreValidationRepository repository,
) async {
  var skipped = 0;
  var workout = await repository.loadFirstWorkout();
  while (workout!.itemKind == ExecutionItemKind.activity) {
    await repository.recordCurrentSet(status: SetOutcomeStatus.skipped);
    skipped++;
    workout = await repository.loadFirstWorkout();
  }
  return skipped;
}
