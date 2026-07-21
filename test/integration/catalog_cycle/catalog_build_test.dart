import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'build publishes the deterministic multi-family SQLite catalog',
    () async {
      final directory = Directory.systemTemp.createTempSync('catalog_build_');
      try {
        final first = '${directory.path}/first.db';
        final second = '${directory.path}/second.db';
        await catalog_tool.buildCatalogDatabase(first);
        await catalog_tool.buildCatalogDatabase(second);
        expect(File(first).readAsBytesSync(), File(second).readAsBytesSync());

        final database = await databaseFactoryFfi.openDatabase(first);
        final repository = SqliteTrainingCatalog(database);
        final index = await repository.loadIndex(catalogVersion: 1);
        final templateIds = index.templates.map((item) => item.id).toSet();
        expect(templateIds, contains('classic_531'));
        expect(templateIds, contains('beyond_boring_but_big'));
        expect(templateIds, contains('powerlifting_classic_531'));
        expect(templateIds.where((id) => id.startsWith('forever')), isEmpty);
        for (final templateId in const [
          'classic_531',
          'beyond_boring_but_big',
          'powerlifting_classic_531',
        ]) {
          final template = index.templates.singleWhere(
            (item) => item.id == templateId,
          );
          final definition = await repository.resolve(
            catalogVersion: 1,
            templateId: template.id,
            variantId: template.variantIds.first,
          );
          expect(definition.sessionMovementIds, isNotEmpty);
          expect(definition.weeks, isNotEmpty);
          expect(definition.weeks.expand((week) => week.blocks), isNotEmpty);
        }
        expect(
          (await database.rawQuery(
            'SELECT COUNT(*) AS count FROM catalog_inventory',
          )).single['count'],
          354,
        );
        expect(
          (await database.rawQuery(
                'SELECT COUNT(*) AS count FROM catalog_schedules_v2',
              )).single['count']
              as int,
          greaterThan(1),
        );
        expect(
          (await database.rawQuery(
                'SELECT COUNT(*) AS count FROM catalog_option_schemas',
              )).single['count']
              as int,
          greaterThan(1),
        );
        expect(
          (await database.rawQuery(
            'PRAGMA integrity_check',
          )).single.values.single,
          'ok',
        );
        await expectLater(
          database.update(
            'catalog_templates',
            {'name': 'mutated'},
            where: 'version=?',
            whereArgs: [1],
          ),
          throwsA(isA<DatabaseException>()),
        );
        await database.close();
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
}
