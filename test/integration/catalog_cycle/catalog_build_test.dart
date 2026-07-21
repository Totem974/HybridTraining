import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/data/catalog_source_document_codec.dart';
import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  test('build is deterministic and materializes the multi-family sources', () {
    final directory = Directory.systemTemp.createTempSync('catalog_build_');
    try {
      final first = File('${directory.path}/first.json');
      final second = File('${directory.path}/second.json');
      catalog_tool.buildCatalogSeed(first.path);
      catalog_tool.buildCatalogSeed(second.path);
      expect(first.readAsBytesSync(), second.readAsBytesSync());

      final seed = jsonDecode(first.readAsStringSync()) as Map<String, Object?>;
      expect(seed['schemaVersion'], 1);
      expect(seed['status'], 'published');
      final documents = (seed['documents']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(documents, isNotEmpty);
      expect(
        documents.map((document) => document['path'] as String).toList(),
        orderedEquals(
          (documents.map((document) => document['path'] as String).toList()
            ..sort()),
        ),
      );

      const codec = CatalogSourceDocumentCodec();
      final templateIds = <String>{};
      var materializedSchedules = 0;
      var decodedOptionSchemas = 0;
      for (final document in documents) {
        final content = document['content']! as Map<String, Object?>;
        final encoded = jsonEncode(content);
        switch (content['kind']) {
          case 'templates':
            templateIds.addAll(
              codec.decodeTemplates(encoded).map((template) => template.id),
            );
          case 'schedules':
            materializedSchedules +=
                (content['schedules']! as List<Object?>).length;
          case 'optionSchemas':
            decodedOptionSchemas += codec.decodeOptionSchemas(encoded).length;
        }
      }
      expect(templateIds, contains('classic_531'));
      expect(templateIds, contains('beyond_boring_but_big'));
      expect(templateIds, contains('powerlifting_classic_531'));
      expect(templateIds.where((id) => id.startsWith('forever')), isEmpty);
      expect(materializedSchedules, greaterThan(1));
      expect(decodedOptionSchemas, greaterThan(1));

      final coverage = seed['coverage']! as Map<String, Object?>;
      expect(coverage['inventoryEntries'], 354);
      expect(coverage['classifiedEntries'], 354);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
