import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/data/sqlite_workspace_program_repository.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/workspace_program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('user-defined program survives reopening workspace.db', () async {
    final directory = await Directory.systemTemp.createTemp('workspace-ppl-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/workspace.db';

    SqliteDatabaseFile file() => SqliteDatabaseFile(
      fileName: 'workspace.db',
      version: WorkspaceDatabaseSchema.version,
      factory: databaseFactoryFfi,
      databasePath: path,
      onCreate: (db, version) async {
        await WorkspaceDatabaseSchema.create(db, version);
      },
    );

    final firstFile = file();
    final database = await firstFile.open();
    await database.insert('profiles', {
      'id': 'athlete',
      'display_name': 'Athlete',
      'unit': 'kg',
      'global_tm_ratio_basis_points': 9000,
      'rounding_increment_centi_units': 250,
    });
    await SqliteWorkspaceProgramRepository(firstFile).save(_ppl());
    await firstFile.close();

    final secondFile = file();
    final loaded = await SqliteWorkspaceProgramRepository(
      secondFile,
    ).load('ppl');
    expect(loaded.catalogVersion, 1);
    expect(loaded.revision, 1);
    expect(loaded.weeks.single.sessions.map((session) => session.role), [
      'push',
      'pull',
      'legs',
    ]);
    expect(
      loaded.catalogMovementReferences.map((id) => id.value),
      containsAll(['bench_press', 'pull_up', 'squat']),
    );
    await secondFile.close();
  });

  test('strict decoder rejects unknown keys and primitives', () {
    final encoded =
        jsonDecode(const WorkspaceProgramCodec().encode(_ppl()))!
            as Map<String, Object?>;
    encoded['unexpected'] = true;
    expect(
      () => const WorkspaceProgramCodec().decodeDefinition(jsonEncode(encoded)),
      throwsA(isA<WorkspaceProgramFormatException>()),
    );

    final unknownPrimitive =
        jsonDecode(const WorkspaceProgramCodec().encode(_ppl()))!
            as Map<String, Object?>;
    final weeks = unknownPrimitive['weeks']! as List<Object?>;
    final week = weeks.single! as Map<String, Object?>;
    final sessions = week['sessions']! as List<Object?>;
    final session = sessions.first! as Map<String, Object?>;
    final blocks = session['blocks']! as List<Object?>;
    final block = blocks.first! as Map<String, Object?>;
    final sets = block['sets']! as List<Object?>;
    final set = sets.first! as Map<String, Object?>;
    set['load'] = {'type': 'magic_load'};
    expect(
      () => const WorkspaceProgramCodec().decodeDefinition(
        jsonEncode(unknownPrimitive),
      ),
      throwsA(isA<WorkspaceProgramFormatException>()),
    );
  });
}

WorkspaceProgram _ppl() => const WorkspaceProgram(
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
          ],
        ),
        SessionDefinition(
          id: MovementId('pull'),
          role: 'pull',
          blocks: [
            BlockDefinition(
              id: 'pull-ups',
              role: 'assistance',
              movementId: MovementId('pull_up'),
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
                  load: TrainingMaxPercentageLoad(Percentage(7500)),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
