import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/database_schema.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('empty database creates v1 to v3 tables with constraints', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await DatabaseSchema.createV1(db);
          await DatabaseSchema.createV2(db);
          await DatabaseSchema.createV3(db);
        },
      ),
    );
    addTearDown(database.close);
    final names = (await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();
    expect(
      names,
      containsAll({
        'training_cycles',
        'training_sets',
        'training_plans',
        'training_blocks',
        'plan_training_cycles',
        'plan_training_sessions',
        'session_blocks',
        'set_prescriptions',
        'set_performances',
        'plan_events',
        'program_definition_snapshots',
        'workout_runtime_sessions',
        'workout_runtime_blocks',
        'workout_activities',
      }),
    );
  });

  test('v1 to v3 migration preserves legacy rows', () async {
    final temporary = await Directory.systemTemp.createTemp('db-v1-v2-');
    addTearDown(() => temporary.delete(recursive: true));
    final path = '${temporary.path}/migration.db';
    var database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => DatabaseSchema.createV1(db),
      ),
    );
    await database.insert('app_metadata', {'key': 'legacy', 'value': 'kept'});
    await database.close();

    final local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    database = await local.open();
    addTearDown(local.close);
    expect(await database.query('app_metadata'), [
      {'key': 'legacy', 'value': 'kept'},
    ]);
    expect(await database.query('training_plans'), isEmpty);
    expect(await database.query('workout_runtime_sessions'), isEmpty);
    expect(await database.getVersion(), 3);
  });

  test('interrupted migration rolls back and leaves v1 restorable', () async {
    final temporary = await Directory.systemTemp.createTemp('db-rollback-');
    addTearDown(() => temporary.delete(recursive: true));
    final path = '${temporary.path}/rollback.db';
    var database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => DatabaseSchema.createV1(db),
      ),
    );
    await database.insert('app_metadata', {'key': 'legacy', 'value': 'kept'});
    await database.close();

    await expectLater(
      databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, oldVersion, newVersion) async {
            await db.execute('CREATE TABLE migration_probe (id TEXT)');
            throw StateError('simulated interruption');
          },
        ),
      ),
      throwsA(isA<StateError>()),
    );
    database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    addTearDown(database.close);
    expect(await database.getVersion(), 1);
    expect(await database.query('app_metadata'), [
      {'key': 'legacy', 'value': 'kept'},
    ]);
    final probe = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE name = 'migration_probe'",
    );
    expect(probe, isEmpty);
  });

  test('unknown migration paths fail explicitly', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);
    await expectLater(
      DatabaseSchema.migrate(database, 0, 2),
      throwsA(isA<StateError>()),
    );
  });
}
