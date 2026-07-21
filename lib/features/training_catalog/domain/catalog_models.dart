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
    this.components = const [],
    this.schedules = const [],
    this.rules = const [],
  });

  final int schemaVersion;
  final int catalogVersion;
  final String status;
  final String sourceReference;
  final List<CatalogMovement> movements;
  final List<CatalogTemplate> templates;
  final List<CatalogComponent> components;
  final List<CatalogSchedule> schedules;
  final List<CanonicalRuleReference> rules;
}

final class CanonicalRuleReference {
  const CanonicalRuleReference({
    required this.ruleId,
    required this.work,
    required this.edition,
    required this.section,
    required this.reviewStatus,
  });
  final String ruleId;
  final String work;
  final String edition;
  final String section;
  final String reviewStatus;
}

final class CatalogComponent {
  const CatalogComponent({
    required this.id,
    required this.block,
    this.ruleIds = const [],
  });
  final String id;
  final BlockDefinition block;
  final List<String> ruleIds;
}

final class CatalogSchedule {
  const CatalogSchedule({required this.id, required this.movementIds});
  final String id;
  final List<String> movementIds;
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
    this.componentIdsByWeek = const {},
  });
  final String id;
  final String name;
  final List<String> sessionMovementIds;
  final List<WeekDefinition> weeks;
  final Map<int, List<String>> componentIdsByWeek;
}
