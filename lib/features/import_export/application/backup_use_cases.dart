import '../data/sqlite_backup_manager.dart';
import '../domain/import_models.dart';

class ExportBackup {
  const ExportBackup(this.manager);
  final SqliteBackupManager manager;

  Future<String> call({required String appVersion}) =>
      manager.exportBackup(appVersion: appVersion);
}

class SimulateImport {
  const SimulateImport(this.manager);
  final SqliteBackupManager manager;

  Future<ImportReport> call(String source) =>
      manager.importBackup(source, dryRun: true);
}

class ApplyImport {
  const ApplyImport(this.manager);
  final SqliteBackupManager manager;

  Future<ImportReport> call(String source) =>
      manager.importBackup(source, dryRun: false);
}
