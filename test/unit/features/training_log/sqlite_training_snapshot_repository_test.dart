import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/training_log/data/sqlite_training_snapshot_repository.dart';
import 'package:hybrid_training/features/training_log/data/training_database_schema.dart';
import 'package:hybrid_training/features/training_log/domain/training_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'snapshot and actual set result survive reopening training.db',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'training-db-v1-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/training.db';
      SqliteDatabaseFile file() => SqliteDatabaseFile(
        fileName: 'training.db',
        version: TrainingDatabaseSchema.version,
        onCreate: TrainingDatabaseSchema.create,
        onUpgrade: TrainingDatabaseSchema.upgrade,
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      const load = Weight(10000, WeightUnit.kg);
      final cycle = GeneratedCycle(
        id: 'cycle-1',
        catalogVersion: 1,
        templateId: 'standard-531',
        variantId: 'standard-four-day',
        effectiveTrainingMaxes: const {'press': load},
        weeks: [
          GeneratedWeek(
            number: 1,
            sessions: [
              GeneratedSession(
                id: 'cycle-1:w1:s1',
                date: DateTime.utc(2026, 7, 20),
                movementId: const MovementId('press'),
                blocks: const [
                  GeneratedBlock(
                    id: 'main',
                    role: 'main-work',
                    movementId: MovementId('press'),
                    sets: [
                      GeneratedSet(
                        index: 0,
                        repetitions: {'type': 'fixed', 'count': 5},
                        percentageBasisPoints: 6500,
                        plannedLoad: load,
                        platesPerSide: [],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final firstFile = file();
      final first = SqliteTrainingSnapshotRepository(firstFile);
      await first.save(cycle);
      await first.recordSetResult(
        'cycle-1:w1:s1:main:0',
        const ActualSetResult(
          state: TrainingSetResultState.completed,
          repetitions: 7,
          loadCentiUnits: 10000,
          note: 'solid',
        ),
      );
      await firstFile.close();
      final secondFile = file();
      final second = SqliteTrainingSnapshotRepository(secondFile);
      expect((await second.load('cycle-1')).resolvedCycleJson, cycle.toJson());
      final result = await second.loadSetResult('cycle-1:w1:s1:main:0');
      expect(result.state, TrainingSetResultState.completed);
      expect(result.repetitions, 7);
      expect(result.note, 'solid');
      await secondFile.close();
    },
  );

  test('rejects incoherent completed set results', () async {
    final directory = await Directory.systemTemp.createTemp(
      'training-result-v1-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = SqliteDatabaseFile(
      fileName: 'training.db',
      version: TrainingDatabaseSchema.version,
      onCreate: TrainingDatabaseSchema.create,
      onUpgrade: TrainingDatabaseSchema.upgrade,
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/training.db',
    );
    addTearDown(file.close);
    final repository = SqliteTrainingSnapshotRepository(file);
    await expectLater(
      repository.recordSetResult(
        'missing',
        const ActualSetResult(
          state: TrainingSetResultState.completed,
          loadCentiUnits: -1,
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'migrates training.db v1 blocks with an explicit movement column',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'training-migration-v2-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/training.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) async {
            await database.execute(
              'CREATE TABLE blocks(id TEXT PRIMARY KEY, session_id TEXT NOT NULL, '
              'sequence INTEGER NOT NULL, role TEXT NOT NULL)',
            );
          },
        ),
      );
      await legacy.close();
      final file = SqliteDatabaseFile(
        fileName: 'training.db',
        version: TrainingDatabaseSchema.version,
        onCreate: TrainingDatabaseSchema.create,
        onUpgrade: TrainingDatabaseSchema.upgrade,
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(file.close);
      final columns = await (await file.open()).rawQuery(
        'PRAGMA table_info(blocks)',
      );
      expect(columns.map((column) => column['name']), contains('movement_id'));
    },
  );
}
