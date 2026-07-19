import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/workout_runtime/data/sqlite_workout_execution_repository.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteWorkoutExecutionRepository repository;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('workout-execution-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/runtime.db',
    );
    repository = SqliteWorkoutExecutionRepository(localDatabase: local);
    await _seedSession(local);
  });

  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test('persists every mutation and reopens the exact execution', () async {
    final created = await repository.create('session');
    expect(created.sets.map((set) => set.setId), ['set-1', 'set-2']);

    final startedAt = DateTime.utc(2026, 7, 20, 10);
    await repository.mutate(
      'session',
      eventType: 'started',
      action: (current) => current.start(startedAt),
    );
    await repository.mutate(
      'session',
      eventType: 'setRecorded',
      payload: const {'prescriptionId': 'set-1'},
      action: (current) => current.recordActiveSet(
        status: SetOutcomeStatus.success,
        actualRepetitions: 5,
        actualLoad: 100,
        rpe: 8,
        notes: 'Fictitious result',
        at: startedAt.add(const Duration(minutes: 1)),
      ),
    );
    await repository.mutate(
      'session',
      eventType: 'paused',
      action: (current) =>
          current.pause(startedAt.add(const Duration(minutes: 2))),
    );

    await local.close();
    final reopened = await repository.load('session');
    expect(reopened?.state, WorkoutExecutionState.paused);
    expect(reopened?.pausedFrom, WorkoutExecutionState.activeSet);
    expect(reopened?.activeSetIndex, 1);
    expect(reopened?.sets.first.actualLoad, 100);
    expect(reopened?.sets.first.actualRepetitions, 5);
    final database = await local.open();
    expect(await database.query('workout_execution_events'), hasLength(4));
  });

  test('failed or duplicate action is atomic and creates no event', () async {
    await repository.create('session');
    final at = DateTime.utc(2026, 7, 20, 10);
    await repository.mutate(
      'session',
      eventType: 'started',
      action: (current) => current.start(at),
    );
    await expectLater(
      repository.mutate(
        'session',
        eventType: 'startedAgain',
        action: (current) => current.start(at),
      ),
      throwsStateError,
    );
    final database = await local.open();
    expect(await database.query('workout_execution_events'), hasLength(2));
    expect(
      (await repository.load('session'))?.state,
      WorkoutExecutionState.activeSet,
    );
  });

  test('executes generic activities and resumes partial progress', () async {
    final created = await repository.create('activity-session');
    expect(created.sets, hasLength(4));
    expect(
      created.sets.every((item) => item.kind == ExecutionItemKind.activity),
      isTrue,
    );
    final at = DateTime.utc(2026, 7, 20, 12);
    await repository.mutate(
      'activity-session',
      eventType: 'started',
      action: (current) => current.start(at),
    );
    await repository.mutate(
      'activity-session',
      eventType: 'activityRecorded',
      action: (current) => current.recordActiveSet(
        status: SetOutcomeStatus.success,
        actualTotalRepetitions: 75,
        rpe: 6,
        at: at.add(const Duration(minutes: 1)),
      ),
    );
    await repository.mutate(
      'activity-session',
      eventType: 'paused',
      action: (current) => current.pause(at.add(const Duration(minutes: 2))),
    );
    await local.close();
    final partial = await repository.load('activity-session');
    expect(partial?.state, WorkoutExecutionState.paused);
    expect(partial?.sets.first.actualTotalRepetitions, 75);

    await repository.mutate(
      'activity-session',
      eventType: 'resumed',
      action: (current) => current.resume(at.add(const Duration(minutes: 3))),
    );
    for (var index = 1; index < 4; index++) {
      await repository.mutate(
        'activity-session',
        eventType: 'activityRecorded',
        action: (current) => current.recordActiveSet(
          status: index == 3
              ? SetOutcomeStatus.skipped
              : SetOutcomeStatus.success,
          actualDurationSeconds: index == 1 ? 1200 : null,
          actualDistanceMeters: index == 2 ? 1609.344 : null,
          completed: index == 3 ? false : null,
          at: at.add(Duration(minutes: index + 3)),
        ),
      );
    }
    final completed = await repository.mutate(
      'activity-session',
      eventType: 'completed',
      action: (current) => current.complete(at.add(const Duration(minutes: 8))),
    );
    expect(completed.state, WorkoutExecutionState.completed);
    final database = await local.open();
    expect(await database.query('activity_results'), hasLength(4));
  });
}

