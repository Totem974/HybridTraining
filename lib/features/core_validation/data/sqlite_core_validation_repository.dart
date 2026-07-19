import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/generate_beginner_plan.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_versioned_plan_store.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/domain/core_validation_snapshot.dart';
import 'package:hybrid_training/features/import_export/data/sqlite_backup_manager.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
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
    final completed =
        Sqflite.firstIntValue(
          await database.rawQuery(
            "SELECT COUNT(*) FROM plan_training_sessions WHERE status = 'completed'",
          ),
        ) ??
        0;
    Future<int> countResult(String result) async =>
        Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT COUNT(*) FROM set_performances WHERE result = ?',
            [result],
          ),
        ) ??
        0;
    final tonnageRows = await database.rawQuery(
      '''SELECT SUM(actual_load * completed_reps) AS tonnage
         FROM set_performances
         WHERE actual_load IS NOT NULL AND result = 'success' ''',
    );
    final tonnage = tonnageRows.single['tonnage'] as num?;
    return CoreValidationSnapshot(
      profileName: profiles.isEmpty
          ? null
          : profiles.single['display_name']! as String,
      unit: profiles.isEmpty
          ? null
          : profiles.single['preferred_unit']! as String,
      activePlans: plans,
      plannedSessions: planned,
      completedSessions: completed,
      successfulSets: await countResult('success'),
      failedSets: await countResult('failure'),
      skippedSets: await countResult('skipped'),
      actualTonnage: tonnage?.toDouble(),
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
