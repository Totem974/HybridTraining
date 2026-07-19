enum WorkoutExecutionState {
  planned,
  ready,
  activeSet,
  resting,
  paused,
  completed,
  abandoned,
  skipped,
}

enum SetOutcomeStatus { pending, success, failure, skipped }

enum ExecutionItemKind { loadedSet, activity }

enum ExecutionItemStorage { legacySet, genericActivity }

class SetOutcome {
  const SetOutcome({
    required this.setId,
    this.kind = ExecutionItemKind.loadedSet,
    this.storage = ExecutionItemStorage.legacySet,
    this.status = SetOutcomeStatus.pending,
    this.actualRepetitions,
    this.actualLoad,
    this.rpe,
    this.notes = '',
    this.recordedAt,
    this.actualTotalRepetitions,
    this.actualDurationSeconds,
    this.actualDistanceMeters,
    this.actualRounds,
    this.completed,
  });

  final String setId;
  final SetOutcomeStatus status;
  final ExecutionItemKind kind;
  final ExecutionItemStorage storage;
  final int? actualRepetitions;
  final double? actualLoad;
  final double? rpe;
  final String notes;
  final DateTime? recordedAt;
  final int? actualTotalRepetitions;
  final int? actualDurationSeconds;
  final double? actualDistanceMeters;
  final int? actualRounds;
  final bool? completed;

  bool get isPending => status == SetOutcomeStatus.pending;

  SetOutcome record({
    required SetOutcomeStatus status,
    required DateTime recordedAt,
    int? actualRepetitions,
    double? actualLoad,
    double? rpe,
    String notes = '',
    int? actualTotalRepetitions,
    int? actualDurationSeconds,
    double? actualDistanceMeters,
    int? actualRounds,
    bool? completed,
  }) {
    if (status == SetOutcomeStatus.pending) {
      throw ArgumentError('A recorded outcome cannot be pending.');
    }
    if ((actualRepetitions ?? 0) < 0 ||
        (actualLoad ?? 0) < 0 ||
        (actualTotalRepetitions ?? 0) < 0 ||
        (actualDurationSeconds ?? 0) < 0 ||
        (actualDistanceMeters ?? 0) < 0 ||
        (actualRounds ?? 0) < 0) {
      throw ArgumentError('Actual activity values cannot be negative.');
    }
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      throw ArgumentError.value(rpe, 'rpe', 'RPE must be between 1 and 10.');
    }
    return SetOutcome(
      setId: setId,
      kind: kind,
      storage: storage,
      status: status,
      actualRepetitions: actualRepetitions,
      actualLoad: actualLoad,
      rpe: rpe,
      notes: notes,
      recordedAt: recordedAt.toUtc(),
      actualTotalRepetitions: actualTotalRepetitions,
      actualDurationSeconds: actualDurationSeconds,
      actualDistanceMeters: actualDistanceMeters,
      actualRounds: actualRounds,
      completed: completed,
    );
  }

  SetOutcome clear() => SetOutcome(setId: setId, kind: kind, storage: storage);
}

class WorkoutExecution {
  WorkoutExecution({
    required this.sessionId,
    required List<SetOutcome> sets,
    this.state = WorkoutExecutionState.planned,
    this.activeSetIndex = 0,
    this.restUntil,
    this.pausedFrom,
    this.notes = '',
    List<int> reversibleSetIndexes = const [],
    this.updatedAt,
  }) : sets = List.unmodifiable(sets),
       reversibleSetIndexes = List.unmodifiable(reversibleSetIndexes) {
    if (sessionId.trim().isEmpty || sets.isEmpty) {
      throw ArgumentError('A workout execution requires an id and sets.');
    }
    if (sets.map((set) => set.setId).toSet().length != sets.length) {
      throw ArgumentError('Set identifiers must be unique.');
    }
    if (activeSetIndex < 0 || activeSetIndex >= sets.length) {
      throw ArgumentError.value(activeSetIndex, 'activeSetIndex');
    }
  }

  final String sessionId;
  final List<SetOutcome> sets;
  final WorkoutExecutionState state;
  final int activeSetIndex;
  final DateTime? restUntil;
  final WorkoutExecutionState? pausedFrom;
  final String notes;
  final List<int> reversibleSetIndexes;
  final DateTime? updatedAt;

  SetOutcome get activeSet => sets[activeSetIndex];
  bool get isClosed => const {
    WorkoutExecutionState.completed,
    WorkoutExecutionState.abandoned,
    WorkoutExecutionState.skipped,
  }.contains(state);

  WorkoutExecution ready(DateTime at) {
    _require(WorkoutExecutionState.planned);
    return _copy(state: WorkoutExecutionState.ready, updatedAt: at);
  }

  WorkoutExecution start(DateTime at) {
    if (state != WorkoutExecutionState.ready &&
        state != WorkoutExecutionState.planned) {
      throw StateError('Only a planned or ready workout can start.');
    }
    return _copy(state: WorkoutExecutionState.activeSet, updatedAt: at);
  }

