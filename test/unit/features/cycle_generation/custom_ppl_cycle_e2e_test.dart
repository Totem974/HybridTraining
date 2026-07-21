import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/application/definition_resolver.dart';
import 'package:hybrid_training/features/cycle_generation/data/sqlite_workspace_program_repository.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/workspace_program.dart';
import 'package:hybrid_training/features/training_catalog/application/catalog_repository.dart';
import 'package:hybrid_training/features/training_log/data/sqlite_training_snapshot_repository.dart';
import 'package:hybrid_training/features/training_log/data/training_database_schema.dart';
import 'package:hybrid_training/features/training_log/domain/training_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'PPL resolves, compiles and round-trips through the common path',
    () async {
      final directory = await Directory.systemTemp.createTemp('ppl-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final workspaceFile = SqliteDatabaseFile(
        fileName: 'workspace.db',
        version: WorkspaceDatabaseSchema.version,
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/workspace.db',
        onCreate: (db, version) async {
          await WorkspaceDatabaseSchema.create(db, version);
        },
      );
      addTearDown(workspaceFile.close);
      final workspaceDb = await workspaceFile.open();
      await workspaceDb.insert('profiles', {
        'id': 'athlete',
        'display_name': 'Athlete',
        'unit': 'kg',
        'global_tm_ratio_basis_points': 9000,
        'rounding_increment_centi_units': 250,
      });
      final programs = SqliteWorkspaceProgramRepository(workspaceFile);
      await programs.save(_multiExercisePpl());

      final catalog = _CatalogStub({
        'bench_press',
        'dip',
        'barbell_row',
        'pull_up',
        'squat',
        'lunge',
      });
      final definition = await DefinitionResolver(
        catalog: catalog,
        workspacePrograms: programs,
      ).resolve(const WorkspaceCycleDefinitionReference('ppl'));
      expect(catalog.validatedVersion, 1);
      expect(definition.sourceReference, 'userDefined:ppl:r1');

      const push = MovementId('push');
      const pull = MovementId('pull');
      const legs = MovementId('legs');
      const bench = MovementId('bench_press');
      const row = MovementId('barbell_row');
      const squat = MovementId('squat');
      final cycle = const CycleCompilerImpl().compile(
        definition,
        CycleRequest(
          cycleId: 'ppl-cycle',
          startDate: DateTime(2026, 7, 20),
          trainingDays: const [1, 3, 5],
          sessionOrder: const [push, pull, legs],
          maxInputs: const {
            bench: DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
            row: DirectTrainingMaxInput(Weight(8000, WeightUnit.kg)),
            squat: DirectTrainingMaxInput(Weight(14000, WeightUnit.kg)),
          },
          globalTrainingMaxRatio: const Percentage(9000),
          unit: WeightUnit.kg,
          roundingIncrement: const Weight(250, WeightUnit.kg),
          barProfile: const BarProfile(
            weight: Weight(2000, WeightUnit.kg),
            platesPerSide: [
              Weight(2000, WeightUnit.kg),
              Weight(1000, WeightUnit.kg),
              Weight(500, WeightUnit.kg),
              Weight(250, WeightUnit.kg),
              Weight(125, WeightUnit.kg),
            ],
          ),
        ),
      );
      expect(cycle.weeks.single.sessions, hasLength(3));
      expect(cycle.weeks.single.sessions.first.blocks, hasLength(2));
      expect(
        cycle.weeks.single.sessions.first.blocks.map(
          (block) => block.movementId.value,
        ),
        ['bench_press', 'dip'],
      );
      expect(
        cycle.effectiveTrainingMaxes.keys,
        containsAll(['bench_press', 'barbell_row', 'squat']),
      );
      expect(cycle.effectiveTrainingMaxes, isNot(contains('dip')));

      final trainingFile = SqliteDatabaseFile(
        fileName: 'training.db',
        version: TrainingDatabaseSchema.version,
        onCreate: TrainingDatabaseSchema.create,
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/training.db',
      );
      addTearDown(trainingFile.close);
      final snapshots = SqliteTrainingSnapshotRepository(trainingFile);
      await snapshots.save(cycle);
      expect(
        (await snapshots.load(cycle.id)).resolvedCycleJson,
        cycle.toJson(),
      );
      final setId = '${cycle.weeks.single.sessions.first.id}:bench:0';
      await snapshots.recordSetResult(
        setId,
        const ActualSetResult(
          state: TrainingSetResultState.completed,
          repetitions: 5,
          loadCentiUnits: 6750,
          note: 'PPL round-trip',
        ),
      );
      expect((await snapshots.loadSetResult(setId)).note, 'PPL round-trip');
    },
  );
}

final class _CatalogStub implements TrainingCatalogRepository {
  _CatalogStub(this.available);
  final Set<String> available;
  int? validatedVersion;

  @override
  Future<void> validateMovementReferences({
    required int catalogVersion,
    required Set<MovementId> movementIds,
  }) async {
    if (!movementIds.every((id) => available.contains(id.value))) {
      throw StateError('Unknown catalog movement reference');
    }
    validatedVersion = catalogVersion;
  }

  @override
  Future<ResolvedCycleDefinition> resolve({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) => throw UnimplementedError();
}

WorkspaceProgram _multiExercisePpl() => const WorkspaceProgram(
  id: 'ppl',
  profileId: 'athlete',
  name: 'Push Pull Legs',
  revision: 1,
  catalogVersion: 1,
  weeks: [
    WeekDefinition(
      number: 1,
      sessions: [
        SessionDefinition(
          id: MovementId('push'),
          role: 'push',
          blocks: [
            BlockDefinition(
              id: 'bench',
              role: 'main_work',
              movementId: MovementId('bench_press'),
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(5),
                  load: TrainingMaxPercentageLoad(Percentage(7500)),
                ),
              ],
            ),
            BlockDefinition(
              id: 'dips',
              role: 'assistance',
              movementId: MovementId('dip'),
              sets: [
                PrescribedSetDefinition(
                  repetitions: RepetitionRange(8, 12),
                  load: BodyweightLoad(),
                ),
              ],
            ),
          ],
        ),
        SessionDefinition(
          id: MovementId('pull'),
          role: 'pull',
          blocks: [
            BlockDefinition(
              id: 'row',
              role: 'main_work',
              movementId: MovementId('barbell_row'),
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(8),
                  load: TrainingMaxPercentageLoad(Percentage(7000)),
                ),
              ],
            ),
            BlockDefinition(
              id: 'pull-ups',
              role: 'assistance',
              movementId: MovementId('pull_up'),
              sets: [
                PrescribedSetDefinition(
                  repetitions: TotalRepetitions(30),
                  load: BodyweightLoad(),
                ),
              ],
            ),
          ],
        ),
        SessionDefinition(
          id: MovementId('legs'),
          role: 'legs',
          blocks: [
            BlockDefinition(
              id: 'squat',
              role: 'main_work',
              movementId: MovementId('squat'),
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(5),
                  load: TrainingMaxPercentageLoad(Percentage(8000)),
                ),
              ],
            ),
            BlockDefinition(
              id: 'lunges',
              role: 'assistance',
              movementId: MovementId('lunge'),
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(10),
                  load: FixedLoad(Weight(2000, WeightUnit.kg)),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
