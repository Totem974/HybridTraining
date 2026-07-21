import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/data/sqlite_cycle_web_draft_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('round-trips one profile-scoped draft in generation_drafts', () async {
    final temporary = await Directory.systemTemp.createTemp('cycle-web-draft-');
    addTearDown(() => temporary.delete(recursive: true));
    final database = SqliteDatabaseFile(
      fileName: 'workspace.db',
      version: WorkspaceDatabaseSchema.version,
      onCreate: WorkspaceDatabaseSchema.create,
      onUpgrade: WorkspaceDatabaseSchema.upgrade,
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/workspace.db',
    );
    addTearDown(database.close);
    final db = await database.open();
    await db.insert('profiles', {
      'id': 'profile-1',
      'display_name': 'Test',
      'unit': 'kg',
      'global_tm_ratio_basis_points': 9000,
      'rounding_increment_centi_units': 250,
    });
    final repository = SqliteCycleWebDraftRepository(
      databaseFile: database,
      draftId: 'cycle-web',
      profileId: 'profile-1',
      now: () => DateTime.utc(2026, 7, 21, 12),
    );
    expect(await repository.load(), isNull);

    await repository.save(
      const CycleEditorState(
        templateId: 'classic',
        variantId: 'four_day',
        values: {
          'include_deload': true,
          'percentage_by_movement': {'squat': 5000},
        },
      ),
    );
    final loaded = await repository.load();
    expect(loaded!.templateId, 'classic');
    expect(loaded.variantId, 'four_day');
    expect(loaded.values['include_deload'], isTrue);
    expect(loaded.values['percentage_by_movement'], {'squat': 5000});
    final row = (await db.query('generation_drafts')).single;
    expect(row['updated_at'], '2026-07-21T12:00:00.000Z');
  });
}
