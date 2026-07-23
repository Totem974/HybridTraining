import '../domain/cycle_configuration_record.dart';

abstract interface class CycleConfigurationRepository {
  Future<void> create(CycleConfigurationRecord configuration);

  Future<void> update(CycleConfigurationRecord configuration);

  Future<CycleConfigurationRecord?> find(String id);

  Future<List<CycleConfigurationRecord>> list({
    String? profileId,
    bool includeArchived = false,
  });

  Future<void> archive(String id, DateTime archivedAt);
}
