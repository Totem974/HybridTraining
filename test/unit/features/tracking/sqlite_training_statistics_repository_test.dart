import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:hybrid_training/features/tracking/data/sqlite_training_statistics_repository.dart';
import 'package:hybrid_training/features/tracking/domain/training_statistics.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteCoreValidationRepository runtime;
  late SqliteTrainingStatisticsRepository statistics;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('training-statistics-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/statistics.db',
    );
    runtime = SqliteCoreValidationRepository(
      localDatabase: local,
      clock: () => DateTime.utc(2026, 7, 20, 10),
    );
    statistics = SqliteTrainingStatisticsRepository(localDatabase: local);
    await runtime.createDevelopmentFixture();
  });

  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test(
    'separates actual and prescribed work and aggregates by scope',
    () async {
      await runtime.startFirstWorkout();
      await runtime.recordCurrentSet(
        status: SetOutcomeStatus.success,
        actualRepetitions: 6,
        actualLoad: 42.5,
      );
      await runtime.recordCurrentSet(
        status: SetOutcomeStatus.failure,
        actualRepetitions: 3,
        actualLoad: 50,
      );
      var workout = await runtime.loadFirstWorkout();
      while (workout!.completedSets < workout.totalSets) {
        await runtime.recordCurrentSet(status: SetOutcomeStatus.skipped);
        workout = await runtime.loadFirstWorkout();
      }
      await runtime.completeWorkout();

      final all = await statistics.load();
      expect(all.completedSessions, 1);
      expect(all.failedSessions, 1);
      expect(all.successfulSets, 1);
      expect(all.failedSets, 1);
      expect(all.skippedSets, workout.totalSets - 2);
      expect(all.actualRepetitions, 9);
      expect(all.actualTonnage, 405);
      expect(all.prescribedTonnageForRecordedSets, isNot(all.actualTonnage));
      final squat = all.movements.firstWhere(
        (movement) => movement.movementId == 'squat',
      );
      expect(squat.bestEstimatedOneRepMax, closeTo(55, .001));
      expect(squat.currentTrainingMax, 100);
      expect(squat.trainingMaxChanges, 1);

      final july = await statistics.load(
        scope: StatisticsScope(
          from: DateTime.utc(2026, 7, 1),
          until: DateTime.utc(2026, 8, 1),
          planId: 'dev-bps-plan-1',
        ),
      );
      expect(july.actualTonnage, 405);
      final outside = await statistics.load(
        scope: StatisticsScope(from: DateTime.utc(2026, 8, 1)),
      );
      expect(outside.actualTonnage, isNull);
      expect(outside.completedSessions, 0);
    },
  );

  test('reports unavailable actual work for prescriptions only', () async {
    final result = await statistics.load();
    expect(result.actualTonnage, isNull);
    expect(result.actualRepetitions, 0);
    expect(result.prescribedTonnageForRecordedSets, 0);
  });
}
