import 'package:hybrid_training/features/programs/domain/training_models.dart';

class FoundationProfileInput {
  const FoundationProfileInput({
    required this.displayName,
    required this.unit,
    required this.oneRepMaxes,
    required this.roundingIncrement,
  });

  final String displayName;
  final WeightUnit unit;
  final Map<MainLift, double> oneRepMaxes;
  final double roundingIncrement;
}

class StoredSet {
  const StoredSet({
    required this.id,
    required this.sequence,
    required this.kind,
    required this.load,
    required this.repetitions,
    required this.isPerformanceSet,
    required this.isComplete,
  });

  final String id;
  final int sequence;
  final SetKind kind;
  final double load;
  final int repetitions;
  final bool isPerformanceSet;
  final bool isComplete;
}

class StoredSession {
  const StoredSession({
    required this.id,
    required this.lift,
    required this.scheduledFor,
    required this.unit,
    required this.sets,
    required this.isComplete,
  });

  final String id;
  final MainLift lift;
  final DateTime scheduledFor;
  final WeightUnit unit;
  final List<StoredSet> sets;
  final bool isComplete;
}

class TrainingSnapshot {
  const TrainingSnapshot({
    required this.displayName,
    required this.nextSession,
    required this.history,
  });

  final String displayName;
  final StoredSession? nextSession;
  final List<StoredSession> history;
}

abstract interface class TrainingStore {
  Future<void> initialize();

  Future<bool> hasProfile();

  Future<void> createFoundation(FoundationProfileInput input);

  Future<TrainingSnapshot> loadSnapshot();

  Future<void> completeSet(String setId, {required int repetitions});

  Future<void> finishSession(String sessionId);

  Future<void> close();
}
