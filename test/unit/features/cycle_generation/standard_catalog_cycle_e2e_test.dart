import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:hybrid_training/features/training_log/data/sqlite_training_snapshot_repository.dart';
import 'package:hybrid_training/features/training_log/data/training_database_schema.dart';
import 'package:hybrid_training/features/training_log/domain/training_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'Standard is loaded, compiled, snapshotted and executed end to end',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'catalog-cycle-e2e-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final seed = await File(
        'assets/catalog/standard_531_v1.json',
      ).readAsString();
      final golden =
          jsonDecode(
                await File(
                  'test/fixtures/standard_531_catalog_cycle.golden.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      final catalog = await openCatalogDatabase(
        factory: databaseFactoryFfi,
        path: '${temporary.path}/catalog.db',
        seedJson: seed,
      );
      addTearDown(() => catalog.database.close());
      final definition = await catalog.resolve(
        catalogVersion: 1,
        templateId: 'standard_531',
        variantId: 'four_day',
      );

      const press = MovementId('overhead_press');
      const deadlift = MovementId('deadlift');
      const bench = MovementId('bench_press');
      const squat = MovementId('squat');
      const plates = <Weight>[
        Weight(2500, WeightUnit.kg),
        Weight(2500, WeightUnit.kg),
        Weight(2500, WeightUnit.kg),
        Weight(2000, WeightUnit.kg),
        Weight(2000, WeightUnit.kg),
        Weight(2000, WeightUnit.kg),
        Weight(1500, WeightUnit.kg),
        Weight(1000, WeightUnit.kg),
        Weight(500, WeightUnit.kg),
        Weight(250, WeightUnit.kg),
        Weight(125, WeightUnit.kg),
      ];
      final cycle = const CycleCompilerImpl().compile(
        definition,
        CycleRequest(
          cycleId: 'standard-cycle-golden',
          startDate: DateTime(2026, 7, 20),
          trainingDays: const [1, 2, 4, 5],
          sessionOrder: const [press, deadlift, bench, squat],
          maxInputs: const {
            press: OneRepMaxInput(Weight(8000, WeightUnit.kg)),
            deadlift: RepMaxInput(Weight(18000, WeightUnit.kg), 3),
            bench: DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
            squat: OneRepMaxInput(Weight(20000, WeightUnit.kg)),
          },
          globalTrainingMaxRatio: const Percentage(9000),
          trainingMaxRatioByMovement: const {squat: Percentage(8500)},
          unit: WeightUnit.kg,
          roundingIncrement: const Weight(250, WeightUnit.kg),
          barProfile: const BarProfile(
            weight: Weight(2000, WeightUnit.kg),
            platesPerSide: plates,
          ),
        ),
      );

      expect(cycle.catalogVersion, golden['catalogVersion']);
      expect(cycle.templateId, golden['templateId']);
      expect(cycle.variantId, golden['variantId']);
      expect(
        cycle.effectiveTrainingMaxes.map(
          (id, weight) => MapEntry(id, weight.centiUnits),
        ),
        golden['effectiveTrainingMaxCentiUnits'],
      );
      final expectedOrder = (golden['movementOrder']! as List).cast<String>();
      final expectedDates = (golden['dates']! as List).cast<List>();
      final expectedWeeks = (golden['weeks']! as List).cast<Map>();
      expect(cycle.weeks, hasLength(expectedWeeks.length));
      for (var weekIndex = 0; weekIndex < cycle.weeks.length; weekIndex++) {
        final week = cycle.weeks[weekIndex];
        expect(
          week.sessions.map((session) => session.movementId.value),
          expectedOrder,
        );
        expect(
          week.sessions.map(
            (session) => session.date.toIso8601String().substring(0, 10),
          ),
          expectedDates[weekIndex],
        );
        final goldenBlocks = (expectedWeeks[weekIndex]['blocks']! as List)
            .cast<Map>();
        for (final session in week.sessions) {
          expect(
            session.blocks.map((block) => block.role),
            goldenBlocks.map((block) => block['role']),
          );
          for (
            var blockIndex = 0;
            blockIndex < session.blocks.length;
            blockIndex++
          ) {
            final block = session.blocks[blockIndex];
            final expected = goldenBlocks[blockIndex];
            expect(
              block.sets.map((set) => set.percentageBasisPoints),
              expected['percentages'],
            );
            expect(block.sets.map(_repetitionLabel), expected['repetitions']);
            expect(
              block.sets.every(
                (set) =>
                    set.plannedLoad != null &&
                    set.platesPerSide.isNotEmpty &&
                    set.warning == null,
              ),
              isTrue,
            );
          }
        }
      }

      final trainingFile = SqliteDatabaseFile(
        fileName: 'training.db',
        version: TrainingDatabaseSchema.version,
        onCreate: TrainingDatabaseSchema.create,
        onUpgrade: TrainingDatabaseSchema.upgrade,
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/training.db',
      );
      addTearDown(trainingFile.close);
      final snapshots = SqliteTrainingSnapshotRepository(trainingFile);
      await snapshots.save(cycle);
      expect(
        (await snapshots.load(cycle.id)).resolvedCycleJson,
        cycle.toJson(),
      );
      final firstSetId = '${cycle.weeks.first.sessions.first.id}:warm_up:0';
      await snapshots.recordSetResult(
        firstSetId,
        const ActualSetResult(
          state: TrainingSetResultState.completed,
          repetitions: 5,
          loadCentiUnits: 3000,
          note: 'golden execution',
        ),
      );
      final actual = await snapshots.loadSetResult(firstSetId);
      expect(actual.state, TrainingSetResultState.completed);
      expect(actual.repetitions, 5);
      expect(actual.loadCentiUnits, 3000);
      expect(actual.note, 'golden execution');
    },
  );
}

Object _repetitionLabel(GeneratedSet set) {
  final repetitions = set.repetitions;
  if (repetitions['type'] == 'amrap') return '${repetitions['minimum']}+';
  return repetitions['count']!;
}
