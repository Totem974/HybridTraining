enum CatalogEntryClassification {
  cycleTemplate,
  sharedComponent,
  rule,
  schedule,
  protocol,
  transition,
  documentation,
}

final class CatalogInventoryEntry {
  const CatalogInventoryEntry({
    required this.id,
    required this.generation,
    required this.classification,
    required this.title,
    this.cycleTemplateId,
  });

  final String id;
  final String generation;
  final CatalogEntryClassification classification;
  final String title;
  final String? cycleTemplateId;
}

final class CycleTemplateSummary {
  const CycleTemplateSummary({
    required this.id,
    required this.revision,
    required this.labelEn,
    required this.labelFr,
    required this.variantIds,
  });

  final String id;
  final int revision;
  final String labelEn;
  final String labelFr;
  final List<String> variantIds;
}

final class CycleCatalogIndex {
  const CycleCatalogIndex({
    required this.catalogVersion,
    required this.templates,
  });

  final int catalogVersion;
  final List<CycleTemplateSummary> templates;
}
