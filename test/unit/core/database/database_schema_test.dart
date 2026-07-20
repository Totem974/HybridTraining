import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/database_schema.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/workout_runtime/data/sqlite_workout_execution_repository.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';
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
        final execution = await SqliteWorkoutExecutionRepository(
          localDatabase: local,
        ).load('session-1');
        expect(execution?.state, WorkoutExecutionState.activeSet);
        expect(execution?.activeSetIndex, 0);
        expect(execution?.sets, [
          allOf(
            isA<SetOutcome>(),
            predicate<SetOutcome>(
              (set) => set.status == SetOutcomeStatus.success,
            ),
            predicate<SetOutcome>((set) => set.actualRepetitions == 5),
            predicate<SetOutcome>((set) => set.actualLoad == 80.0),
          ),
        ]);
      }
    });
  }

  for (final legacyStatus in const [
    'planned',
    'started',
    'completed',
    'abandoned',
    'skipped',
  ]) {
    test('v3 migration preserves $legacyStatus session without sets', () async {
      final database = await _v3Database();
      addTearDown(database.close);
      await _seedV3Session(database, status: legacyStatus);
      final legacySessions = await database.query('workout_runtime_sessions');

      await DatabaseSchema.createV4(database);
      await DatabaseSchema.migrateV3RuntimeToV4(database);

      expect(await database.query('workout_runtime_sessions'), legacySessions);
      expect(await database.query('workout_executions'), isEmpty);
      expect(await database.query('workout_set_outcomes'), isEmpty);
      expect(await database.query('workout_execution_events'), isEmpty);
    });
  }

  for (final statusMapping in const {
    'planned': 'planned',
    'started': 'activeSet',
    'completed': 'completed',
    'abandoned': 'abandoned',
    'skipped': 'skipped',
  }.entries) {
    test('v3 migration maps ${statusMapping.key} session with a set', () async {
      final database = await _v3Database();
      addTearDown(database.close);
      await _seedV3Session(database, status: statusMapping.key, setCount: 1);

      await DatabaseSchema.createV4(database);
      await DatabaseSchema.migrateV3RuntimeToV4(database);

      expect(await database.query('workout_executions'), [
        allOf(
          containsPair('session_id', 'session-1'),
          containsPair('state', statusMapping.value),
          containsPair('active_set_index', 0),
        ),
      ]);
      expect(await database.query('workout_execution_events'), [
        allOf(
          containsPair('session_id', 'session-1'),
          containsPair('event_type', 'migratedFromV3'),
        ),
      ]);
    });
  }

  test('v3 migration derives cursors and prefers set performance', () async {
    final database = await _v3Database();
    addTearDown(database.close);
    await _seedV3Session(database, status: 'started', setCount: 2);
    await database.insert('workout_activities', {
      'id': 'prescription-0',
      'session_block_id': 'session-block-1',
      'sequence': 0,
      'label': 'Legacy activity',
      'target_type': 'setsRepsLoad',
      'target_json': '{}',
      'status': 'failure',
      'result_json': '{"completedReps":2,"actualLoad":60.0}',
      'updated_at': '2026-07-19T10:00:00.000Z',
    });
    await database.insert('set_performances', {
      'id': 'performance-1',
      'prescription_id': 'prescription-0',
      'result': 'success',
      'completed_reps': 5,
      'actual_load': 80.0,
      'notes': 'authoritative',
      'recorded_at': '2026-07-19T10:01:00.000Z',
    });

    await DatabaseSchema.createV4(database);
    await DatabaseSchema.migrateV3RuntimeToV4(database);

    expect(await database.query('workout_executions'), [
      allOf(
        containsPair('active_set_index', 1),
        containsPair('reversible_stack_json', '[0]'),
      ),
    ]);
    expect(await database.query('workout_set_outcomes'), [
      allOf(
        containsPair('prescription_id', 'prescription-0'),
        containsPair('status', 'success'),
        containsPair('actual_repetitions', 5),
        containsPair('actual_load', 80.0),
      ),
      containsPair('status', 'pending'),
    ]);
    expect(await database.query('workout_runtime_sessions'), hasLength(1));
    expect(await database.query('workout_activities'), hasLength(1));
  });

  test('v3 migration uses last cursor when every set is completed', () async {
    final database = await _v3Database();
    addTearDown(database.close);
    await _seedV3Session(database, status: 'completed', setCount: 2);
    for (var index = 0; index < 2; index++) {
      await database.insert('set_performances', {
        'id': 'performance-$index',
        'prescription_id': 'prescription-$index',
        'result': 'success',
        'completed_reps': 5,
        'notes': '',
        'recorded_at': '2026-07-19T10:0${index + 1}:00.000Z',
      });
    }
    await DatabaseSchema.createV4(database);
    await DatabaseSchema.migrateV3RuntimeToV4(database);

    expect(
      (await database.query('workout_executions')).single,
      allOf(
        containsPair('active_set_index', 1),
        containsPair('reversible_stack_json', '[0,1]'),
      ),
    );
    expect(await database.query('workout_set_outcomes'), hasLength(2));
    expect(await database.query('workout_execution_events'), hasLength(1));
  });

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

  for (final transition in _atomicUpgradeTransitions) {
    test(
      'v${transition.sourceVersion} to v${transition.targetVersion} upgrade is atomic and restorable',
      () async {
        final temporary = await Directory.systemTemp.createTemp('db-atomic-');
        addTearDown(() => temporary.delete(recursive: true));
        final path = '${temporary.path}/atomic.db';
        var database = await _createVersionedDatabase(
          path,
          transition.sourceVersion,
        );
        addTearDown(() async {
          if (database.isOpen) await database.close();
        });
        await database.insert('app_metadata', {
          'key': 'atomicity-sentinel',
          'value': 'v${transition.sourceVersion}',
        });
        if (transition.sourceVersion == 3) {
          await _seedV3Session(database, status: 'started', setCount: 1);
        }
        await database.close();

        await expectLater(
          databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: transition.targetVersion,
              onUpgrade: (db, oldVersion, newVersion) async {
                await DatabaseSchema.migrate(db, oldVersion, newVersion);
                throw StateError('simulated late upgrade failure');
              },
            ),
          ),
          throwsA(isA<StateError>()),
        );

        database = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(readOnly: true),
        );
        expect(await database.getVersion(), transition.sourceVersion);
        expect(await database.query('app_metadata'), [
          {
            'key': 'atomicity-sentinel',
            'value': 'v${transition.sourceVersion}',
          },
        ]);
        expect(
          await _tables(database),
          isNot(contains(anyOf(transition.tables))),
        );
        expect(
          await _indexes(database),
          isNot(contains(anyOf(transition.indexes))),
        );
        for (final entry in transition.columns.entries) {
          expect(
            await _columns(database, entry.key),
            isNot(contains(anyOf(entry.value))),
          );
        }
        if (transition.sourceVersion == 3) {
          expect(
            await database.query('workout_runtime_sessions'),
            hasLength(1),
          );
          expect(await database.query('set_prescriptions'), hasLength(1));
        }
        await database.close();

        database = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: transition.targetVersion,
            onUpgrade: DatabaseSchema.migrate,
          ),
        );
        expect(await database.getVersion(), transition.targetVersion);
        expect(await _tables(database), containsAll(transition.tables));
        expect(await _indexes(database), containsAll(transition.indexes));
        for (final entry in transition.columns.entries) {
          expect(await _columns(database, entry.key), containsAll(entry.value));
        }
        expect(await database.query('app_metadata'), [
          {
            'key': 'atomicity-sentinel',
            'value': 'v${transition.sourceVersion}',
          },
        ]);
        if (transition.sourceVersion == 3) {
          expect(
            await database.query('workout_runtime_sessions'),
            hasLength(1),
          );
          expect(await database.query('set_prescriptions'), hasLength(1));
          expect(await database.query('workout_executions'), hasLength(1));
          expect(await database.query('workout_set_outcomes'), hasLength(1));
          expect(
            await database.query('workout_execution_events'),
            hasLength(1),
          );
        }
      },
    );
  }
}

