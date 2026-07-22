import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/forever/data/forever_sqlite_schema.dart';
import 'package:hybrid_training/features/forever/data/forever_json_export.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_draft_repository.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_macrocycle_repository.dart';
import 'package:hybrid_training/features/forever/domain/forever_contract.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'Forever draft round-trips through workspace and replaces safely',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final repository = SqliteForeverDraftRepository(fixture.workspace);
      final first = StoredForeverDraft(
        id: 'current',
        payloadVersion: 1,
        definitionId: 'five-three-one-forever',
        definitionRevision: 1,
        payload: const {
          'startDate': '2026-07-22T00:00:00.000Z',
          'selectedCycles': {'leader': 'classic_531/standard'},
          'trainingMaxes': {'squat': 10000},
        },
        updatedAt: DateTime.utc(2026, 7, 22),
      );
      await repository.save(first);
      final loaded = await repository.load('current');
      expect(loaded?.payload, first.payload);
      expect(loaded?.definitionRevision, 1);
    },
  );

  test('macrocycle preserves order and logical hash after restart', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    final repository = SqliteForeverMacrocycleRepository(fixture.training);
    final macrocycle = _macrocycle();
    await repository.save(
      macrocycle: macrocycle,
      savedAt: DateTime.utc(2026, 7, 22),
    );
    final before = await repository.load(macrocycle.id);
    await fixture.training.close();
    final after = await SqliteForeverMacrocycleRepository(
      fixture.training,
    ).load(macrocycle.id);
    expect(after.logicalHash, before.logicalHash);
    expect(after.nodes.map((node) => node['slotId']), ['leader', 'anchor']);
    expect(after.snapshot, before.snapshot);
    expect(ForeverJsonExport.result(after), ForeverJsonExport.result(before));
  });

  test(
    'completed child is immutable and cancellation retains children',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final repository = SqliteForeverMacrocycleRepository(fixture.training);
      final original = _macrocycle();
      await repository.save(
        macrocycle: original,
        savedAt: DateTime.utc(2026, 7, 22),
      );
      await repository.completeNode(original.id, 0);
      final changed = _macrocycle(firstCycleId: 'changed-cycle');
      await expectLater(
        repository.save(
          macrocycle: changed,
          savedAt: DateTime.utc(2026, 7, 23),
        ),
        throwsStateError,
      );
      await repository.cancel(original.id, DateTime.utc(2026, 7, 24));
      final cancelled = await repository.load(original.id);
      expect(cancelled.state, MacrocycleState.cancelled);
      expect(cancelled.nodes, hasLength(2));
      await expectLater(
        repository.cancel(original.id, DateTime.utc(2026, 7, 25)),
        throwsStateError,
      );
      await expectLater(
        repository.completeNode(original.id, 1),
        throwsStateError,
      );
    },
  );
}

GeneratedMacrocycle _macrocycle({String firstCycleId = 'cycle-0'}) {
  final squat = MovementId('squat');
  final before = TrainingMaxSnapshot(
    values: {squat: const Weight(10000, WeightUnit.kg)},
    kind: TrainingMaxValueKind.confirmed,
  );
  final after = TrainingMaxSnapshot(
    values: {squat: const Weight(10500, WeightUnit.kg)},
    kind: TrainingMaxValueKind.projected,
  );
  GeneratedMacrocycleNode node(int index, String slot, String cycleId) =>
      GeneratedMacrocycleNode(
        index: index,
        slotId: slot,
        role: index == 0 ? ForeverPhaseRole.leader : ForeverPhaseRole.anchor,
        cycleReference: const ForeverCycleReference(
          templateId: 'standard',
          variantId: 'default',
        ),
        cycle: GeneratedCycle(
          id: cycleId,
          catalogVersion: 1,
          templateId: 'standard',
          variantId: 'default',
          effectiveTrainingMaxes: const {'squat': Weight(10000, WeightUnit.kg)},
          weeks: const [],
        ),
        trainingMaxesBefore: before,
        trainingMaxesAfter: after,
      );
  return GeneratedMacrocycle(
    id: 'macro-1',
    definitionId: const ForeverDefinitionId('five-three-one-forever'),
    definitionRevision: const ForeverDefinitionRevision(1),
    state: MacrocycleState.scheduled,
    nodes: [node(0, 'leader', firstCycleId), node(1, 'anchor', 'cycle-1')],
    initialTrainingMaxes: {squat: const Weight(10000, WeightUnit.kg)},
    projectedTrainingMaxes: {squat: const Weight(10500, WeightUnit.kg)},
  );
}

final class _Fixture {
  const _Fixture(this.directory, this.workspace, this.training);
  final Directory directory;
  final SqliteDatabaseFile workspace;
  final SqliteDatabaseFile training;

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp('forever-db-');
    return _Fixture(
      directory,
      SqliteDatabaseFile(
        fileName: 'workspace.db',
        databasePath: '${directory.path}/workspace.db',
        version: 1,
        factory: databaseFactoryFfi,
        onCreate: (db, version) => createForeverWorkspaceTables(db),
      ),
      SqliteDatabaseFile(
        fileName: 'training.db',
        databasePath: '${directory.path}/training.db',
        version: 1,
        factory: databaseFactoryFfi,
        onCreate: (db, version) => createForeverTrainingTables(db),
      ),
    );
  }

  Future<void> dispose() async {
    await workspace.close();
    await training.close();
    await directory.delete(recursive: true);
  }
}
