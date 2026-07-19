import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';

void main() {
  final t0 = DateTime.utc(2026, 7, 20, 8);

  WorkoutExecution planned() => WorkoutExecution(
    sessionId: 'session-1',
    sets: const [
      SetOutcome(setId: 'set-1'),
      SetOutcome(setId: 'set-2'),
    ],
  );

  test('executes, rests, pauses, resumes and completes every set', () {
    var execution = planned()
        .ready(t0)
        .start(t0.add(const Duration(minutes: 1)));
    execution = execution.recordActiveSet(
      status: SetOutcomeStatus.success,
      at: t0.add(const Duration(minutes: 2)),
      actualRepetitions: 5,
      actualLoad: 80,
      rpe: 8,
      notes: 'clean',
    );
    execution = execution.beginRest(
      t0.add(const Duration(minutes: 5)),
      t0.add(const Duration(minutes: 2)),
    );
    expect(execution.state, WorkoutExecutionState.resting);
    execution = execution.pause(t0.add(const Duration(minutes: 3)));
    expect(execution.pausedFrom, WorkoutExecutionState.resting);
    execution = execution.resume(t0.add(const Duration(minutes: 4)));
    execution = execution.endRest(t0.add(const Duration(minutes: 5)));
    execution = execution.recordActiveSet(
      status: SetOutcomeStatus.failure,
      at: t0.add(const Duration(minutes: 6)),
      actualRepetitions: 3,
      actualLoad: 82.5,
    );
    execution = execution.complete(t0.add(const Duration(minutes: 7)));

    expect(execution.state, WorkoutExecutionState.completed);
    expect(execution.sets.map((set) => set.status), [
      SetOutcomeStatus.success,
      SetOutcomeStatus.failure,
    ]);
    expect(execution.reversibleSetIndexes, isEmpty);
  });

  test('undo affects only the last reversible validation', () {
    var execution = planned().start(t0);
    execution = execution.recordActiveSet(
      status: SetOutcomeStatus.success,
      at: t0.add(const Duration(minutes: 1)),
      actualRepetitions: 5,
      actualLoad: 80,
    );
    execution = execution.recordActiveSet(
      status: SetOutcomeStatus.skipped,
      at: t0.add(const Duration(minutes: 2)),
    );

    execution = execution.undoLastOutcome(t0.add(const Duration(minutes: 3)));

    expect(execution.activeSetIndex, 1);
    expect(execution.sets.first.status, SetOutcomeStatus.success);
    expect(execution.sets.last.status, SetOutcomeStatus.pending);
    expect(execution.reversibleSetIndexes, [0]);
  });

  test('closed states reject editing and undo', () {
    final abandoned = planned()
        .start(t0)
        .abandon(t0.add(const Duration(minutes: 1)));
    expect(
      () => abandoned.updateNotes('late', t0.add(const Duration(minutes: 2))),
      throwsStateError,
    );
    expect(
      () => abandoned.undoLastOutcome(t0.add(const Duration(minutes: 2))),
      throwsStateError,
    );
    expect(planned().ready(t0).skip(t0).state, WorkoutExecutionState.skipped);
  });

  test('validates actual values and forbids premature completion', () {
    final execution = planned().start(t0);
    expect(() => execution.complete(t0), throwsStateError);
    expect(
      () => execution.recordActiveSet(
        status: SetOutcomeStatus.success,
        at: t0,
        actualRepetitions: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => execution.recordActiveSet(
        status: SetOutcomeStatus.success,
        at: t0,
        rpe: 11,
      ),
      throwsArgumentError,
    );
  });

  test('does not read the system clock', () {
    final execution = planned().start(t0).updateNotes('persist me', t0);
    expect(execution.updatedAt, t0);
    expect(execution.notes, 'persist me');
  });

  test('rejects malformed executions and invalid state actions', () {
    expect(
      () => WorkoutExecution(
        sessionId: '',
        sets: const [SetOutcome(setId: 'a')],
      ),
      throwsArgumentError,
    );
    expect(
      () => WorkoutExecution(
        sessionId: 'duplicate',
        sets: const [
          SetOutcome(setId: 'a'),
          SetOutcome(setId: 'a'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => WorkoutExecution(
        sessionId: 'index',
        sets: const [SetOutcome(setId: 'a')],
        activeSetIndex: 2,
      ),
      throwsArgumentError,
    );
    expect(
      () => const SetOutcome(
        setId: 'a',
      ).record(status: SetOutcomeStatus.pending, recordedAt: t0),
      throwsArgumentError,
    );
    final active = planned().start(t0);
    expect(() => active.beginRest(t0, t0), throwsArgumentError);
    expect(() => planned().pause(t0), throwsStateError);
    expect(() => active.skip(t0), throwsStateError);
    final recorded = active.recordActiveSet(
      status: SetOutcomeStatus.success,
      at: t0,
      actualRepetitions: 5,
      actualLoad: 80,
    );
    expect(
      () => WorkoutExecution(
        sessionId: recorded.sessionId,
        sets: recorded.sets,
        state: WorkoutExecutionState.activeSet,
        activeSetIndex: 0,
      ).recordActiveSet(status: SetOutcomeStatus.success, at: t0),
      throwsStateError,
    );
  });
}
