import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/forever/application/forever_composer_impl.dart';
import 'package:hybrid_training/features/forever/application/forever_web_application_impl.dart';
import 'package:hybrid_training/features/forever/data/forever_sqlite_schema.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_definition_repository.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_macrocycle_repository.dart';
import 'package:hybrid_training/features/forever/domain/forever_contract.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'published Forever definition composes five real Cycles and round-trips training.db',
    () async {
      final directory = Directory.systemTemp.createTempSync('forever_e2e_');
      final catalogPath = '${directory.path}/catalog.db';
      final trainingPath = '${directory.path}/training.db';
      Database? catalogDb;
      SqliteDatabaseFile? trainingFile;
      SqliteDatabaseFile? reopenedFile;
      try {
        await catalog_tool.buildCatalogDatabase(catalogPath);
        catalogDb = await databaseFactoryFfi.openDatabase(catalogPath);
        final catalog = SqliteTrainingCatalog(catalogDb);
        final definitions = await SqliteForeverDefinitionRepository(
          catalogDb,
        ).loadPublishedDefinitions(2);

        expect(definitions, hasLength(1));
        final definition = definitions.single;
        final resolver = CatalogForeverCycleResolver(catalog, 2);
        final slotRequests = <String, ForeverSlotRequest>{};
        for (final slot in definition.phases.expand((phase) => phase.slots)) {
          final cycle = await resolver.resolve(slot.defaultCycle);
          slotRequests[slot.id] = ForeverSlotRequest(
            slotId: slot.id,
            cycle: slot.defaultCycle,
            trainingDays: List<int>.generate(
              cycle.sessionMovementIds.length,
              (index) => index + 1,
            ),
            sessionOrder: cycle.sessionMovementIds,
          );
        }

        final macrocycle =
            await ForeverComposerImpl(
              cycleDefinitionResolver: resolver,
              cycleCompiler: const CycleCompilerImpl(),
            ).compose(
              definition,
              ForeverRequest(
                macrocycleId: 'forever-e2e',
                definitionId: definition.id,
                definitionRevision: definition.revision,
                startDate: DateTime.utc(2026, 1, 5),
                initialTrainingMaxes: const {
                  MovementId('overhead_press'): Weight(10000, WeightUnit.lb),
                  MovementId('bench_press'): Weight(15000, WeightUnit.lb),
                  MovementId('deadlift'): Weight(20000, WeightUnit.lb),
                  MovementId('squat'): Weight(18000, WeightUnit.lb),
                },
                slotRequests: slotRequests,
                unit: WeightUnit.lb,
                roundingIncrement: const Weight(500, WeightUnit.lb),
                barProfile: const BarProfile(
                  weight: Weight(4500, WeightUnit.lb),
                  platesPerSide: [
                    Weight(4500, WeightUnit.lb),
                    Weight(2500, WeightUnit.lb),
                    Weight(1000, WeightUnit.lb),
                    Weight(500, WeightUnit.lb),
                    Weight(250, WeightUnit.lb),
                  ],
                ),
              ),
            );

        expect(macrocycle.nodes, hasLength(5));
        expect(
          macrocycle.nodes.map((node) => node.role),
          orderedEquals(const [
            ForeverPhaseRole.leader,
            ForeverPhaseRole.leader,
            ForeverPhaseRole.deload,
            ForeverPhaseRole.anchor,
            ForeverPhaseRole.test,
          ]),
        );
        expect(
          macrocycle.nodes.every(
            (node) =>
                node.cycle.weeks.isNotEmpty &&
                node.cycle.weeks.expand((week) => week.sessions).isNotEmpty,
          ),
          isTrue,
        );
        expect(
          macrocycle.nodes
              .expand((node) => node.cycle.weeks)
              .expand((week) => week.sessions)
              .expand((session) => session.blocks)
              .expand((block) => block.sets),
          isNotEmpty,
        );

        trainingFile = SqliteDatabaseFile(
          fileName: 'training.db',
          databasePath: trainingPath,
          version: 1,
          factory: databaseFactoryFfi,
          onCreate: (database, _) => createForeverTrainingTables(database),
        );
        final repository = SqliteForeverMacrocycleRepository(trainingFile);
        await repository.save(
          macrocycle: macrocycle,
          savedAt: DateTime.utc(2026, 1, 1),
        );
        final firstRead = await repository.load(macrocycle.id);
        await trainingFile.close();

        reopenedFile = SqliteDatabaseFile(
          fileName: 'training.db',
          databasePath: trainingPath,
          version: 1,
          factory: databaseFactoryFfi,
          onCreate: (database, _) => createForeverTrainingTables(database),
        );
        final reopened = SqliteForeverMacrocycleRepository(reopenedFile);
        final secondRead = await reopened.load(macrocycle.id);
        expect(secondRead.nodes, hasLength(5));
        expect(secondRead.snapshot, firstRead.snapshot);
        expect(secondRead.logicalHash, firstRead.logicalHash);
        expect(secondRead.logicalHash, hasLength(16));
      } finally {
        await reopenedFile?.close();
        await trainingFile?.close();
        await catalogDb?.close();
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
