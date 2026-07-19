import 'dart:io';

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
    'tonnage uses actual successful load and never prescribed load',
    () async {
      await repository.createDevelopmentFixture();
      final database = await local.open();
      final prescription = (await database.query(
        'set_prescriptions',
        limit: 1,
      )).single;
      expect((await repository.load()).actualTonnage, isNull);

      await database.insert('set_performances', {
        'id': 'performance-1',
        'prescription_id': prescription['id'],
        'result': 'success',
        'completed_reps': 6,
        'actual_load': 42.5,
        'notes': '',
        'recorded_at': DateTime.utc(2026, 7, 20).toIso8601String(),
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
      expect((await repository.loadFirstWorkout())?.completedSets, 0);
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
      final totalSets = workout!.totalSets;
      while (workout!.completedSets < workout.totalSets) {
        await repository.recordCurrentSet(status: SetOutcomeStatus.skipped);
        workout = await repository.loadFirstWorkout();
      }
      expect(workout.canComplete, isTrue);
      await repository.completeWorkout();

      final snapshot = await repository.load();
      expect(snapshot.completedSessions, 1);
      expect(snapshot.successfulSets, 1);
      expect(snapshot.skippedSets, totalSets - 1);
      expect(snapshot.actualTonnage, 255);
      final database = await local.open();
      expect(
        (await database.query('workout_executions', limit: 1)).single['state'],
        'completed',
      );
    },
  );
}
