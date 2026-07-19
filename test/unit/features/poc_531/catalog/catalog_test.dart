import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/catalog/catalog.dart';
import 'package:hybrid_training/features/poc_531/domain/models.dart';

void main() {
  group('generated 5/3/1 catalog', () {
    test('classifies every workbook row without silently ignoring one', () {
      final report = getCatalogCoverageReport();

      expect(report.total, 354);
      expect(report.classified, report.total);
      expect(report.executable, 4);
      expect(report.nonExecutable, 350);
      expect(report.ambiguous, 350);
      expect(generatedCatalogEntries, hasLength(354));
    });

    test('has unique stable source identifiers', () {
      final ids = generatedCatalogEntries
          .map((record) => record.definition.id)
          .toSet();
      expect(ids, hasLength(generatedCatalogEntries.length));
      expect(validateGeneratedCatalog(), isEmpty);
    });

    test('keeps the three generations distinct', () {
      int count(Generation generation, SourceKind sourceKind) =>
          generatedCatalogEntries.where((record) {
            final definition = record.definition;
            return definition.generation == generation &&
                definition.sourceKind == sourceKind;
          }).length;

      expect(count(Generation.original, SourceKind.canonical), 40);
      expect(count(Generation.beyond, SourceKind.canonical), 107);
      expect(count(Generation.forever, SourceKind.canonical), 182);
    });

    test('models Powerlifting only as a supplement', () {
      final supplements = generatedCatalogEntries
          .where(
            (record) => record.definition.sourceKind == SourceKind.supplement,
          )
          .toList();

      expect(supplements, hasLength(25));
      expect(
        supplements.map((record) => record.definition.generation).toSet(),
        {Generation.original},
      );
    });

    test('connects every executable row to a registered Core v5 strategy', () {
      final executable = generatedCatalogEntries
          .map((record) => record.definition)
          .where((definition) => definition.isExecutable)
          .toList();

      expect(executable.map((entry) => entry.id).toSet(), {
        'PL-001',
        'BY-026',
        'FV-141',
        'FV-236',
      });
      expect(
        executable.every(
          (entry) => catalogGeneratorStrategies.contains(entry.generatorId),
        ),
        isTrue,
      );
    });

    test('gives every non-executable row an explicit review reason', () {
      final unavailable = generatedCatalogEntries
          .map((record) => record.definition)
          .where((definition) => !definition.isExecutable);

      expect(
        unavailable.every(
          (entry) => entry.nonExecutableReason!.startsWith('NEEDS_REVIEW:'),
        ),
        isTrue,
      );
    });
  });
}