  WorkoutExecution recordActiveSet({
    required SetOutcomeStatus status,
    required DateTime at,
    int? actualRepetitions,
    double? actualLoad,
    double? rpe,
    String notes = '',
    int? actualTotalRepetitions,
    int? actualDurationSeconds,
    double? actualDistanceMeters,
    int? actualRounds,
    bool? completed,
  }) {
    _require(WorkoutExecutionState.activeSet);
    if (!activeSet.isPending) {
      throw StateError('The active set already has an outcome.');
    }
    final next = [...sets];
    next[activeSetIndex] = activeSet.record(
      status: status,
      recordedAt: at,
      actualRepetitions: actualRepetitions,
      actualLoad: actualLoad,
      rpe: rpe,
      notes: notes,
      actualTotalRepetitions: actualTotalRepetitions,
      actualDurationSeconds: actualDurationSeconds,
      actualDistanceMeters: actualDistanceMeters,
      actualRounds: actualRounds,
      completed: completed,
    );
    final nextIndex = _nextPending(next, activeSetIndex + 1) ?? activeSetIndex;
    return _copy(
      sets: next,
      activeSetIndex: nextIndex,
      reversibleSetIndexes: [...reversibleSetIndexes, activeSetIndex],
      updatedAt: at,
    );
  }

  WorkoutExecution beginRest(DateTime until, DateTime at) {
    _require(WorkoutExecutionState.activeSet);
    if (!until.isAfter(at)) {
      throw ArgumentError('Rest must end after it begins.');
    }
    return _copy(
      state: WorkoutExecutionState.resting,
      restUntil: until,
      updatedAt: at,
    );
  }

  WorkoutExecution endRest(DateTime at) {
    _require(WorkoutExecutionState.resting);
    return _copy(
      state: WorkoutExecutionState.activeSet,
      clearRest: true,
      updatedAt: at,
    );
  }

  WorkoutExecution pause(DateTime at) {
    if (state != WorkoutExecutionState.activeSet &&
        state != WorkoutExecutionState.resting) {
      throw StateError('Only an active or resting workout can pause.');
    }
    return _copy(
      state: WorkoutExecutionState.paused,
      pausedFrom: state,
      updatedAt: at,
    );
  }

  WorkoutExecution resume(DateTime at) {
    _require(WorkoutExecutionState.paused);
    return _copy(
      state: pausedFrom ?? WorkoutExecutionState.activeSet,
      clearPausedFrom: true,
      updatedAt: at,
    );
  }

  WorkoutExecution undoLastOutcome(DateTime at) {
    if (isClosed || reversibleSetIndexes.isEmpty) {
      throw StateError('No reversible set outcome is available.');
    }
    final index = reversibleSetIndexes.last;
    final next = [...sets]..[index] = sets[index].clear();
    return _copy(
      sets: next,
      state: WorkoutExecutionState.activeSet,
      activeSetIndex: index,
      clearRest: true,
      reversibleSetIndexes: reversibleSetIndexes.sublist(
        0,
        reversibleSetIndexes.length - 1,
      ),
      updatedAt: at,
    );
  }

  WorkoutExecution updateNotes(String value, DateTime at) {
    if (isClosed) throw StateError('A closed workout cannot be edited.');
    return _copy(notes: value, updatedAt: at);
  }

  WorkoutExecution complete(DateTime at) {
    if (sets.any((set) => set.isPending)) {
      throw StateError('Every set requires an outcome before completion.');
    }
    if (isClosed) throw StateError('The workout is already closed.');
    return _copy(
      state: WorkoutExecutionState.completed,
      clearRest: true,
      reversibleSetIndexes: const [],
      updatedAt: at,
    );
  }

  WorkoutExecution abandon(DateTime at) {
    if (isClosed) throw StateError('The workout is already closed.');
    return _copy(
      state: WorkoutExecutionState.abandoned,
      clearRest: true,
      reversibleSetIndexes: const [],
      updatedAt: at,
    );
  }

  WorkoutExecution skip(DateTime at) {
    if (state != WorkoutExecutionState.planned &&
        state != WorkoutExecutionState.ready) {
      throw StateError('Only a workout that has not started can be skipped.');
    }
    return _copy(
      state: WorkoutExecutionState.skipped,
      reversibleSetIndexes: const [],
      updatedAt: at,
    );
  }

  int? _nextPending(List<SetOutcome> values, int start) {
    for (var index = start; index < values.length; index++) {
      if (values[index].isPending) return index;
    }
    return null;
  }

  void _require(WorkoutExecutionState expected) {
    if (state != expected) {
      throw StateError('Expected ${expected.name}, found ${state.name}.');
    }
  }

  WorkoutExecution _copy({
    List<SetOutcome>? sets,
    WorkoutExecutionState? state,
    int? activeSetIndex,
    DateTime? restUntil,
    bool clearRest = false,
    WorkoutExecutionState? pausedFrom,
    bool clearPausedFrom = false,
    String? notes,
    List<int>? reversibleSetIndexes,
    DateTime? updatedAt,
  }) => WorkoutExecution(
    sessionId: sessionId,
    sets: sets ?? this.sets,
    state: state ?? this.state,
    activeSetIndex: activeSetIndex ?? this.activeSetIndex,
    restUntil: clearRest ? null : (restUntil ?? this.restUntil),
    pausedFrom: clearPausedFrom ? null : (pausedFrom ?? this.pausedFrom),
    notes: notes ?? this.notes,
    reversibleSetIndexes: reversibleSetIndexes ?? this.reversibleSetIndexes,
    updatedAt: updatedAt?.toUtc() ?? this.updatedAt,
  );
}
