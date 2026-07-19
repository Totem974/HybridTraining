import '../domain/core_validation_snapshot.dart';

abstract interface class CoreValidationRepository {
  Future<CoreValidationSnapshot> load();

  Future<void> createDevelopmentFixture();

  Future<String> exportBackup();

  Future<void> deleteAllData();
}
