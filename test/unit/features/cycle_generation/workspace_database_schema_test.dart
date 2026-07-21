import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('workspace.db v1 stores the vertical-slice user inputs', () async {
    final directory = await Directory.systemTemp.createTemp('workspace-db-v1-');
    addTearDown(() => directory.delete(recursive: true));
    final file = SqliteDatabaseFile(
      fileName: 'workspace.db',
      version: WorkspaceDatabaseSchema.version,
      onCreate: WorkspaceDatabaseSchema.create,
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/workspace.db',
    );
    addTearDown(file.close);
    final database = await file.open();
    await database.insert('profiles', {
      'id': 'local-profile',
      'display_name': 'Fixture Athlete',
      'unit': 'kg',
      'global_tm_ratio_basis_points': 9000,
      'rounding_increment_centi_units': 250,
    });
    await database.insert('movement_maxes', {
      'profile_id': 'local-profile',
      'movement_id': 'squat',
      'input_type': 'repMax',
      'weight_centi_units': 18000,
      'repetitions': 3,
      'tm_ratio_basis_points': 8500,
    });
    await database.insert('gyms', {'id': 'home', 'name': 'Home'});
    await database.insert('bars', {
      'id': 'bar-20',
      'gym_id': 'home',
      'unit': 'kg',
      'weight_centi_units': 2000,
    });
    await database.insert('plates', {
      'gym_id': 'home',
      'unit': 'kg',
      'weight_centi_units': 2000,
      'pair_count': 2,
    });
    await database.insert('generation_drafts', {
      'id': 'draft-1',
      'profile_id': 'local-profile',
      'request_json': '{"templateId":"standard_531"}',
      'updated_at': '2026-07-21T00:00:00.000Z',
    });
    expect((await database.query('profiles')).single['unit'], 'kg');
    expect(
      (await database.query('movement_maxes')).single['input_type'],
      'repMax',
    );
    expect(await database.query('bars'), hasLength(1));
    expect(await database.query('plates'), hasLength(1));
    expect(await database.query('generation_drafts'), hasLength(1));
  });
}
