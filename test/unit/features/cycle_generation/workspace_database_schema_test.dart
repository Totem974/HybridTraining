import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('workspace.db stores the vertical-slice user inputs', () async {
    final directory = await Directory.systemTemp.createTemp('workspace-db-');
    addTearDown(() => directory.delete(recursive: true));
    final file = SqliteDatabaseFile(
      fileName: 'workspace.db',
      version: WorkspaceDatabaseSchema.version,
      onCreate: WorkspaceDatabaseSchema.create,
      onUpgrade: WorkspaceDatabaseSchema.upgrade,
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

  test(
    'migration v3 to v4 adds configurations without changing data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'workspace-db-v3-v4-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/workspace.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (database, version) async {
            await WorkspaceDatabaseSchema.create(database, version);
            await database.execute('DROP TABLE cycle_configurations');
          },
        ),
      );
      await legacy.insert('profiles', {
        'id': 'existing-profile',
        'display_name': 'Existing Athlete',
        'unit': 'kg',
        'global_tm_ratio_basis_points': 9000,
        'rounding_increment_centi_units': 250,
      });
      await legacy.close();

      final file = SqliteDatabaseFile(
        fileName: 'workspace.db',
        version: WorkspaceDatabaseSchema.version,
        onCreate: WorkspaceDatabaseSchema.create,
        onUpgrade: WorkspaceDatabaseSchema.upgrade,
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(file.close);
      final migrated = await file.open();

      expect(await migrated.query('profiles'), hasLength(1));
      expect(
        await migrated.rawQuery(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'cycle_configurations'",
        ),
        hasLength(1),
      );
    },
  );

  test('cycle configuration schema creation is idempotent', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workspace-db-idempotent-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = await databaseFactoryFfi.openDatabase(
      '${directory.path}/workspace.db',
    );
    addTearDown(database.close);
    await database.execute('''CREATE TABLE profiles(
      id TEXT PRIMARY KEY, display_name TEXT NOT NULL, unit TEXT NOT NULL,
      global_tm_ratio_basis_points INTEGER NOT NULL,
      rounding_increment_centi_units INTEGER NOT NULL)''');

    await createCycleConfigurationTables(database);
    await createCycleConfigurationTables(database);

    expect(
      await database.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'index' "
        "AND name = 'cycle_configurations_profile_updated_idx'",
      ),
      hasLength(1),
    );
  });
}
