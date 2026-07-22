import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/forever/application/forever_composer_impl.dart';
import 'package:hybrid_training/features/forever/application/forever_web_application_impl.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_definition_repository.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_draft_repository.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_macrocycle_repository.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_contract.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:hybrid_training/features/training_log/data/training_database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  setUpAll(sqfliteFfiInit);

  test('custom Web draft controls composition, reload and export', () async {
    final directory = Directory.systemTemp.createTempSync('forever_web_');
    final catalogPath = '${directory.path}/catalog.db';
    final workspacePath = '${directory.path}/workspace.db';
    final trainingPath = '${directory.path}/training.db';
    Database? catalogDatabase;
    SqliteDatabaseFile? workspace;
    SqliteDatabaseFile? training;
    try {
      await catalog_tool.buildCatalogDatabase(catalogPath);
      catalogDatabase = await databaseFactoryFfi.openDatabase(catalogPath);
      final catalog = SqliteTrainingCatalog(catalogDatabase);
      workspace = SqliteDatabaseFile(
        fileName: 'workspace.db',
        databasePath: workspacePath,
        factory: databaseFactoryFfi,
        version: WorkspaceDatabaseSchema.version,
        onCreate: WorkspaceDatabaseSchema.create,
        onUpgrade: WorkspaceDatabaseSchema.upgrade,
      );
      training = SqliteDatabaseFile(
        fileName: 'training.db',
        databasePath: trainingPath,
        factory: databaseFactoryFfi,
        version: TrainingDatabaseSchema.version,
        onCreate: TrainingDatabaseSchema.create,
        onUpgrade: TrainingDatabaseSchema.upgrade,
      );
      final resolver = CatalogForeverCycleResolver(catalog, 2);
      final application = ForeverWebApplicationImpl(
        catalogVersion: 2,
        definitionRepository: SqliteForeverDefinitionRepository(
          catalogDatabase,
        ),
        catalogQuery: catalog,
        cycleResolver: resolver,
        composer: ForeverComposerImpl(
          cycleDefinitionResolver: resolver,
          cycleCompiler: const CycleCompilerImpl(),
        ),
        draftRepository: SqliteForeverDraftRepository(workspace),
        macrocycleRepository: SqliteForeverMacrocycleRepository(training),
        now: () => DateTime.utc(2026, 7, 22, 12),
      );
      final definition = (await application.loadDefinitions()).single;
      final slots = definition.phases.expand((phase) => phase.slots).toList();
      final leader = slots.firstWhere((slot) => slot.role == 'leader');
      final anchor = slots.firstWhere((slot) => slot.role == 'anchor');
      ForeverDraftNode node(String id, String role, String key) {
        final parts = key.split('/');
        return ForeverDraftNode(
          id: id,
          role: role,
          cycleKey: key,
          configuration: CycleEditorState(
            templateId: parts.first,
            variantId: parts.last,
            trainingDays: const [1, 2, 4, 5],
            sessionOrder: const [
              'overhead_press',
              'deadlift',
              'bench_press',
              'squat',
            ],
            globalTrainingMaxRatioBasisPoints: 9000,
          ),
        );
      }

      final draft = ForeverEditorDraft(
        definitionId: definition.id,
        definitionRevision: definition.revision,
        startDate: DateTime.utc(2026, 8, 3),
        trainingMaxCentiUnits: const {
          'overhead_press': 10000,
          'deadlift': 20000,
          'bench_press': 15000,
          'squat': 18000,
        },
        selectedCyclesBySlot: const {},
        architectureMode: ForeverWebArchitectureMode.userDefined,
        nodes: [
          node('custom-anchor', 'anchor', anchor.defaultCycleKey),
          node('custom-leader', 'leader', leader.defaultCycleKey),
        ],
        equipment: const {
          'barWeightCentiUnits': 4500,
          'roundingIncrementCentiUnits': 500,
          'platesPerSideCentiUnits': [4500, 2500, 1000, 500, 250],
        },
      );
      await application.saveDraft(draft);
      final loaded = await application.loadDraft();
      expect(loaded?.architectureMode, ForeverWebArchitectureMode.userDefined);
      expect(loaded?.nodes.map((item) => item.id), [
        'custom-anchor',
        'custom-leader',
      ]);

      final generated = await application.generateSaveAndReload(draft);
      expect(generated.nodes.map((item) => item.role), ['anchor', 'leader']);
      expect(generated.nodes, hasLength(2));
      expect(await application.loadSavedMacrocycle(), isNotNull);
      expect(await application.exportDraft(draft), contains('configuration'));
      expect(
        await application.exportMacrocycle(generated.id),
        contains('logicalHash'),
      );
    } finally {
      await workspace?.close();
      await training?.close();
      await catalogDatabase?.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  });
}