Future<Set<Object?>> _tables(Database database) async =>
    (await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();

Future<Set<Object?>> _indexes(Database database) async =>
    (await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    )).map((row) => row['name']).toSet();

Future<Set<Object?>> _columns(Database database, String table) async =>
    (await database.rawQuery(
      'PRAGMA table_info($table)',
    )).map((row) => row['name']).toSet();

Future<Database> _v3Database() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    version: 3,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await DatabaseSchema.createV1(db);
      await DatabaseSchema.createV2(db);
      await DatabaseSchema.createV3(db);
    },
  ),
);

Future<Database> _createVersionedDatabase(String path, int version) =>
    databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, createdVersion) async {
          await DatabaseSchema.createV1(db);
          await DatabaseSchema.createV2(db);
          if (createdVersion >= 3) await DatabaseSchema.createV3(db);
          if (createdVersion >= 4) await DatabaseSchema.createV4(db);
        },
      ),
    );

class _AtomicUpgradeTransition {
  const _AtomicUpgradeTransition(
    this.sourceVersion,
    this.targetVersion,
    this.tables,
    this.indexes, [
    this.columns = const {},
  ]);

  final int sourceVersion;
  final int targetVersion;
  final List<String> tables;
  final List<String> indexes;
  final Map<String, List<String>> columns;
}

