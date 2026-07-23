import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  test('catalog lint accepts valid option schema includes', () {
    final directory = Directory.systemTemp.createTempSync(
      'option_schema_include_',
    );
    try {
      _writeSchemas(directory, [
        _schema('common'),
        _schema('specialized', includes: [_reference('common')]),
      ]);

      final errors = catalog_tool.lintCatalog(sourcePath: directory.path);
      expect(errors.where((error) => error.contains('optionSchemas')), isEmpty);
      expect(
        catalog_tool.catalogCoverage(
          sourcePath: directory.path,
        )['missingReferences'],
        0,
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('catalog lint rejects malformed and duplicate include references', () {
    final directory = Directory.systemTemp.createTempSync(
      'option_schema_include_invalid_',
    );
    try {
      _writeSchemas(directory, [
        _schema('common'),
        _schema(
          'invalid',
          includes: [_reference('common'), _reference('common')],
        ),
        _schema(
          'invalid_revision',
          includes: [
            {'id': 'common', 'revision': 0},
          ],
        ),
      ]);

      final errors = catalog_tool.lintCatalog(sourcePath: directory.path);
      expect(
        errors.any((error) => error.contains('duplicate reference common@1')),
        isTrue,
      );
      expect(errors.any((error) => error.contains('invalid identity')), isTrue);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('catalog coverage counts a missing included schema reference', () {
    final directory = Directory.systemTemp.createTempSync(
      'option_schema_include_missing_',
    );
    try {
      _writeSchemas(directory, [
        _schema('specialized', includes: [_reference('missing')]),
      ]);

      expect(
        catalog_tool.catalogCoverage(
          sourcePath: directory.path,
        )['missingReferences'],
        1,
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}

void _writeSchemas(Directory directory, List<Map<String, Object?>> schemas) {
  File('${directory.path}/options.json').writeAsStringSync(
    jsonEncode({
      'schemaVersion': 1,
      'kind': 'optionSchemas',
      'optionSchemas': schemas,
    }),
  );
}

Map<String, Object?> _schema(
  String id, {
  List<Map<String, Object?>> includes = const [],
}) => {
  'id': id,
  'revision': 1,
  'sourceRuleIds': <Object?>[],
  if (includes.isNotEmpty) 'includeSchemaIds': includes,
  'parameters': <Object?>[],
};

Map<String, Object?> _reference(String id) => {'id': id, 'revision': 1};
