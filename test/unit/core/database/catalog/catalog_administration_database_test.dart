import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/catalog/catalog_administration_database.dart';
import 'package:hybrid_training/core/database/catalog/catalog_publication_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('writable database handle and forgeable capability are not public', () {
    final source = File(
      'lib/core/database/catalog/catalog_administration_database.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('CatalogAdministrationCapability')));
    expect(source, isNot(matches(RegExp(r'Future<Database>\s+open\s*\('))));
    expect(source, contains('Future<Database> _open()'));
  });

  test('runtime libraries do not import the administration facade', () {
    final forbiddenImport = RegExp(
      r'''import\s+['"][^'"]*catalog_administration_database\.dart['"]''',
    );
    final runtimeImports = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => !file.path.endsWith('catalog_administration_database.dart'),
        )
        .where((file) => forbiddenImport.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(runtimeImports, isEmpty);
  });

  test('publication is routed through the publication service', () async {
    final root = await Directory.systemTemp.createTemp('catalog-admin-');
    addTearDown(() => root.delete(recursive: true));
    final facade = CatalogAdministrationDatabase(
      path: '${root.path}/catalog.db',
      publicationService: const CatalogPublicationService(),
      factory: databaseFactoryFfi,
    );

    await facade.initialize();

    await expectLater(
      facade.publish(
        catalogVersionId: 'missing-version',
        publishedAt: '2026-07-21T00:00:00Z',
      ),
      throwsA(
        isA<CatalogPublicationException>().having(
          (error) => error.issues,
          'issues',
          const ['version.not_found'],
        ),
      ),
    );

    final database = await databaseFactoryFfi.openDatabase(
      '${root.path}/catalog.db',
      options: OpenDatabaseOptions(readOnly: true),
    );
    addTearDown(database.close);
    expect(await database.query('catalog_publication_validations'), isEmpty);
  });
}
