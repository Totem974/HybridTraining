import '../../cycle_generation/domain/cycle_contract.dart';

final class CatalogFormatException implements Exception {
  const CatalogFormatException(this.message);
  final String message;
  @override
  String toString() => 'CatalogFormatException: $message';
}

final class CatalogNotFoundException implements Exception {
  const CatalogNotFoundException(this.message);
  final String message;
  @override
  String toString() => 'CatalogNotFoundException: $message';
}

final class CatalogNotPublishedException implements Exception {
  const CatalogNotPublishedException(this.version);
  final int version;
  @override
  String toString() => 'Catalog version $version is not published';
}

final class CatalogVersionImmutableException implements Exception {
  const CatalogVersionImmutableException(this.version);
  final int version;
  @override
  String toString() => 'Published catalog version $version is immutable';
}

final class CatalogSeed {
  const CatalogSeed({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.status,
    required this.sourceReference,
    required this.movements,
    required this.templates,
  });

  final int schemaVersion;
  final int catalogVersion;
  final String status;
  final String sourceReference;
  final List<CatalogMovement> movements;
  final List<CatalogTemplate> templates;
}

final class CatalogMovement {
  const CatalogMovement({required this.id, required this.name});
  final String id;
  final String name;
}

final class CatalogTemplate {
  const CatalogTemplate({
    required this.id,
    required this.name,
    required this.variants,
  });
  final String id;
  final String name;
  final List<CatalogVariant> variants;
}

final class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.name,
    required this.sessionMovementIds,
    required this.weeks,
  });
  final String id;
  final String name;
  final List<String> sessionMovementIds;
  final List<WeekDefinition> weeks;
}
