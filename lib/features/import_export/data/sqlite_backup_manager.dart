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
    'app_metadata',
    'import_runs',
  ];

  Future<String> exportBackup({required String appVersion}) async {
    final database = await localDatabase.open();
    final payload = <String, Object?>{};
    for (final table in _insertOrder) {
      payload[table] = await database.query(table);
    }
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