Future<void> _seedSession(LocalDatabase local) async {
  final database = await local.open();
  const at = '2026-07-20T00:00:00.000Z';
  await database.insert('athlete_profiles', {
    'id': 'athlete',
    'display_name': 'Fictitious Athlete',
    'preferred_unit': 'kg',
    'rounding_increment': 2.5,
    'created_at': at,
    'updated_at': at,
  });
  await database.insert('program_definition_snapshots', {
    'id': 'snapshot',
    'blueprint_id': 'beginner-prep-school',
    'blueprint_version': 1,
    'snapshot_json': '{}',
    'rule_provenance_json': '{}',
    'created_at': at,
  });
  await database.insert('training_plans', {
    'id': 'plan',
    'athlete_id': 'athlete',
    'blueprint_id': 'beginner-prep-school',
    'blueprint_version': 1,
    'definition_snapshot_id': 'snapshot',
    'macrocycle': 1,
    'status': 'active',
    'created_at': at,
  });
  await database.insert('training_blocks', {
    'id': 'block',
    'plan_id': 'plan',
    'sequence': 0,
    'role': 'leader',
    'template_id': 'beginner-prep-school',
    'status': 'active',
  });
  await database.insert('plan_training_cycles', {
    'id': 'cycle',
    'block_id': 'block',
    'sequence': 0,
    'starts_on': '2026-07-20',
    'status': 'active',
  });
  await database.insert('plan_training_sessions', {
    'id': 'session',
    'cycle_id': 'cycle',
    'sequence': 0,
    'scheduled_for': '2026-07-20',
    'status': 'planned',
  });
  await database.insert('plan_training_sessions', {
    'id': 'activity-session',
    'cycle_id': 'cycle',
    'sequence': 1,
    'scheduled_for': '2026-07-21',
    'status': 'planned',
  });
  await database.insert('session_blocks', {
    'id': 'session-block',
    'session_id': 'session',
    'sequence': 0,
    'kind': 'mainWork',
    'rule_provenance_json': '{}',
  });
  for (var sequence = 0; sequence < 2; sequence++) {
    await database.insert('set_prescriptions', {
      'id': 'set-${sequence + 1}',
      'session_block_id': 'session-block',
      'sequence': sequence,
      'training_max': 100.0,
      'percentage': 0.65,
      'unrounded_load': 65.0,
      'rounding_increment': 2.5,
      'prescribed_load': 65.0,
      'prescribed_reps': 5,
      'prescription_json': '{}',
      'rule_provenance_json': '{}',
    });
  }
  await database.insert('session_blocks', {
    'id': 'activity-block',
    'session_id': 'activity-session',
    'sequence': 0,
    'kind': 'assistance',
    'rule_provenance_json': '{}',
  });
  for (final entry in const [
    ('totalRepetitions', 'warm-up'),
    ('duration', 'conditioning-duration'),
    ('distance', 'conditioning-distance'),
    ('completion', 'assistance-completion'),
  ].indexed) {
    await database.insert('activity_prescriptions', {
      'id': entry.$2.$2,
      'session_block_id': 'activity-block',
      'sequence': entry.$1,
      'movement_or_activity_id': entry.$2.$2,
      'target_type': entry.$2.$1,
      'target_json': '{}',
      'prescription_kind': 'assistance',
      'rule_id': 'TEST-${entry.$1}',
      'source_edition': 'forever',
      'ruleset_generation': 'forever',
      'source_reference_json': '{}',
    });
  }
}
