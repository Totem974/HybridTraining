import '../domain/core_validation_snapshot.dart';
import '../../import_export/domain/import_models.dart';

abstract interface class CoreValidationRepository {
  Future<CoreValidationSnapshot> load();

  Future<void> createDevelopmentFixture();

  Future<String> exportBackup();

  Future<ImportReport> importBackup(String source, {required bool dryRun});

  Future<void> deleteAllData();
}
