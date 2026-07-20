import 'dart:convert';
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

  for (final terminalState in const [
    WorkoutExecutionState.completed,
    WorkoutExecutionState.abandoned,
    WorkoutExecutionState.skipped,
  ]) {
    test(
      '${terminalState.name} execution cannot be reopened or altered',
      () async {
        final terminal = await _closeExecution(repository, terminalState);
        final database = await local.open();
        final executionBefore = await database.query('workout_executions');
        final outcomesBefore = await database.query(
          'workout_set_outcomes',
          orderBy: 'sequence',
        );
        final eventsBefore = await database.query(
          'workout_execution_events',
          orderBy: 'sequence',
        );

        await expectLater(
          repository.mutate(
            'session',
            eventType: 'forgedReopen',
            action: (current) => _replaceExecution(
              current,
              state: WorkoutExecutionState.activeSet,
            ),
          ),
          throwsStateError,
        );
        final alteredSets = [...terminal.sets];
        alteredSets[0] = const SetOutcome(setId: 'set-1');
        await expectLater(
          repository.mutate(
            'session',
            eventType: 'forgedOutcome',
            action: (current) => _replaceExecution(current, sets: alteredSets),
          ),
          throwsStateError,
        );

        expect(await database.query('workout_executions'), executionBefore);
        expect(
          await database.query('workout_set_outcomes', orderBy: 'sequence'),
          outcomesBefore,
        );
        expect(
          await database.query('workout_execution_events', orderBy: 'sequence'),
          eventsBefore,
        );
      },
    );
  }

  test(
    'direct construction cannot forge an invalid state transition',
    () async {
      await repository.create('session');
      final at = DateTime.utc(2026, 7, 20, 10);
      await repository.mutate(
        'session',
        eventType: 'started',
        action: (current) => current.start(at),
      );
      final database = await local.open();
      final eventsBefore = await database.query('workout_execution_events');

      await expectLater(
        repository.mutate(
          'session',
          eventType: 'forgedReady',
          action: (current) =>
              _replaceExecution(current, state: WorkoutExecutionState.ready),
        ),
        throwsStateError,
      );

      expect(
        (await repository.load('session'))?.state,
        WorkoutExecutionState.activeSet,
      );
      expect(await database.query('workout_execution_events'), eventsBefore);
    },
  );

  test('journal is derived from the mutation and no-op is rejected', () async {
    await repository.create('session');
    final at = DateTime.utc(2026, 7, 20, 10);
    await repository.mutate(
      'session',
      eventType: 'forgedCompleted',
      payload: const {'forged': true},
      action: (current) => current.updateNotes('Canonical note', at),
    );
    final database = await local.open();
    final events = await database.query(
      'workout_execution_events',
      orderBy: 'sequence',
    );
    expect(events.last['event_type'], 'notesUpdated');
    expect(events.last['payload_json'], '{"notes":"Canonical note"}');

    await expectLater(
      repository.mutate(
        'session',
        eventType: 'forgedNoOp',
        action: (current) => current,
      ),
      throwsStateError,
    );
    expect(await database.query('workout_execution_events'), events);
  });

  test(
    'result journal preserves values after undo and rest end is explicit',
    () async {
      await repository.create('session');
      final at = DateTime.utc(2026, 7, 20, 10);
      await repository.mutate(
        'session',
        eventType: 'ignored',
        action: (current) => current.start(at),
      );
      await repository.mutate(
        'session',
        eventType: 'ignored',
        action: (current) => current.beginRest(
          at.add(const Duration(minutes: 2)),
          at.add(const Duration(minutes: 1)),
        ),
      );
      await repository.mutate(
        'session',
        eventType: 'ignored',
        action: (current) =>
            current.endRest(at.add(const Duration(minutes: 2))),
      );
      final recordedAt = at.add(const Duration(minutes: 3));
      await repository.mutate(
        'session',
        eventType: 'ignored',
        action: (current) => current.recordActiveSet(
          status: SetOutcomeStatus.success,
          actualRepetitions: 5,
          actualLoad: 102.5,
          rpe: 8.5,
          notes: 'Fictitious canonical result',
          at: recordedAt,
        ),
      );
      await repository.mutate(
        'session',
        eventType: 'ignored',
        action: (current) =>
            current.undoLastOutcome(at.add(const Duration(minutes: 4))),
      );

      final database = await local.open();
      final events = await database.query(
        'workout_execution_events',
        orderBy: 'sequence',
      );
      expect(events.map((event) => event['event_type']), contains('restEnded'));
      final recorded = events.singleWhere(
        (event) => event['event_type'] == 'setRecorded',
      );
      expect(jsonDecode(recorded['payload_json']! as String), {
        'prescriptionId': 'set-1',
        'status': 'success',
        'actualRepetitions': 5,
        'actualLoad': 102.5,
        'rpe': 8.5,
        'notes': 'Fictitious canonical result',
        'recordedAt': recordedAt.toIso8601String(),
        'actualTotalRepetitions': null,
        'actualDurationSeconds': null,
        'actualDistanceMeters': null,
        'actualRounds': null,
        'completed': null,
      });
      expect(events.last['event_type'], 'lastSetUndone');
      expect((await repository.load('session'))!.sets.first.isPending, isTrue);
    },
  );

  test('invalid mutation timestamps and expired rest roll back', () async {
    await repository.create('session');
    final at = DateTime.utc(2026, 7, 20, 10);
    final started = await repository.mutate(
      'session',
      eventType: 'started',
      action: (current) => current.start(at),
    );
    final database = await local.open();
    final executionBefore = await database.query('workout_executions');
    final eventsBefore = await database.query('workout_execution_events');

    final invalidValues = <WorkoutExecution>[
      WorkoutExecution(
        sessionId: started.sessionId,
        sets: started.sets,
        state: started.state,
        activeSetIndex: started.activeSetIndex,
        notes: 'Missing time',
      ),
      WorkoutExecution(
        sessionId: started.sessionId,
        sets: started.sets,
        state: started.state,
        activeSetIndex: started.activeSetIndex,
        notes: 'Earlier time',
        updatedAt: at.subtract(const Duration(seconds: 1)),
      ),
      WorkoutExecution(
        sessionId: started.sessionId,
        sets: started.sets,
        state: WorkoutExecutionState.resting,
        activeSetIndex: started.activeSetIndex,
        restUntil: at,
        updatedAt: at,
      ),
    ];
    for (final invalid in invalidValues) {
      await expectLater(
        repository.mutate(
          'session',
          eventType: 'forgedTime',
          action: (_) => invalid,
        ),
        throwsStateError,
      );
    }
    expect(await database.query('workout_executions'), executionBefore);
    expect(await database.query('workout_execution_events'), eventsBefore);
  });

  test('create rejects every closed session hierarchy', () async {
    final database = await local.open();
    final cases = <(String, String, String)>[
      ('plan_training_sessions', 'session', 'complete'),
      ('plan_training_sessions', 'session', 'cancelled'),
      ('plan_training_cycles', 'cycle', 'complete'),
      ('plan_training_cycles', 'cycle', 'cancelled'),
      ('training_blocks', 'block', 'complete'),
      ('training_blocks', 'block', 'cancelled'),
      ('training_plans', 'plan', 'complete'),
      ('training_plans', 'plan', 'cancelled'),
    ];
    for (final entry in cases) {
      await database.update(
        entry.$1,
        {'status': entry.$3},
        where: 'id = ?',
        whereArgs: [entry.$2],
      );
      await expectLater(repository.create('session'), throwsStateError);
      expect(await database.query('workout_executions'), isEmpty);
      expect(await database.query('workout_execution_events'), isEmpty);
      await database.update(
        entry.$1,
        {'status': entry.$1 == 'plan_training_sessions' ? 'planned' : 'active'},
        where: 'id = ?',
        whereArgs: [entry.$2],
      );
    }
  });

  test(
    'mutation rejects a hierarchy closed after execution creation',
    () async {
      await repository.create('session');
      final database = await local.open();
      final cases = <(String, String, String)>[
        ('plan_training_sessions', 'session', 'complete'),
        ('plan_training_cycles', 'cycle', 'complete'),
        ('training_blocks', 'block', 'cancelled'),
        ('training_plans', 'plan', 'complete'),
      ];
      for (final entry in cases) {
        await database.update(
          entry.$1,
          {'status': entry.$3},
          where: 'id = ?',
          whereArgs: [entry.$2],
        );
        await expectLater(
          repository.mutate(
            'session',
            eventType: 'forbidden',
            action: (current) => current.updateNotes(
              'must not persist',
              DateTime.utc(2026, 7, 20, 14),
            ),
          ),
          throwsStateError,
        );
        expect((await repository.load('session'))?.notes, isEmpty);
        expect(await database.query('workout_execution_events'), hasLength(1));
        await database.update(
          entry.$1,
          {
            'status': entry.$1 == 'plan_training_sessions'
                ? 'planned'
                : 'active',
          },
          where: 'id = ?',
          whereArgs: [entry.$2],
        );
      }
    },
  );

  test(
    'mutation cannot substitute a prescription from another session',
    () async {
      await repository.create('session');
      final database = await local.open();
      final outcomesBefore = await database.query(
        'workout_set_outcomes',
        orderBy: 'session_id, sequence',
      );
      final eventsBefore = await database.query(
        'workout_execution_events',
        orderBy: 'session_id, sequence',
      );
      await expectLater(
        repository.mutate(
          'session',
          eventType: 'setRecorded',
          action: (current) => WorkoutExecution(
            sessionId: current.sessionId,
            sets: [
              const SetOutcome(setId: 'set-other'),
              current.sets[1],
            ],
            state: current.state,
            activeSetIndex: current.activeSetIndex,
            notes: current.notes,
            reversibleSetIndexes: current.reversibleSetIndexes,
            updatedAt: DateTime.utc(2026, 7, 20, 15),
          ),
        ),
        throwsStateError,
      );
      expect(
        await database.query(
          'workout_set_outcomes',
          orderBy: 'session_id, sequence',
        ),
        outcomesBefore,
      );
      expect(await database.query('activity_results'), isEmpty);
      expect(
        await database.query(
          'workout_execution_events',
          orderBy: 'session_id, sequence',
        ),
        eventsBefore,
      );
      expect(
        (await repository.load('session'))?.sets.map((item) => item.setId),
        ['set-1', 'set-2'],
      );
    },
  );

  test('rejects an outcome linked to the wrong owning session', () async {
    final database = await local.open();
    await database.insert('workout_set_outcomes', {
      'prescription_id': 'set-1',
      'session_id': 'other-session',
      'sequence': 0,
      'status': 'success',
      'actual_repetitions': 99,
      'notes': 'Fictitious inconsistent result',
      'updated_at': '2026-07-20T16:00:00.000Z',
    });

    await expectLater(repository.create('session'), throwsStateError);

    expect(await database.query('workout_executions'), isEmpty);
    expect(await database.query('workout_execution_events'), isEmpty);
    expect(await database.query('workout_set_outcomes'), hasLength(1));
  });

  test('orders colliding prescription kinds deterministically', () async {
    final database = await local.open();
    await database.insert('activity_prescriptions', {
      'id': 'activity-collision',
      'session_block_id': 'session-block',
      'sequence': 0,
      'movement_or_activity_id': 'fictitious-collision',
      'target_type': 'setsRepsLoad',
      'target_json': '{}',
      'prescription_kind': 'assistance',
      'rule_id': 'TEST-COLLISION',
      'source_edition': 'forever',
      'ruleset_generation': 'forever',
      'source_reference_json': '{}',
    });

    final created = await repository.create('session');

    expect(created.sets.map((item) => item.setId), [
      'activity-collision',
      'set-1',
      'set-2',
    ]);
    expect(created.sets.map((item) => item.storage), [
      ExecutionItemStorage.genericActivity,
      ExecutionItemStorage.legacySet,
      ExecutionItemStorage.legacySet,
    ]);
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

Future<WorkoutExecution> _closeExecution(
  SqliteWorkoutExecutionRepository repository,
  WorkoutExecutionState state,
) async {
  final at = DateTime.utc(2026, 7, 20, 10);
  await repository.create('session');
  if (state == WorkoutExecutionState.skipped) {
    return repository.mutate(
      'session',
      eventType: 'skipped',
      action: (current) => current.skip(at),
    );
  }
  await repository.mutate(
    'session',
    eventType: 'started',
    action: (current) => current.start(at),
  );
  if (state == WorkoutExecutionState.abandoned) {
    return repository.mutate(
      'session',
      eventType: 'abandoned',
      action: (current) => current.abandon(at.add(const Duration(minutes: 1))),
    );
  }
  for (var index = 0; index < 2; index++) {
    await repository.mutate(
      'session',
      eventType: 'setRecorded',
      action: (current) => current.recordActiveSet(
        status: SetOutcomeStatus.success,
        actualRepetitions: 5,
        actualLoad: 100,
        at: at.add(Duration(minutes: index + 1)),
      ),
    );
  }
  return repository.mutate(
    'session',
    eventType: 'completed',
    action: (current) => current.complete(at.add(const Duration(minutes: 3))),
  );
}

WorkoutExecution _replaceExecution(
  WorkoutExecution current, {
  WorkoutExecutionState? state,
  List<SetOutcome>? sets,
}) => WorkoutExecution(
  sessionId: current.sessionId,
  sets: sets ?? current.sets,
  state: state ?? current.state,
  activeSetIndex: current.activeSetIndex,
  restUntil: current.restUntil,
  pausedFrom: current.pausedFrom,
  notes: current.notes,
  reversibleSetIndexes: current.reversibleSetIndexes,
  updatedAt: DateTime.utc(2026, 7, 20, 20),
);

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
    'id': 'other-session',
    'cycle_id': 'cycle',
    'sequence': 2,
    'scheduled_for': '2026-07-22',
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
    'id': 'other-session-block',
    'session_id': 'other-session',
    'sequence': 0,
    'kind': 'mainWork',
    'rule_provenance_json': '{}',
  });
  await database.insert('set_prescriptions', {
    'id': 'set-other',
    'session_block_id': 'other-session-block',
    'sequence': 0,
    'training_max': 100.0,
    'percentage': 0.65,
    'unrounded_load': 65.0,
    'rounding_increment': 2.5,
    'prescribed_load': 65.0,
    'prescribed_reps': 5,
    'prescription_json': '{}',
    'rule_provenance_json': '{}',
  });
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
