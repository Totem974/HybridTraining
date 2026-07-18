import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';

class FoundationProfileInput {
  const FoundationProfileInput({
    required this.displayName,
    required this.unit,
    required this.oneRepMaxes,
    required this.roundingIncrement,
    required this.startDate,
    required this.trainingDaysPerWeek,
  });

  final String displayName;
  final WeightUnit unit;
  final Map<MainLift, double> oneRepMaxes;
  final double roundingIncrement;
  final DateTime startDate;
  final int trainingDaysPerWeek;
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
    this.completedRepetitions,
    this.result,
  });

  final String id;
  final int sequence;
  final SetKind kind;
  final double load;
  final int repetitions;
  final bool isPerformanceSet;
  final bool isComplete;
  final int? completedRepetitions;
  final SetResult? result;
}

enum SetResult { success, failure, skipped }

class StoredSession {
  const StoredSession({
    required this.id,
    required this.lift,
    required this.scheduledFor,
    required this.unit,
    required this.sets,
    required this.isComplete,
    required this.notes,
    this.startedAt,
    this.restUntil,
  });

  final String id;
  final MainLift lift;
  final DateTime scheduledFor;
  final WeightUnit unit;
  final List<StoredSet> sets;
  final bool isComplete;
  final String notes;
  final DateTime? startedAt;
  final DateTime? restUntil;

  bool get isStarted => startedAt != null;
}

class TrainingSnapshot {
  const TrainingSnapshot({
    required this.displayName,
    required this.nextSession,
    required this.history,
    required this.trainingMaxes,
    required this.activeProgram,
  });

  final String displayName;
  final StoredSession? nextSession;
  final List<StoredSession> history;
  final Map<MainLift, double> trainingMaxes;
  final ProgramDefinitionRef activeProgram;
}

abstract interface class TrainingStore {
  Future<void> initialize();

  Future<bool> hasProfile();

  Future<void> createFoundation(FoundationProfileInput input);

  Future<TrainingSnapshot> loadSnapshot();

  Future<void> completeSet(String setId, {required int repetitions});

  Future<void> startSession(String sessionId);

  Future<void> recordSet(
    String setId, {
    required int repetitions,
    required SetResult result,
  });

  Future<void> setRestUntil(String sessionId, DateTime? restUntil);

  Future<void> updateTrainingMaxes(Map<MainLift, double> trainingMaxes);

  Future<String> exportBackup();

  Future<ImportReport> importBackup(String source, {required bool dryRun});

  Future<void> deleteAllData();

  Future<void> finishSession(String sessionId);

  Future<void> updateSessionNotes(String sessionId, String notes);

  Future<void> close();
}
