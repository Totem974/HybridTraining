import 'dart:io';
import 'dart:convert';

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
      var current = await runtime.loadFirstWorkout();
      while (current!.itemKind == ExecutionItemKind.activity) {
        await runtime.recordCurrentSet(status: SetOutcomeStatus.skipped);
        current = await runtime.loadFirstWorkout();
      }
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
      expect(all.skippedSets, 14);
      expect(all.successfulSets + all.failedSets + all.skippedSets, 16);
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

  test(
    'aggregates generic repetitions, duration, distance and rounds',
    () async {
      final database = await local.open();
      final existingBlock = (await database.query(
        'session_blocks',
        orderBy: 'sequence',
        limit: 1,
      )).single;
      const sessionBlock = 'statistics-activity-block';
      await database.insert('session_blocks', {
        'id': sessionBlock,
        'session_id': existingBlock['session_id'],
        'sequence': 99,
        'kind': 'assistance',
        'rule_provenance_json': '{}',
      });
      for (final entry in const [
        ('reps', 'totalRepetitions', {'totalRepetitions': 40}),
        ('duration', 'duration', {'durationSeconds': 900}),
        ('distance', 'distance', {'distanceMeters': 1609.344}),
        ('rounds', 'rounds', {'rounds': 5}),
      ].indexed) {
        await database.insert('activity_prescriptions', {
          'id': entry.$2.$1,
          'session_block_id': sessionBlock,
          'sequence': entry.$1,
          'movement_or_activity_id': entry.$2.$1,
          'target_type': entry.$2.$2,
          'target_json': '{}',
          'prescription_kind': 'assistance',
          'rule_id': 'STAT-${entry.$1}',
          'source_edition': 'forever',
          'ruleset_generation': 'forever',
          'source_reference_json': '{}',
        });
        await database.insert('activity_results', {
          'prescription_id': entry.$2.$1,
          'status': entry.$1 == 3 ? 'failure' : 'success',
          'actual_json': jsonEncode(entry.$2.$3),
          'notes': '',
          'recorded_at': '2026-07-20T10:00:00.000Z',
          'updated_at': '2026-07-20T10:00:00.000Z',
        });
      }

      final result = await statistics.load();
      expect(result.actualRepetitions, 40);
      expect(result.actualDurationSeconds, 900);
      expect(result.actualDistanceMeters, 1609.344);
      expect(result.actualRounds, 5);
      expect(result.successfulActivities, 3);
      expect(result.failedActivities, 1);
      expect(result.activitySuccessRate, .75);
    },
  );
}
