import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/database_schema.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('empty database creates v1 to v5 tables with constraints', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await DatabaseSchema.createV1(db);
          await DatabaseSchema.createV2(db);
          await DatabaseSchema.createV3(db);
          await DatabaseSchema.createV4(db);
          await DatabaseSchema.createV5(db);
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
        'workout_executions',
        'workout_set_outcomes',
        'workout_execution_events',
        'activity_prescriptions',
        'activity_results',
        'training_max_timeline',
        'plan_amendments',
        'plan_transitions_v5',
        'planned_events_v5',
      }),
    );
    expect(
      await _columns(database, 'training_plans'),
      containsAll(['source_edition', 'ruleset_generation']),
    );
    expect(
      await _columns(database, 'training_blocks'),
      containsAll([
        'block_type',
        'ruleset_role',
        'seventh_week_purpose',
        'programming_block_number',
      ]),
    );
  });

  for (final sourceVersion in [2, 3, 4]) {
    test('v$sourceVersion to v5 migration preserves existing rows', () async {
      final temporary = await Directory.systemTemp.createTemp(
        'db-v$sourceVersion-v4-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final path = '${temporary.path}/migration.db';
      var database = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: sourceVersion,
          onCreate: (db, version) async {
            await DatabaseSchema.createV1(db);
            await DatabaseSchema.createV2(db);
            if (version >= 3) await DatabaseSchema.createV3(db);
            if (version >= 4) await DatabaseSchema.createV4(db);
          },
        ),
      );
      await database.insert('app_metadata', {
        'key': 'source-version',
        'value': '$sourceVersion',
      });
      if (sourceVersion == 3) await _seedInterruptedV3Workout(database);
      await database.close();

      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      database = await local.open();
      addTearDown(local.close);

      expect(await database.getVersion(), 5);
      expect(await database.query('app_metadata'), [
        {'key': 'source-version', 'value': '$sourceVersion'},
      ]);
      expect(
        await _tables(database),
        containsAll([
          'workout_executions',
          'workout_set_outcomes',
          'workout_execution_events',
          'activity_prescriptions',
          'activity_results',
          'training_max_timeline',
          'plan_amendments',
          'plan_transitions_v5',
          'planned_events_v5',
        ]),
      );
      if (sourceVersion == 3) {
        expect(await database.query('workout_executions'), [
          containsPair('state', 'activeSet'),
        ]);
        expect(await database.query('workout_set_outcomes'), [
          allOf(
            containsPair('prescription_id', 'prescription-1'),
            containsPair('status', 'success'),
            containsPair('actual_repetitions', 5),
            containsPair('actual_load', 80.0),
          ),
        ]);
        expect(
          (await database.query(
            'workout_execution_events',
          )).single['event_type'],
          'migratedFromV3',
        );
      }
    });
  }

  test('v1 to v5 migration preserves legacy rows', () async {
    final temporary = await Directory.systemTemp.createTemp('db-v1-v5-');
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
    expect(await database.getVersion(), 5);
    expect(
      await _tables(database),
      containsAll([
        'workout_executions',
        'workout_set_outcomes',
        'workout_execution_events',
        'activity_prescriptions',
        'activity_results',
        'training_max_timeline',
        'plan_amendments',
        'plan_transitions_v5',
        'planned_events_v5',
      ]),
    );
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

Future<Set<Object?>> _tables(Database database) async =>
    (await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();

Future<Set<Object?>> _columns(Database database, String table) async =>
    (await database.rawQuery(
      'PRAGMA table_info($table)',
    )).map((row) => row['name']).toSet();

Future<void> _seedInterruptedV3Workout(Database database) async {
  const at = '2026-07-19T10:00:00.000Z';
  await database.insert('athlete_profiles', {
    'id': 'athlete-1',
    'display_name': 'Migration Athlete',
    'preferred_unit': 'kg',
    'rounding_increment': 2.5,
    'created_at': at,
    'updated_at': at,
  });
  await database.insert('program_definition_snapshots', {
    'id': 'snapshot-1',
    'blueprint_id': 'bps',
    'blueprint_version': 1,
    'snapshot_json': '{}',
    'rule_provenance_json': '{}',
    'created_at': at,
  });
  await database.insert('training_plans', {
    'id': 'plan-1',
    'athlete_id': 'athlete-1',
    'blueprint_id': 'bps',
    'blueprint_version': 1,
    'definition_snapshot_id': 'snapshot-1',
    'macrocycle': 1,
    'status': 'active',
    'created_at': at,
  });
  await database.insert('training_blocks', {
    'id': 'block-1',
    'plan_id': 'plan-1',
    'sequence': 0,
    'role': 'prep',
    'template_id': 'template-1',
    'status': 'active',
  });
  await database.insert('plan_training_cycles', {
    'id': 'cycle-1',
    'block_id': 'block-1',
    'sequence': 0,
    'starts_on': '2026-07-19',
    'status': 'active',
  });
  await database.insert('plan_training_sessions', {
    'id': 'session-1',
    'cycle_id': 'cycle-1',
    'sequence': 0,
    'scheduled_for': '2026-07-19',
    'status': 'started',
    'started_at': at,
  });
  await database.insert('session_blocks', {
    'id': 'session-block-1',
    'session_id': 'session-1',
    'sequence': 0,
    'kind': 'main',
    'rule_provenance_json': '{}',
  });
  await database.insert('set_prescriptions', {
    'id': 'prescription-1',
    'session_block_id': 'session-block-1',
    'sequence': 0,
    'training_max': 100.0,
    'percentage': .8,
    'unrounded_load': 80.0,
    'rounding_increment': 2.5,
    'prescribed_load': 80.0,
    'prescribed_reps': 5,
    'prescription_json': '{}',
    'rule_provenance_json': '{}',
  });
  await database.insert('workout_runtime_sessions', {
    'session_id': 'session-1',
    'status': 'started',
    'active_block_sequence': 0,
    'notes': 'Interrupted but resumable',
    'started_at': at,
    'updated_at': at,
  });
  await database.insert('workout_runtime_blocks', {
    'session_block_id': 'session-block-1',
    'status': 'active',
    'updated_at': at,
  });
  await database.insert('workout_activities', {
    'id': 'prescription-1',
    'session_block_id': 'session-block-1',
    'sequence': 0,
    'label': 'Migrated set',
    'target_type': 'setsRepsLoad',
    'target_json': '{}',
    'status': 'success',
    'result_json': '{"completedReps":5,"actualLoad":80.0}',
    'updated_at': at,
  });
}
