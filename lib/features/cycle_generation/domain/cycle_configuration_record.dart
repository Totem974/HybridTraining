final class CycleConfigurationRecord {
  const CycleConfigurationRecord({
    required this.id,
    required this.profileId,
    required this.name,
    required this.formatVersion,
    required this.catalogVersion,
    required this.catalogHash,
    required this.configurationJson,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  final String id;
  final String? profileId;
  final String name;
  final int formatVersion;
  final int catalogVersion;
  final String catalogHash;
  final String configurationJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}