const _atomicUpgradeTransitions = [
  _AtomicUpgradeTransition(
    2,
    3,
    [
      'workout_runtime_sessions',
      'workout_runtime_blocks',
      'workout_activities',
    ],
    ['workout_activities_block_idx'],
  ),
  _AtomicUpgradeTransition(
    3,
    4,
    ['workout_executions', 'workout_set_outcomes', 'workout_execution_events'],
    ['workout_outcomes_session_idx', 'workout_events_session_idx'],
  ),
  _AtomicUpgradeTransition(
    4,
    5,
    [
      'activity_prescriptions',
      'activity_results',
      'training_max_timeline',
      'plan_amendments',
      'plan_transitions_v5',
      'planned_events_v5',
    ],
    [
      'activity_prescriptions_block_idx',
      'tm_timeline_plan_idx',
      'plan_amendments_plan_idx',
    ],
    {
      'training_plans': ['source_edition', 'ruleset_generation'],
      'training_blocks': [
        'block_type',
        'ruleset_role',
        'seventh_week_purpose',
        'programming_block_number',
      ],
      'plan_training_cycles': ['programming_cycle_number'],
      'plan_training_sessions': ['programming_week_number', 'session_position'],
    },
  ),
];

Future<void> _seedV3Session(
  Database database, {
  required String status,
  int setCount = 0,
}) async {
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
    'status': switch (status) {
      'started' => 'started',
      'completed' => 'complete',
      'abandoned' || 'skipped' => 'cancelled',
      _ => 'planned',
    },
  });
  await database.insert('workout_runtime_sessions', {
    'session_id': 'session-1',
    'status': status,
    'active_block_sequence': 0,
    'notes': 'Preserved',
    'updated_at': at,
  });
  if (setCount == 0) return;
  await database.insert('session_blocks', {
    'id': 'session-block-1',
    'session_id': 'session-1',
    'sequence': 0,
    'kind': 'main',
    'rule_provenance_json': '{}',
  });
  for (var index = 0; index < setCount; index++) {
    await database.insert('set_prescriptions', {
      'id': 'prescription-$index',
      'session_block_id': 'session-block-1',
      'sequence': index,
      'training_max': 100.0,
      'percentage': .8,
      'unrounded_load': 80.0,
      'rounding_increment': 2.5,
      'prescribed_load': 80.0,
      'prescribed_reps': 5,
      'prescription_json': '{}',
      'rule_provenance_json': '{}',
    });
  }
}

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
