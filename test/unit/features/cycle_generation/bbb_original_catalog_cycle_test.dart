import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'BBB Original is catalog data compiled by the generic compiler',
    () async {
      final temporary = await Directory.systemTemp.createTemp('bbb-catalog-');
      addTearDown(() => temporary.delete(recursive: true));
      final catalog = await openCatalogDatabase(
        factory: databaseFactoryFfi,
        path: '${temporary.path}/catalog.db',
        seedJson: await File(
          'assets/catalog/standard_531_bbb_v2.json',
        ).readAsString(),
      );
      addTearDown(() => catalog.database.close());
      final golden =
          jsonDecode(
                await File(
                  'test/fixtures/bbb_original_catalog_cycle.golden.json',
                ).readAsString(),
              )
              as Map<String, Object?>;

      final definition = await catalog.resolve(
        catalogVersion: 2,
        templateId: 'bbb_original',
        variantId: 'four_day_same_lift_50',
      );
      const movements = [
        MovementId('overhead_press'),
        MovementId('deadlift'),
        MovementId('bench_press'),
        MovementId('squat'),
      ];
      final cycle = const CycleCompilerImpl().compile(
        definition,
        CycleRequest(
          cycleId: 'bbb-original-golden',
          startDate: DateTime(2026, 7, 20),
          trainingDays: [1, 2, 4, 5],
          sessionOrder: movements,
          maxInputs: {
            MovementId('overhead_press'): OneRepMaxInput(
              Weight(8000, WeightUnit.kg),
            ),
            MovementId('deadlift'): OneRepMaxInput(
              Weight(18000, WeightUnit.kg),
            ),
            MovementId('bench_press'): DirectTrainingMaxInput(
              Weight(10000, WeightUnit.kg),
            ),
            MovementId('squat'): OneRepMaxInput(Weight(20000, WeightUnit.kg)),
          },
          globalTrainingMaxRatio: Percentage(9000),
          trainingMaxRatioByMovement: {MovementId('squat'): Percentage(8500)},
          unit: WeightUnit.kg,
          roundingIncrement: Weight(250, WeightUnit.kg),
          barProfile: BarProfile(
            weight: Weight(2000, WeightUnit.kg),
            platesPerSide: [
              Weight(2500, WeightUnit.kg),
              Weight(2500, WeightUnit.kg),
              Weight(2500, WeightUnit.kg),
              Weight(2000, WeightUnit.kg),
              Weight(2000, WeightUnit.kg),
              Weight(1500, WeightUnit.kg),
              Weight(1000, WeightUnit.kg),
              Weight(500, WeightUnit.kg),
              Weight(250, WeightUnit.kg),
              Weight(125, WeightUnit.kg),
            ],
          ),
        ),
      );

      expect(cycle.catalogVersion, golden['catalogVersion']);
      expect(cycle.templateId, golden['templateId']);
      expect(cycle.variantId, golden['variantId']);
      expect(cycle.id, golden['cycleId']);
      expect(
        cycle.effectiveTrainingMaxes.map(
          (id, weight) => MapEntry(id, weight.centiUnits),
        ),
        golden['effectiveTrainingMaxCentiUnits'],
      );
      final expectedDates = (golden['dates']! as List).cast<List>();
      final expectedWeeks = (golden['weeks']! as List).cast<Map>();
      for (var weekIndex = 0; weekIndex < cycle.weeks.length; weekIndex++) {
        final week = cycle.weeks[weekIndex];
        expect(week.number, expectedWeeks[weekIndex]['number']);
        expect(
          week.sessions.map((session) => session.movementId.value),
          golden['movementOrder'],
        );
        expect(
          week.sessions.map(
            (session) => session.date.toIso8601String().substring(0, 10),
          ),
          expectedDates[weekIndex],
        );
        final expectedBlocks = (expectedWeeks[weekIndex]['blocks']! as List)
            .cast<Map>();
        for (final session in week.sessions) {
          expect(
            session.blocks.map((block) => block.role),
            expectedBlocks.map((block) => block['role']),
          );
          for (var index = 0; index < session.blocks.length; index++) {
            final block = session.blocks[index];
            final expected = expectedBlocks[index];
            expect(
              block.movementId,
              session.movementId,
              reason: 'Original BBB uses the same supplemental lift',
            );
            expect(
              block.sets.map((set) => set.percentageBasisPoints),
              expected['percentages'],
            );
            expect(block.sets.map(_repetitionLabel), expected['repetitions']);
          }
        }
      }
      final supplementalLoads = (golden['supplementalLoadsCentiUnits']! as Map)
          .cast<String, int>();
      for (final session in cycle.weeks.first.sessions) {
        final supplemental = session.blocks.singleWhere(
          (block) => block.role == 'supplemental',
        );
        expect(supplemental.sets, hasLength(5));
        expect(
          supplemental.sets.map((set) => set.plannedLoad!.centiUnits),
          everyElement(supplementalLoads[session.movementId.value]),
        );
      }

      final snapshot = cycle.toJson();
      final expectedSnapshot = golden['snapshot']! as Map;
      expect(snapshot['schemaVersion'], expectedSnapshot['schemaVersion']);
      expect(snapshot['catalogVersion'], expectedSnapshot['catalogVersion']);
      expect(cycle.weeks, hasLength(expectedSnapshot['weekCount']! as int));
      expect(
        cycle.weeks.every(
          (week) => week.sessions.length == expectedSnapshot['sessionsPerWeek'],
        ),
        isTrue,
      );
    },
  );
}

Object _repetitionLabel(GeneratedSet set) {
  if (set.repetitions['type'] == 'amrap') {
    return '${set.repetitions['minimum']}+';
  }
  return set.repetitions['count']!;
}
