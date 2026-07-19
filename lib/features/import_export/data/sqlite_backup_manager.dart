import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/import_export/data/hybrid_backup_handler.dart';
import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_pipeline.dart';
import 'package:sqflite/sqflite.dart';

class SqliteBackupManager implements AtomicImportTarget {
  SqliteBackupManager({required this.localDatabase, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalDatabase localDatabase;
  final DateTime Function() _clock;

  static const _insertOrder = HybridBackupHandler.tables;
  static const _deleteOrder = [
    'workout_execution_events',
    'workout_set_outcomes',
    'workout_executions',
    'workout_activities',
    'workout_runtime_blocks',
    'workout_runtime_sessions',
    'plan_events',
    'set_performances',
    'set_prescriptions',
    'session_blocks',
    'plan_training_sessions',
    'plan_training_cycles',
    'training_blocks',
    'training_plans',
    'program_definition_snapshots',
    'personal_records',
    'training_sets',
    'training_sessions',
    'training_cycles',
    'gym_plates',
    'gym_bars',
    'gyms',
    'training_max_history',
    'athlete_profiles',
    'program_definitions',
    'exercises',
    'import_runs',
    'app_metadata',
  ];

  Future<String> exportBackup({required String appVersion}) async {
    final database = await localDatabase.open();
    final payload = await database.transaction((transaction) async {
      final snapshot = <String, Object?>{};
      for (final table in _insertOrder) {
        snapshot[table] = await transaction.query(table);
      }
      return snapshot;
    });
    return BackupEnvelope(
      exportedAt: _clock().toUtc(),
      appVersion: appVersion,
      payload: payload,
    ).encode();
  }

  Future<ImportReport> importBackup(String source, {required bool dryRun}) =>
      ImportPipeline(
        handlers: const [HybridBackupHandler()],
        target: this,
      ).run(source, dryRun: dryRun);

  @override
  Future<void> applyAtomically(ImportCandidate candidate) async {
    final database = await localDatabase.open();
    await database.transaction((transaction) async {
      await _deleteAll(transaction);
      for (final table in _insertOrder) {
        final rows = candidate.payload[table]! as List<Object?>;
        for (final row in rows.cast<Map<String, Object?>>()) {
          await transaction.insert(table, row);
        }
      }
    });
  }

  Future<void> deleteAllData() async {
    final database = await localDatabase.open();
    await database.transaction(_deleteAll);
  }

  Future<void> _deleteAll(DatabaseExecutor transaction) async {
    for (final table in _deleteOrder) {
      await transaction.delete(table);
    }
  }
}
