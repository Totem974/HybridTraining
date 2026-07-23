import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:training_engine/training_engine.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'Bodyweight option order is identical in SQLite and the bridge',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'option_schema_runtime_parity_',
      );
      Database? database;
      try {
        final artifacts = await catalog_tool.buildCatalogArtifacts(
          directory.path,
        );
        database = await databaseFactoryFfi.openDatabase(
          artifacts.databasePath,
        );
        final repository = SqliteTrainingCatalog(database);
        final native = await repository.loadEditorSchema(
          catalogVersion: 2,
          templateId: 'classic_bodyweight',
          variantId: 'four_day',
        );

        final bridge = BridgeService(LocalTrainingEngineBindings());
        bridge.initialize(File(artifacts.bundlePath).readAsStringSync());
        final web =
            jsonDecode(
                  bridge.cycleEditorSchema(
                    jsonEncode({
                      'apiVersion': 'v1',
                      'schemaVersion': 1,
                      'templateId': 'classic_bodyweight',
                      'variantId': 'four_day',
                    }),
                  ),
                )
                as Map<String, Object?>;
        final webOptionIds = (web['fields']! as List)
            .cast<Map<String, Object?>>()
            .where(
              (field) =>
                  field['path'] is String &&
                  (field['path']! as String).startsWith('options.'),
            )
            .map((field) => field['id'])
            .toList(growable: false);

        expect(webOptionIds, native.options.map((option) => option.id));
        expect(webOptionIds.take(2), ['warmUp.enabled', 'warmUp.type']);
        expect(webOptionIds.sublist(webOptionIds.length - 2), [
          'total_repetitions',
          'set_count',
        ]);

        final beginner = await repository.loadEditorSchema(
          catalogVersion: 2,
          templateId: 'classic_for_beginners',
          variantId: 'original_progression',
        );
        expect(
          beginner.options
              .singleWhere((option) => option.id == 'training_max_ratio')
              .scope,
          CycleOptionScope.perMovement,
        );
      } finally {
        await database?.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
