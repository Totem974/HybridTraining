import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/tracking/application/training_statistics_repository.dart';
import 'package:hybrid_training/features/tracking/domain/training_statistics.dart';
import 'package:hybrid_training/features/training_max/domain/max_calculator.dart';

class SqliteTrainingStatisticsRepository
    implements TrainingStatisticsRepository {
  const SqliteTrainingStatisticsRepository({required this.localDatabase});

  final LocalDatabase localDatabase;

  @override
  Future<TrainingStatistics> load({
    StatisticsScope scope = const StatisticsScope(),
  }) async {
    final database = await localDatabase.open();
    final sessionRows = await database.rawQuery('''
      SELECT s.id, s.scheduled_for, s.status, e.state AS execution_state,
             c.id AS cycle_id, b.id AS block_id, p.id AS plan_id
      FROM plan_training_sessions s
      JOIN plan_training_cycles c ON c.id = s.cycle_id
      JOIN training_blocks b ON b.id = c.block_id
      JOIN training_plans p ON p.id = b.plan_id
      LEFT JOIN workout_executions e ON e.session_id = s.id
    ''');
    final sessions = sessionRows.where((row) => _inScope(row, scope)).toList();
    final setRows = await database.rawQuery('''
      SELECT o.status AS result, o.actual_repetitions, o.actual_load,
             sp.prescribed_reps, sp.prescribed_load, sb.movement_id,
             s.id AS session_id, s.scheduled_for,
             c.id AS cycle_id, b.id AS block_id, p.id AS plan_id
      FROM workout_set_outcomes o
      JOIN set_prescriptions sp ON sp.id = o.prescription_id
      JOIN session_blocks sb ON sb.id = sp.session_block_id
      JOIN plan_training_sessions s ON s.id = sb.session_id
      JOIN plan_training_cycles c ON c.id = s.cycle_id
      JOIN training_blocks b ON b.id = c.block_id
      JOIN training_plans p ON p.id = b.plan_id
      WHERE o.status != 'pending'
      UNION ALL
      SELECT f.result, f.completed_reps, f.actual_load,
             sp.prescribed_reps, sp.prescribed_load, sb.movement_id,
             s.id, s.scheduled_for, c.id, b.id, p.id
      FROM set_performances f
      JOIN set_prescriptions sp ON sp.id = f.prescription_id
      JOIN session_blocks sb ON sb.id = sp.session_block_id
      JOIN plan_training_sessions s ON s.id = sb.session_id
      JOIN plan_training_cycles c ON c.id = s.cycle_id
      JOIN training_blocks b ON b.id = c.block_id
      JOIN training_plans p ON p.id = b.plan_id
      WHERE NOT EXISTS (
        SELECT 1 FROM workout_set_outcomes o
        WHERE o.prescription_id = f.prescription_id AND o.status != 'pending'
      )
    ''');
    final sets = setRows.where((row) => _inScope(row, scope)).toList();
    final activityRows = await database.rawQuery('''
      SELECT r.status, r.actual_json,
             s.id AS session_id, s.scheduled_for,
             c.id AS cycle_id, b.id AS block_id, p.id AS plan_id
      FROM activity_results r
      JOIN activity_prescriptions ap ON ap.id = r.prescription_id
      JOIN session_blocks sb ON sb.id = ap.session_block_id
      JOIN plan_training_sessions s ON s.id = sb.session_id
      JOIN plan_training_cycles c ON c.id = s.cycle_id
      JOIN training_blocks b ON b.id = c.block_id
      JOIN training_plans p ON p.id = b.plan_id
      WHERE r.status != 'pending'
    ''');
    final activities = activityRows
        .where((row) => _inScope(row, scope))
        .map(
          (row) => (
            row: row,
            actual:
                jsonDecode(row['actual_json']! as String)
                    as Map<String, Object?>,
          ),
        )
        .toList();
    final failedSessionIds = <String>{};
    for (final row in sets.where((row) => row['result'] == 'failure')) {
      failedSessionIds.add(row['session_id']! as String);
    }
    final movements = <String, List<Map<String, Object?>>>{};
    for (final row in sets) {
      final movement = row['movement_id'] as String?;
      if (movement != null) movements.putIfAbsent(movement, () => []).add(row);
    }
    final tmRows = await database.rawQuery('''
      SELECT h.exercise_id, h.training_max, h.effective_at
      FROM training_max_history h ORDER BY h.effective_at
    ''');
    final recordRows = await database.query('personal_records');
    final movementStats = <MovementStatistics>[];
    final allMovementIds = {
      ...movements.keys,
      ...tmRows.map((row) => row['exercise_id']! as String),
      ...recordRows.map((row) => row['lift_id']! as String),
    }.toList()..sort();
    const maxCalculator = MaxCalculator();
    for (final movement in allMovementIds) {
      final rows = movements[movement] ?? const [];
      final actualRows = rows.where((row) => row['actual_repetitions'] != null);
      final tonnageRows = actualRows.where((row) => row['actual_load'] != null);
      final estimates = tonnageRows
          .where((row) => (row['actual_repetitions']! as int) > 0)
          .map(
            (row) => maxCalculator.estimateOneRepMax(
              load: (row['actual_load']! as num).toDouble(),
              repetitions: row['actual_repetitions']! as int,
            ),
          )
          .toList();
      final movementTm = tmRows
          .where((row) => row['exercise_id'] == movement)
          .toList();
      movementStats.add(
        MovementStatistics(
          movementId: movement,
          actualRepetitions: actualRows.fold(
            0,
            (sum, row) => sum + (row['actual_repetitions']! as int),
          ),
          actualTonnage: tonnageRows.isEmpty
              ? null
              : tonnageRows.fold<double>(
                  0.0,
                  (sum, row) =>
                      sum +
                      (row['actual_load']! as num).toDouble() *
                          (row['actual_repetitions']! as int),
                ),
          bestEstimatedOneRepMax: estimates.isEmpty
              ? null
              : estimates.reduce((a, b) => a > b ? a : b),
          currentTrainingMax: movementTm.isEmpty
              ? null
              : (movementTm.last['training_max']! as num).toDouble(),
          trainingMaxChanges: movementTm.length,
          personalRecordCount: recordRows
              .where((row) => row['lift_id'] == movement)
              .length,
        ),
      );
    }
    final tonnageRows = sets.where(
      (row) => row['actual_load'] != null && row['actual_repetitions'] != null,
    );
    return TrainingStatistics(
      completedSessions: sessions
          .where((row) => _state(row) == 'completed')
          .length,
      failedSessions: failedSessionIds.length,
      skippedSessions: sessions.where((row) => _state(row) == 'skipped').length,
      abandonedSessions: sessions
          .where((row) => _state(row) == 'abandoned')
          .length,
      successfulSets: sets.where((row) => row['result'] == 'success').length,
      failedSets: sets.where((row) => row['result'] == 'failure').length,
      skippedSets: sets.where((row) => row['result'] == 'skipped').length,
      actualRepetitions:
          sets.fold(
            0,
            (sum, row) => sum + ((row['actual_repetitions'] as int?) ?? 0),
          ) +
          activities.fold(
            0,
            (sum, item) =>
                sum +
                ((item.actual['totalRepetitions'] as num?)?.toInt() ?? 0) +
                ((item.actual['repetitions'] as num?)?.toInt() ?? 0),
          ),
      actualTonnage: tonnageRows.isEmpty
          ? null
          : tonnageRows.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  (row['actual_load']! as num).toDouble() *
                      (row['actual_repetitions']! as int),
            ),
      prescribedTonnageForRecordedSets: sets.fold(
        0.0,
        (sum, row) =>
            sum +
            (row['prescribed_load']! as num).toDouble() *
                (row['prescribed_reps']! as int),
      ),
      movements: List.unmodifiable(movementStats),
      successfulActivities: activities
          .where((item) => item.row['status'] == 'success')
          .length,
      failedActivities: activities
          .where((item) => item.row['status'] == 'failure')
          .length,
      skippedActivities: activities
          .where((item) => item.row['status'] == 'skipped')
          .length,
      actualDistanceMeters: activities.fold(
        0,
        (sum, item) =>
            sum + ((item.actual['distanceMeters'] as num?)?.toDouble() ?? 0),
      ),
      actualDurationSeconds: activities.fold(
        0,
        (sum, item) =>
            sum + ((item.actual['durationSeconds'] as num?)?.toInt() ?? 0),
      ),
      actualRounds: activities.fold(
        0,
        (sum, item) => sum + ((item.actual['rounds'] as num?)?.toInt() ?? 0),
      ),
    );
  }

  bool _inScope(Map<String, Object?> row, StatisticsScope scope) {
    if (scope.planId != null && row['plan_id'] != scope.planId) return false;
    if (scope.blockId != null && row['block_id'] != scope.blockId) return false;
    if (scope.cycleId != null && row['cycle_id'] != scope.cycleId) return false;
    return scope.includesDate(DateTime.parse(row['scheduled_for']! as String));
  }

  String _state(Map<String, Object?> row) {
    final execution = row['execution_state'] as String?;
    if (execution != null) return execution;
    return switch (row['status']) {
      'complete' => 'completed',
      'cancelled' => 'abandoned',
      final value => value! as String,
    };
  }
}
