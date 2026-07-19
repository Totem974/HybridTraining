import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/generate_beginner_plan.dart';
import 'package:hybrid_training/features/active_program/application/program_switch.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_versioned_plan_store.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/domain/core_validation_snapshot.dart';
import 'package:hybrid_training/features/core_validation/domain/core_workout_snapshot.dart';
import 'package:hybrid_training/features/import_export/data/sqlite_backup_manager.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:hybrid_training/features/tracking/data/sqlite_training_statistics_repository.dart';
import 'package:hybrid_training/features/workout_runtime/data/sqlite_workout_execution_repository.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';
import 'package:sqflite/sqflite.dart';

class SqliteCoreValidationRepository implements CoreValidationRepository {
  SqliteCoreValidationRepository({
    required this.localDatabase,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalDatabase localDatabase;
  final DateTime Function() _clock;

  static const _athleteId = 'dev-core-athlete';
  static const _planId = 'dev-bps-plan-1';

  SqliteWorkoutExecutionRepository get _workouts =>
      SqliteWorkoutExecutionRepository(localDatabase: localDatabase);

  @override
  Future<CoreValidationSnapshot> load() async {
    final database = await localDatabase.open();
    final profiles = await database.query(
      'athlete_profiles',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at',
      limit: 1,
    );
    final plans =
        Sqflite.firstIntValue(
          await database.rawQuery(
            "SELECT COUNT(*) FROM training_plans WHERE status = 'active'",
          ),
        ) ??
        0;
    final planned =
        Sqflite.firstIntValue(
          await database.rawQuery(
            "SELECT COUNT(*) FROM plan_training_sessions WHERE status = 'planned'",
          ),
        ) ??
        0;
    final statistics = await SqliteTrainingStatisticsRepository(
      localDatabase: localDatabase,
    ).load();
    return CoreValidationSnapshot(
      profileName: profiles.isEmpty
          ? null
          : profiles.single['display_name']! as String,
      unit: profiles.isEmpty
          ? null
          : profiles.single['preferred_unit']! as String,
      activePlans: plans,
      plannedSessions: planned,
      completedSessions: statistics.completedSessions,
      successfulSets: statistics.successfulSets,
      failedSets: statistics.failedSets,
      skippedSets: statistics.skippedSets,
      actualTonnage: statistics.actualTonnage,
    );
  }

  @override
  Future<void> createDevelopmentFixture() async {
    final database = await localDatabase.open();
    final existing = await database.query(
      'athlete_profiles',
      where: 'id = ?',
      whereArgs: [_athleteId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = _clock().toUtc();
    const maxes = {
      MainLift.squat: 100.0,
      MainLift.benchPress: 70.0,
      MainLift.deadlift: 120.0,
      MainLift.overheadPress: 45.0,
    };
    await database.transaction((tx) async {
      await tx.insert('athlete_profiles', {
        'id': _athleteId,
        'display_name': 'Athlete DEV',
        'preferred_unit': 'kg',
        'rounding_increment': 2.5,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      for (final lift in MainLift.values) {
        await tx.insert('exercises', {
          'id': lift.name,
          'name_key': 'exercise.${lift.name}',
          'category': 'mainLift',
          'is_main_lift': 1,
          'created_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await tx.insert('training_max_history', {
          'id': 'dev-tm-${lift.name}-1',
          'athlete_id': _athleteId,
          'exercise_id': lift.name,
          'one_rep_max': maxes[lift]! / .85,
          'training_max': maxes[lift],
          'unit': 'kg',
          'effective_at': now.toIso8601String(),
        });
      }
    });
    final planStore = SqliteVersionedPlanStore(localDatabase: localDatabase);
    await GenerateBeginnerPlan(repository: planStore, clock: _clock)(
      GenerateBeginnerPlanRequest(
        planId: _planId,
        athleteId: _athleteId,
        trainingMaxes: maxes,
        trainingMaxRatios: {for (final lift in MainLift.values) lift: .85},
        unit: WeightUnit.kilograms,
        trainingWeekdays: const [1, 3, 5],
        startDate: LocalDate.fromDateTime(now),
        roundingIncrement: 2.5,
        seed: 531,
      ),
    );
  }

  @override
  Future<CoreWorkoutSnapshot?> loadFirstWorkout() async {
    final database = await localDatabase.open();
    final session = await _firstOpenSession(database);
    if (session == null) return null;
    final execution = await _workouts.loadInTransaction(
      database,
      session['id']! as String,
    );
    return _workoutSnapshot(database, session, execution);
  }

  @override
  Future<void> startFirstWorkout() => _mutateWorkout(
    eventType: 'started',
    action: (current, at) => current.start(at),
    updateSession: (tx, sessionId, next, at) => tx.update(
      'plan_training_sessions',
      {'status': 'started', 'started_at': at.toIso8601String()},
      where: "id = ? AND status = 'planned'",
      whereArgs: [sessionId],
    ),
  );

  @override
  Future<void> recordCurrentSet({
    required SetOutcomeStatus status,
    int? actualRepetitions,
    double? actualLoad,
    double? rpe,
    String notes = '',
  }) => _mutateWorkout(
    eventType: 'setRecorded',
    payload: {
      'status': status.name,
      'actualRepetitions': actualRepetitions,
      'actualLoad': actualLoad,
      'rpe': rpe,
    },
    action: (current, at) => current.recordActiveSet(
      status: status,
      at: at,
      actualRepetitions: actualRepetitions,
      actualLoad: actualLoad,
      rpe: rpe,
      notes: notes,
    ),
  );

  @override
  Future<void> pauseOrResumeWorkout() => _mutateWorkout(
    eventType: 'pauseOrResume',
    action: (current, at) => current.state == WorkoutExecutionState.paused
        ? current.resume(at)
        : current.pause(at),
  );

  @override
  Future<void> undoLastSet() => _mutateWorkout(
    eventType: 'lastSetUndone',
    action: (current, at) => current.undoLastOutcome(at),
  );

  @override
  Future<void> beginOrEndRest({required Duration duration}) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration');
    }
    return _mutateWorkout(
      eventType: 'restToggled',
      payload: {'durationSeconds': duration.inSeconds},
      action: (current, at) => current.state == WorkoutExecutionState.resting
          ? current.endRest(at)
          : current.beginRest(at.add(duration), at),
    );
  }

  @override
  Future<void> completeWorkout() => _mutateWorkout(
    eventType: 'completed',
    action: (current, at) => current.complete(at),
    updateSession: (tx, sessionId, next, at) => tx.update(
      'plan_training_sessions',
      {'status': 'complete', 'completed_at': at.toIso8601String()},
      where: "id = ? AND status = 'started'",
      whereArgs: [sessionId],
    ),
  );

  @override
  Future<void> abandonWorkout() => _mutateWorkout(
    eventType: 'abandoned',
    action: (current, at) => current.abandon(at),
    updateSession: (tx, sessionId, next, at) => tx.update(
      'plan_training_sessions',
      {'status': 'cancelled', 'completed_at': at.toIso8601String()},
      where: "id = ? AND status = 'started'",
      whereArgs: [sessionId],
    ),
  );

  @override
  Future<void> skipWorkout() => _mutateWorkout(
    eventType: 'skipped',
    action: (current, at) => current.skip(at),
    updateSession: (tx, sessionId, next, at) => tx.update(
      'plan_training_sessions',
      {'status': 'cancelled', 'completed_at': at.toIso8601String()},
      where: "id = ? AND status = 'planned'",
      whereArgs: [sessionId],
    ),
  );

  @override
  Future<void> rescheduleWorkout(DateTime date) async {
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final session = await _firstOpenSession(tx);
      if (session == null || session['status'] != 'planned') {
        throw StateError('Only a planned workout can be rescheduled.');
      }
      final value = date.toIso8601String().substring(0, 10);
      final updated = await tx.update(
        'plan_training_sessions',
        {'scheduled_for': value},
        where: "id = ? AND status = 'planned'",
        whereArgs: [session['id']],
      );
      if (updated != 1) throw StateError('The planned workout changed.');
    });
  }

  @override
  Future<ProgramSwitchPreview> previewProgramSwitch(DateTime startDate) async {
    final request = await _programSwitchRequest(startDate);
    return SqliteVersionedPlanStore(
      localDatabase: localDatabase,
    ).previewProgramSwitch(request);
  }

  @override
  Future<void> applyProgramSwitch(
    DateTime startDate, {
    required bool abandonActiveSession,
  }) async {
    final request = await _programSwitchRequest(
      startDate,
      abandonActiveSession: abandonActiveSession,
    );
    await SqliteVersionedPlanStore(
      localDatabase: localDatabase,
    ).applyProgramSwitch(request);
  }

  Future<ProgramSwitchRequest> _programSwitchRequest(
    DateTime startDate, {
    bool abandonActiveSession = false,
  }) async {
    final database = await localDatabase.open();
    final rows = await database.rawQuery('''
      SELECT p.id, p.athlete_id, s.snapshot_json, a.preferred_unit,
             a.rounding_increment
      FROM training_plans p
      JOIN program_definition_snapshots s ON s.id = p.definition_snapshot_id
      JOIN athlete_profiles a ON a.id = p.athlete_id
      WHERE p.status = 'active' AND a.deleted_at IS NULL LIMIT 1
    ''');
    if (rows.isEmpty) throw StateError('No active plan is available.');
    final row = rows.single;
    final snapshot = jsonDecode(row['snapshot_json']! as String);
    if (snapshot is! Map<String, Object?> ||
        snapshot['trainingMaxRatios'] is! Map<String, Object?>) {
      throw StateError('The active plan snapshot has no TM ratios.');
    }
    final ratioJson = snapshot['trainingMaxRatios']! as Map<String, Object?>;
    final ratios = <MainLift, double>{};
    final maxes = <MainLift, double>{};
    for (final lift in MainLift.values) {
      final movementId = _movementId(lift);
      ratios[lift] =
          ((ratioJson[movementId.value] ?? ratioJson[lift.name])! as num)
              .toDouble();
      final history = await database.query(
        'training_max_history',
        columns: ['training_max'],
        where: 'athlete_id = ? AND exercise_id = ?',
        whereArgs: [row['athlete_id'], lift.name],
        orderBy: 'effective_at DESC',
        limit: 1,
      );
      if (history.isEmpty) throw StateError('Missing TM for ${lift.name}.');
      maxes[lift] = (history.single['training_max']! as num).toDouble();
    }
    final unit = switch (row['preferred_unit']) {
      'kg' => WeightUnit.kilograms,
      'lb' => WeightUnit.pounds,
      _ => throw StateError('Unsupported athlete unit.'),
    };
    final movements = MainLift.values.map(_movementId).toList();
    final generated = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.beginnerPrepSchool,
      athlete: CanonicalAthleteConfiguration(
        movementOrder: movements,
        trainingMaxes: {
          for (final lift in MainLift.values) _movementId(lift): maxes[lift]!,
        },
        progressionIncrements: {for (final movement in movements) movement: 1},
        trainingMaxRatios: {
          for (final lift in MainLift.values) _movementId(lift): ratios[lift]!,
        },
        unit: unit,
        trainingWeekdays: const [1, 3, 5],
        startDate: LocalDate.fromDateTime(startDate),
        rounder: LoadRounder(
          increment: (row['rounding_increment']! as num).toDouble(),
        ),
      ),
    );
    final dateId = startDate.toIso8601String().substring(0, 10);
    final next = VersionedTrainingPlan.fromCanonical(
      id: 'preview-bps-$dateId',
      athleteId: row['athlete_id']! as String,
      macrocycle: 1,
      createdAt: _clock().toUtc(),
      generated: generated,
    );
    return ProgramSwitchRequest(
      currentPlanId: row['id']! as String,
      nextPlan: next,
      reason: 'Program switch confirmed by the local athlete',
      activeSessionDisposition: abandonActiveSession
          ? ActiveSessionDisposition.abandon
          : ActiveSessionDisposition.reject,
    );
  }

  Future<void> _mutateWorkout({
    required String eventType,
    Map<String, Object?> payload = const {},
    required WorkoutExecution Function(WorkoutExecution, DateTime) action,
    Future<int> Function(DatabaseExecutor, String, WorkoutExecution, DateTime)?
    updateSession,
  }) async {
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final session = await _firstOpenSession(tx);
      if (session == null) throw StateError('No open workout is available.');
      final sessionId = session['id']! as String;
      var current = await _workouts.createInTransaction(tx, sessionId);
      final at = _clock().toUtc();
      final next = await _workouts.mutateInTransaction(
        tx,
        sessionId,
        eventType: eventType,
        payload: payload,
        action: (value) => action(value, at),
      );
      current = next;
      if (updateSession != null) {
        final updated = await updateSession(tx, sessionId, current, at);
        if (updated != 1) {
          throw StateError('The planned session changed concurrently.');
        }
      }
    });
  }

  Future<Map<String, Object?>?> _firstOpenSession(
    DatabaseExecutor database,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT s.* FROM plan_training_sessions s
         JOIN plan_training_cycles c ON c.id = s.cycle_id
         JOIN training_blocks b ON b.id = c.block_id
         JOIN training_plans p ON p.id = b.plan_id
         WHERE p.status = 'active' AND s.status IN ('planned','started')
         ORDER BY s.scheduled_for, b.sequence, c.sequence, s.sequence LIMIT 1''',
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<CoreWorkoutSnapshot> _workoutSnapshot(
    DatabaseExecutor database,
    Map<String, Object?> session,
    WorkoutExecution? execution,
  ) async {
    final sessionId = session['id']! as String;
    final prescriptions = await database.rawQuery(
      '''SELECT sp.id, sp.prescribed_reps, sp.prescribed_load,
                NULL AS target_json, NULL AS calculated_load,
                sb.sequence AS block_sequence, sp.sequence AS item_sequence,
                'loadedSet' AS item_kind
         FROM set_prescriptions sp
         JOIN session_blocks sb ON sb.id = sp.session_block_id
         WHERE sb.session_id = ?
         UNION ALL
         SELECT ap.id, NULL AS prescribed_reps, NULL AS prescribed_load,
                ap.target_json, ap.calculated_load,
                sb.sequence AS block_sequence, ap.sequence AS item_sequence,
                CASE WHEN ap.target_type = 'setsRepsLoad'
                     THEN 'loadedSet' ELSE 'activity' END AS item_kind
         FROM activity_prescriptions ap
         JOIN session_blocks sb ON sb.id = ap.session_block_id
         WHERE sb.session_id = ?
         ORDER BY block_sequence, item_sequence, item_kind''',
      [sessionId, sessionId],
    );
    if (prescriptions.isEmpty) {
      throw StateError('The planned workout has no executable prescription.');
    }
    final index = execution?.activeSetIndex ?? 0;
    final prescription = prescriptions[index];
    final target = prescription['target_json'] == null
        ? const <String, Object?>{}
        : jsonDecode(prescription['target_json']! as String)
              as Map<String, Object?>;
    return CoreWorkoutSnapshot(
      sessionId: sessionId,
      scheduledFor: session['scheduled_for']! as String,
      state: execution?.state ?? WorkoutExecutionState.planned,
      currentSetNumber: index + 1,
      totalSets: prescriptions.length,
      prescriptionId: prescription['id']! as String,
      prescribedRepetitions:
          (prescription['prescribed_reps'] as int?) ??
          (target['repetitionsPerSet'] as num?)?.toInt() ??
          0,
      prescribedLoad:
          ((prescription['prescribed_load'] ?? prescription['calculated_load'])
                  as num?)
              ?.toDouble() ??
          0,
      completedSets:
          execution?.sets.where((outcome) => !outcome.isPending).length ?? 0,
      restUntil: execution?.restUntil,
      itemKind: ExecutionItemKind.values.byName(
        prescription['item_kind']! as String,
      ),
    );
  }

  @override
  Future<String> exportBackup() => SqliteBackupManager(
    localDatabase: localDatabase,
    clock: _clock,
  ).exportBackup(appVersion: 'core-validation');

  @override
  Future<ImportReport> importBackup(String source, {required bool dryRun}) =>
      SqliteBackupManager(
        localDatabase: localDatabase,
        clock: _clock,
      ).importBackup(source, dryRun: dryRun);

  @override
  Future<void> deleteAllData() =>
      SqliteBackupManager(localDatabase: localDatabase).deleteAllData();
}

MovementId _movementId(MainLift lift) => switch (lift) {
  MainLift.squat => MovementId.squat,
  MainLift.benchPress => MovementId.benchPress,
  MainLift.deadlift => MovementId.deadlift,
  MainLift.overheadPress => MovementId.overheadPress,
};
