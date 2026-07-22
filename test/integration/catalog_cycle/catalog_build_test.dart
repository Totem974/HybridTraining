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
      Database? openedDatabase;
      try {
        final first = '${directory.path}/first.db';
        final second = '${directory.path}/second.db';
        await catalog_tool.buildCatalogDatabase(first);
        await catalog_tool.buildCatalogDatabase(second);
        expect(File(first).readAsBytesSync(), File(second).readAsBytesSync());

        final database = await databaseFactoryFfi.openDatabase(first);
        openedDatabase = database;
        final repository = SqliteTrainingCatalog(database);
        final index = await repository.loadIndex(catalogVersion: 2);
        final templateIds = index.templates.map((item) => item.id).toSet();
        expect(templateIds, contains('classic_531'));
        expect(templateIds, contains('beyond_boring_but_big'));
        expect(templateIds, contains('powerlifting_classic_531'));
        expect(templateIds, isNot(contains('forever_bbb_leader')));
        expect(templateIds, isNot(contains('forever_7th_week_protocol')));
        for (final templateId in const [
          'classic_531',
          'beyond_boring_but_big',
          'powerlifting_classic_531',
        ]) {
          final template = index.templates.singleWhere(
            (item) => item.id == templateId,
          );
          final definition = await repository.resolve(
            catalogVersion: 2,
            templateId: template.id,
            variantId: template.variantIds.first,
          );
          expect(definition.sessionMovementIds, isNotEmpty);
          expect(definition.weeks, isNotEmpty);
          expect(
            definition.weeks.expand(
              (week) => [
                ...week.blocks,
                ...week.sessions.expand((session) => session.blocks),
              ],
            ),
            isNotEmpty,
          );
        }
        for (final identity in const {
          'classic_for_beginners': 'original_progression',
          'classic_full_body_phase_1': 'phase_1',
          'classic_full_body_phase_2': 'phase_2',
          'classic_full_body_phase_3': 'phase_3',
        }.entries) {
          final definition = await repository.resolve(
            catalogVersion: 2,
            templateId: identity.key,
            variantId: identity.value,
          );
          expect(
            definition.sessionMovementIds.map((item) => item.value),
            orderedEquals(const ['monday', 'wednesday', 'friday']),
          );
          for (final week in definition.weeks) {
            expect(week.sessions, hasLength(3));
            expect(
              week.sessions.every((session) => session.blocks.isNotEmpty),
              isTrue,
            );
            expect(
              week.sessions
                  .expand((session) => session.blocks)
                  .map((block) => block.movementId?.value)
                  .whereType<String>(),
              isNot(contains(anyOf('monday', 'wednesday', 'friday'))),
            );
          }
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
            whereArgs: [2],
          ),
          throwsA(isA<DatabaseException>()),
        );
        await database.close();
      } finally {
        if (openedDatabase?.isOpen ?? false) await openedDatabase!.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
