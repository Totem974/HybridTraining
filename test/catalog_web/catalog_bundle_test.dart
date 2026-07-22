import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalog/canonical_json.dart';
import '../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  test('web bundle and SQLite catalogue have the same logical hash', () async {
    final output = Directory.systemTemp.createTempSync('catalog_web_test_');
    try {
      final report = await catalog_tool.buildCatalogArtifacts(output.path);
      final bundle = jsonDecode(File(report.bundlePath).readAsStringSync());
      final manifest =
          jsonDecode(File(report.manifestPath).readAsStringSync())
              as Map<String, Object?>;
      final databaseHash = await catalog_tool.readCatalogDatabaseLogicalHash(
        report.databasePath,
      );

      expect(logicalJsonHash(bundle), report.logicalHash);
      expect(databaseHash, report.logicalHash);
      expect(manifest['contentHash'], report.logicalHash);
      expect(manifest['catalogVersion'], 2);
      expect(manifest['schemaVersion'], 1);
      expect(manifest['buildId'], 'catalog-2-${report.logicalHash}');
      expect(
        (manifest['entryCounts']! as Map<String, Object?>)['inventory'],
        354,
      );
    } finally {
      output.deleteSync(recursive: true);
    }
  });

  test('web artifacts are byte-for-byte deterministic', () async {
    final first = Directory.systemTemp.createTempSync('catalog_web_first_');
    final second = Directory.systemTemp.createTempSync('catalog_web_second_');
    try {
      final a = await catalog_tool.buildCatalogArtifacts(first.path);
      final b = await catalog_tool.buildCatalogArtifacts(second.path);
      expect(
        File(a.bundlePath).readAsBytesSync(),
        File(b.bundlePath).readAsBytesSync(),
      );
      expect(
        File(a.manifestPath).readAsBytesSync(),
        File(b.manifestPath).readAsBytesSync(),
      );
      expect(a.logicalHash, b.logicalHash);
    } finally {
      first.deleteSync(recursive: true);
      second.deleteSync(recursive: true);
    }
  });
}
