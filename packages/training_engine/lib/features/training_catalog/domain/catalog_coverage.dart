final class CatalogCoverage {
  const CatalogCoverage({
    required this.inventoryEntries,
    required this.classifiedEntries,
    required this.cycleTemplates,
    required this.cycleVariants,
    required this.sharedComponents,
    required this.optionSchemas,
    required this.schedules,
    required this.movements,
    required this.exercises,
    required this.assistancePlans,
    required this.conditioningDefinitions,
    required this.unresolvedCycleEntries,
    required this.missingVariants,
    required this.missingOptionSchemas,
    required this.missingSchedules,
    required this.missingReferences,
    required this.unsupportedPrimitives,
    required this.placeholderEntries,
    required this.compileFailures,
  });

  final int inventoryEntries;
  final int classifiedEntries;
  final int cycleTemplates;
  final int cycleVariants;
  final int sharedComponents;
  final int optionSchemas;
  final int schedules;
  final int movements;
  final int exercises;
  final int assistancePlans;
  final int conditioningDefinitions;
  final int unresolvedCycleEntries;
  final int missingVariants;
  final int missingOptionSchemas;
  final int missingSchedules;
  final int missingReferences;
  final int unsupportedPrimitives;
  final int placeholderEntries;
  final int compileFailures;

  bool get isComplete =>
      classifiedEntries == inventoryEntries &&
      unresolvedCycleEntries == 0 &&
      missingVariants == 0 &&
      missingOptionSchemas == 0 &&
      missingSchedules == 0 &&
      missingReferences == 0 &&
      unsupportedPrimitives == 0 &&
      placeholderEntries == 0 &&
      compileFailures == 0;
}

