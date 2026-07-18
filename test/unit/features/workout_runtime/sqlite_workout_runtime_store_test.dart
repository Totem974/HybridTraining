import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/workout_runtime/data/sqlite_workout_runtime_store.dart';
import 'package:hybrid_training/features/workout_runtime/domain/composable_workout.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteWorkoutRuntimeStore store;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('workout-runtime-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/runtime.db',
    );
    store = SqliteWorkoutRuntimeStore(
      localDatabase: local,
      clock: () => DateTime.utc(2026, 7, 18, 10),
    );
    await _seed(local);
  });
  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test(
    'persists multi-block progress and resumes after database reopen',
    () async {
      await store.initialize(_workout());
      await store.startOrResume('session');
      await store.record(
        'warm-item',
        PrescriptionStatus.success,
        result: {'seconds': 300},
      );
      await store.navigate('session', blockSequence: 1);
      await store.setRest('main', DateTime.utc(2026, 7, 18, 10, 3));
      await store.updateNotes('session', 'Fictitious note');
      await local.close();
      final resumed = await store.load('session');
      expect(resumed?['status'], 'started');
      expect(resumed?['active_block_sequence'], 1);
      expect(resumed?['notes'], 'Fictitious note');
      final blocks = resumed?['blocks']! as List<Map<String, Object?>>;
      expect(blocks[1]['rest_until'], '2026-07-18T10:03:00.000Z');
    },
  );

  test('skip rest is atomic and creates final summary data', () async {
    await store.initialize(_workout());
    await store.startOrResume('session');
    await store.record('warm-item', PrescriptionStatus.failure);
    await store.navigate('session', blockSequence: 1);
    await store.skipRest('session');
    final value = await store.load('session');
    expect(value?['status'], 'skipped');
    final blocks = value?['blocks']! as List<Map<String, Object?>>;
    final activities = blocks
        .expand((block) => block['activities']! as List<Map<String, Object?>>)
        .toList();
    expect(activities.map((row) => row['status']), [
      'failure',
      'skipped',
      'skipped',
    ]);
  });

  test('supports edit, cancellation, abandonment and expired rest', () async {
    await store.initialize(_workout());
    await store.startOrResume('session');
    await store.record('warm-item', PrescriptionStatus.success);
    await store.editResult('warm-item', PrescriptionStatus.failure, {
      'seconds': 200,
    });
    await store.cancelResult('warm-item');
    await store.setRest('warm', DateTime.utc(2026, 7, 18, 9, 59));
    await store.abandon('session');
    final value = await store.load('session');
    expect(value?['status'], 'abandoned');
    final blocks = value?['blocks']! as List<Map<String, Object?>>;
    expect(
      DateTime.parse(
        blocks.first['rest_until']! as String,
      ).isBefore(DateTime.utc(2026, 7, 18, 10)),
      isTrue,
    );
  });

  test('SQLite failure rolls initialization back atomically', () async {
    final invalid = ComposableWorkout(
      id: 'session',
      blocks: [
        WorkoutBlock(
          id: 'warm',
          sequence: 0,
          role: WorkoutBlockRole.warmUp,
          prescriptions: const [
            WorkoutPrescription(
              id: 'duplicate',
              label: 'one',
              target: ActivityTarget(type: TargetType.completion),
            ),
          ],
        ),
        WorkoutBlock(
          id: 'main',
          sequence: 1,
          role: WorkoutBlockRole.mainWork,
          prescriptions: const [
            WorkoutPrescription(
              id: 'duplicate',
              label: 'two',
              target: ActivityTarget(type: TargetType.completion),
            ),
          ],
        ),
      ],
    );
    await expectLater(
      store.initialize(invalid),
      throwsA(isA<DatabaseException>()),
    );
    final db = await local.open();
    expect(await db.query('workout_runtime_sessions'), isEmpty);
    expect(await db.query('workout_runtime_blocks'), isEmpty);
    expect(await db.query('workout_activities'), isEmpty);
  });
}

ComposableWorkout _workout() => ComposableWorkout(
  id: 'session',
  blocks: [
    WorkoutBlock(
      id: 'warm',
      sequence: 0,
      role: WorkoutBlockRole.warmUp,
      prescriptions: const [
        WorkoutPrescription(
          id: 'warm-item',
          label: 'Warm up',
          target: ActivityTarget(
            type: TargetType.duration,
            durationSeconds: 300,
          ),
        ),
      ],
    ),
    WorkoutBlock(
      id: 'main',
      sequence: 1,
      role: WorkoutBlockRole.mainWork,
      movementId: 'squat',
      prescriptions: const [
        WorkoutPrescription(
          id: 'main-item',
          label: 'Main',
          target: ActivityTarget(
            type: TargetType.setsRepsLoad,
            sets: 3,
            reps: 5,
            load: 100,
          ),
        ),
      ],
    ),
    WorkoutBlock(
      id: 'bench',
      sequence: 2,
      role: WorkoutBlockRole.mainWork,
      movementId: 'benchPress',
      prescriptions: const [
        WorkoutPrescription(
          id: 'bench-item',
          label: 'Bench',
          target: ActivityTarget(type: TargetType.totalReps, totalReps: 25),
        ),
      ],
    ),
  ],
);

Future<void> _seed(LocalDatabase local) async {
  final db = await local.open();
  await db.insert('athlete_profiles', {
    'id': 'athlete',
    'display_name': 'Fictitious Athlete',
    'preferred_unit': 'kg',
    'rounding_increment': 2.5,
    'created_at': '2026-07-18T00:00:00Z',
    'updated_at': '2026-07-18T00:00:00Z',
  });
  await db.insert('program_definition_snapshots', {
    'id': 'snapshot',
    'blueprint_id': 'fixture',
    'blueprint_version': 1,
    'snapshot_json': '{}',
    'rule_provenance_json': '[]',
    'created_at': '2026-07-18T00:00:00Z',
  });
  await db.insert('training_plans', {
    'id': 'plan',
    'athlete_id': 'athlete',
    'blueprint_id': 'fixture',
    'blueprint_version': 1,
    'definition_snapshot_id': 'snapshot',
    'macrocycle': 1,
    'status': 'active',
    'created_at': '2026-07-18T00:00:00Z',
  });
  await db.insert('training_blocks', {
    'id': 'plan-block',
    'plan_id': 'plan',
    'sequence': 0,
    'role': 'leader',
    'template_id': 'fixture',
    'status': 'active',
  });
  await db.insert('plan_training_cycles', {
    'id': 'cycle',
    'block_id': 'plan-block',
    'sequence': 0,
    'starts_on': '2026-07-18',
    'status': 'active',
  });
  await db.insert('plan_training_sessions', {
    'id': 'session',
    'cycle_id': 'cycle',
    'sequence': 0,
    'scheduled_for': '2026-07-18',
    'status': 'planned',
  });
  for (final entry in [
    ('warm', 0, 'warmUp', null),
    ('main', 1, 'mainWork', 'squat'),
    ('bench', 2, 'mainWork', 'benchPress'),
  ]) {
    await db.insert('session_blocks', {
      'id': entry.$1,
      'session_id': 'session',
      'sequence': entry.$2,
      'kind': entry.$3,
      'movement_id': entry.$4,
      'rule_provenance_json': '{}',
    });
  }
}
