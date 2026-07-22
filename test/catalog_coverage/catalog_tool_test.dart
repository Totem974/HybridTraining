import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_coverage.dart';
import '../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  test('coverage report uses the complete Dart counter contract', () {
    final report = catalog_tool.catalogCoverage();
    const contract = CatalogCoverage(
      inventoryEntries: 0,
      classifiedEntries: 0,
      cycleTemplates: 0,
      cycleVariants: 0,
      sharedComponents: 0,
      optionSchemas: 0,
      schedules: 0,
      movements: 0,
      exercises: 0,
      assistancePlans: 0,
      conditioningDefinitions: 0,
      unresolvedCycleEntries: 0,
      missingVariants: 0,
      missingOptionSchemas: 0,
      missingSchedules: 0,
      missingReferences: 0,
      unsupportedPrimitives: 0,
      placeholderEntries: 0,
      compileFailures: 0,
    );
    expect(report.keys, {
      'inventoryEntries',
      'classifiedEntries',
      'cycleTemplates',
      'cycleVariants',
      'sharedComponents',
      'optionSchemas',
      'schedules',
      'movements',
      'exercises',
      'assistancePlans',
      'conditioningDefinitions',
      'foreverDefinitions',
      'unresolvedCycleEntries',
      'missingVariants',
      'missingOptionSchemas',
      'missingSchedules',
      'missingReferences',
      'unsupportedPrimitives',
      'placeholderEntries',
      'compileFailures',
    });
    expect(contract.isComplete, isTrue);
    expect(report['classifiedEntries'], report['inventoryEntries']);
  });

  test('lint rejects unknown keys, kinds, primitives and placeholders', () {
    final directory = Directory.systemTemp.createTempSync('catalog_lint_');
    try {
      File(
        '${directory.path}/unknown-kind.json',
      ).writeAsStringSync('{"schemaVersion":1,"kind":"plugin","plugin":[]}');
      File('${directory.path}/placeholder.json').writeAsStringSync(
        '{"schemaVersion":1,"kind":"sources","sources":[{"ruleId":"r","work":"TODO","edition":"1","section":"p.1","reviewStatus":"reviewed"}]}',
      );
      File('${directory.path}/unknown-key.json').writeAsStringSync(
        '{"schemaVersion":1,"kind":"sources","sources":[{"ruleId":"r2","work":"Book","edition":"1","section":"p.1","reviewStatus":"reviewed","surprise":true}]}',
      );
      File('${directory.path}/primitive.json').writeAsStringSync(
        '{"schemaVersion":1,"kind":"components","components":[{"id":"c","revision":1,"role":"main_work","labels":{"en":"C","fr":"C"},"sourceRuleIds":["r"],"parameterSchemaIds":[],"constraints":{},"compatibilities":{},"block":{"id":"b","role":"main_work","sets":[{"repetitions":{"type":"mystery"},"load":{"type":"unloaded"}}]}}]}',
      );
      final errors = catalog_tool.lintCatalog(sourcePath: directory.path);
      expect(errors.any((error) => error.contains('unknown kind')), isTrue);
      expect(errors.any((error) => error.contains('unknown key')), isTrue);
      expect(
        errors.any((error) => error.contains('unknown primitive')),
        isTrue,
      );
      expect(errors.any((error) => error.contains('placeholder')), isTrue);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
