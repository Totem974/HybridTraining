export 'catalog.generated.dart';
export 'catalog_schema.dart';

import '../domain/models.dart';
import 'catalog.generated.dart';

const catalogGeneratorStrategies = <String>{
  'canonical-powerlifting',
  'canonical-beyond',
  'canonical-forever-original-fsl',
  'canonical-bps',
};

List<ProgramDefinition> get catalogProgramDefinitions => List.unmodifiable(
  generatedCatalogEntries.map((record) => record.definition),
);

CatalogCoverageReport getCatalogCoverageReport() {
  var executable = 0;
  var ambiguous = 0;
  for (final record in generatedCatalogEntries) {
    executable += record.definition.isExecutable ? 1 : 0;
    ambiguous += record.ambiguity ? 1 : 0;
  }
  return CatalogCoverageReport(
    total: generatedCatalogEntries.length,
    classified: generatedCatalogEntries.length,
    executable: executable,
    nonExecutable: generatedCatalogEntries.length - executable,
    ambiguous: ambiguous,
  );
}

List<String> validateGeneratedCatalog() {
  final issues = <String>[];
  final ids = <String>{};
  for (final record in generatedCatalogEntries) {
    final entry = record.definition;
    if (!ids.add(entry.id)) issues.add('Duplicate id: ${entry.id}');
    if (entry.isExecutable) {
      if (!catalogGeneratorStrategies.contains(entry.generatorId)) {
        issues.add('Missing generator strategy: ${entry.id}');
      }
      if (record.ambiguity) issues.add('Ambiguous executable: ${entry.id}');
    } else if (entry.nonExecutableReason == null ||
        entry.nonExecutableReason!.isEmpty) {
      issues.add('Missing non-executable reason: ${entry.id}');
    }
  }
  return List.unmodifiable(issues);
}
